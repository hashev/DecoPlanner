import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/planner_document.dart';

enum SaveStage {
  beforeDirectory,
  afterDirectory,
  beforeTemporaryWrite,
  afterTemporaryWrite,
  afterTemporaryValidation,
  beforeBackupWrite,
  afterBackupWrite,
  afterBackupValidation,
  afterBackupPublish,
  beforePrimaryPublish,
  afterPrimaryPublish,
}

typedef SaveHook = FutureOr<void> Function(SaveStage stage, String path);

Future<PlannerDocument> _decodeBackground(Uint8List bytes, int limit) =>
    Isolate.run(() => decodePlannerDocument(bytes, maxBytes: limit));
Future<Uint8List> _encodeBackground(PlannerDocument document, int limit) =>
    Isolate.run(() => encodePlannerDocument(document, maxBytes: limit));
Future<void> _validateBackground(
  Uint8List actual,
  Uint8List expected,
  int limit,
) => Isolate.run(() {
  if (actual.length != expected.length) {
    throw const DocumentFailure(
      DocumentFailureKind.integrity,
      'Saved data is incomplete.',
    );
  }
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      throw const DocumentFailure(
        DocumentFailureKind.integrity,
        'Saved data differs from the document.',
      );
    }
  }
  decodePlannerDocument(actual, maxBytes: limit);
});

final class LoadedDocument {
  const LoadedDocument(
    this.document, {
    this.recoveredFromBackup = false,
    this.primaryFailure,
  });
  final PlannerDocument document;
  final bool recoveredFromBackup;
  final DocumentFailure? primaryFailure;
}

final class DocumentEntry {
  const DocumentEntry(this.id, {this.loaded, this.failure});
  final String id;
  final LoadedDocument? loaded;
  final DocumentFailure? failure;
}

final class _VerifiedFile {
  const _VerifiedFile(this.document, this.bytes, {this.backup = false});
  final PlannerDocument document;
  final Uint8List bytes;
  final bool backup;
}

/// Serializes writes and keeps a verified last-good copy until publication.
final class DocumentRepository {
  DocumentRepository(
    this.directory, {
    this.maxBytes = maximumDocumentBytes,
    this.saveHook,
  }) {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  }
  final Directory directory;
  final int maxBytes;
  final SaveHook? saveHook;
  Future<void> _tail = Future.value();

  static Future<DocumentRepository> application() async {
    final support = await getApplicationSupportDirectory();
    return DocumentRepository(Directory(p.join(support.path, 'plans')));
  }

  String _path(String id, String suffix) {
    if (!validDocumentId(id)) {
      throw const DocumentFailure(
        DocumentFailureKind.invalidDocument,
        'Invalid document identity.',
      );
    }
    return p.join(directory.path, '$id$suffix');
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final completion = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(await operation());
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  Future<void> _stage(SaveStage stage, String path) async =>
      saveHook?.call(stage, path);

  Future<Uint8List> _readBounded(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const DocumentFailure(
        DocumentFailureKind.notFound,
        'Saved plan not found.',
      );
    }
    if (await file.length() > maxBytes) {
      throw const DocumentFailure(
        DocumentFailureKind.tooLarge,
        'Saved plan exceeds the size limit.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const DocumentFailure(
          DocumentFailureKind.tooLarge,
          'Saved plan exceeds the size limit.',
        );
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<_VerifiedFile> _readVerified(String id, {bool backup = false}) async {
    final bytes = await _readBounded(
      _path(id, backup ? '.last-good.json' : '.json'),
    );
    final limit = maxBytes;
    final document = await _decodeBackground(bytes, limit);
    if (document.id != id) {
      throw const DocumentFailure(
        DocumentFailureKind.integrity,
        'Saved plan identity does not match its file.',
      );
    }
    return _VerifiedFile(document, bytes, backup: backup);
  }

  bool _recoverable(DocumentFailure failure) => switch (failure.kind) {
    DocumentFailureKind.notFound ||
    DocumentFailureKind.invalidDocument ||
    DocumentFailureKind.integrity => true,
    _ => false,
  };

  Future<LoadedDocument> load(String id) => _serial(() => _load(id));

  Future<LoadedDocument> _load(String id) async {
    try {
      await _requireNotDeleted(id);
      try {
        final primary = await _readVerified(id);
        return LoadedDocument(primary.document);
      } on DocumentFailure catch (failure) {
        if (!_recoverable(failure)) rethrow;
        final backup = await _readVerified(id, backup: true);
        return LoadedDocument(
          backup.document,
          recoveredFromBackup: true,
          primaryFailure: failure,
        );
      }
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not read the saved plan.',
      );
    }
  }

  Future<void> _requireNotDeleted(String id) async {
    if (await File(_path(id, '.deleted')).exists()) {
      throw const DocumentFailure(
        DocumentFailureKind.notFound,
        'This plan has been deleted.',
      );
    }
  }

  /// Includes unreadable documents so that damage never silently hides a plan.
  Future<List<DocumentEntry>> list() => _serial(() async {
    try {
      if (!await directory.exists()) return const [];
      final ids = <String>{};
      await for (final file in directory.list(followLinks: false)) {
        if (file is! File) continue;
        final name = p.basename(file.path);
        final suffix = name.endsWith('.last-good.json')
            ? '.last-good.json'
            : '.json';
        if (!name.endsWith(suffix)) continue;
        final id = name.substring(0, name.length - suffix.length);
        if (validDocumentId(id)) ids.add(id);
      }
      final entries = <DocumentEntry>[];
      for (final id in ids.toList()..sort()) {
        if (await File(_path(id, '.deleted')).exists()) continue;
        try {
          entries.add(DocumentEntry(id, loaded: await _load(id)));
        } on DocumentFailure catch (failure) {
          entries.add(DocumentEntry(id, failure: failure));
        }
      }
      return List.unmodifiable(entries);
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not list saved plans.',
      );
    }
  });

  Future<void> rename(String id, String name, {DateTime? modifiedAt}) =>
      _serial(() async {
        final loaded = await _load(id);
        await _save(
          loaded.document.copyWith(
            name: name,
            modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
          ),
        );
      });

  /// A durable tombstone prevents queued or interrupted saves resurrecting data.
  Future<void> delete(String id) => _serial(() async {
    final marker = _path(id, '.deleted');
    final pending = _path(id, '.delete.pending');
    try {
      await directory.create(recursive: true);
      if (!await File(marker).exists()) {
        await File(pending).writeAsString('deleted', flush: true);
        await File(pending).rename(marker);
      }
      for (final suffix in [
        '.json',
        '.last-good.json',
        '.pending',
        '.last-good.pending',
        '.delete.pending',
      ]) {
        final file = File(_path(id, suffix));
        if (await file.exists()) await file.delete();
      }
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not delete the saved plan.',
      );
    }
  });

  Future<_VerifiedFile?> _prior(String id) async {
    try {
      return await _readVerified(id);
    } on DocumentFailure catch (failure) {
      if (!_recoverable(failure)) rethrow;
      try {
        return await _readVerified(id, backup: true);
      } on DocumentFailure catch (backupFailure) {
        if (!_recoverable(backupFailure)) rethrow;
        return null;
      }
    }
  }

  Future<void> _validateWritten(String path, Uint8List expected) async {
    final actual = await _readBounded(path);
    await _validateBackground(actual, expected, maxBytes);
  }

  Future<void> save(PlannerDocument document) => _serial(() => _save(document));

  Future<void> _save(PlannerDocument document) async {
    final primary = _path(document.id, '.json');
    final temporary = _path(document.id, '.pending');
    final backup = _path(document.id, '.last-good.json');
    final backupTemporary = _path(document.id, '.last-good.pending');
    final limit = maxBytes;
    final bytes = await _encodeBackground(document, limit);
    try {
      await _stage(SaveStage.beforeDirectory, primary);
      await directory.create(recursive: true);
      await _requireNotDeleted(document.id);
      await _stage(SaveStage.afterDirectory, primary);
      final previous = await _prior(document.id);
      await _stage(SaveStage.beforeTemporaryWrite, temporary);
      await File(temporary).writeAsBytes(bytes, flush: true);
      await _stage(SaveStage.afterTemporaryWrite, temporary);
      await _validateWritten(temporary, bytes);
      await _stage(SaveStage.afterTemporaryValidation, temporary);
      if (previous != null && !previous.backup) {
        await _stage(SaveStage.beforeBackupWrite, backupTemporary);
        await File(backupTemporary).writeAsBytes(previous.bytes, flush: true);
        await _stage(SaveStage.afterBackupWrite, backupTemporary);
        await _validateWritten(backupTemporary, previous.bytes);
        await _stage(SaveStage.afterBackupValidation, backupTemporary);
        await File(backupTemporary).rename(backup);
        await _stage(SaveStage.afterBackupPublish, backup);
      }
      // If recovery selected the backup, leave that only good copy untouched.
      await _stage(SaveStage.beforePrimaryPublish, temporary);
      await File(temporary).rename(primary);
      await _stage(SaveStage.afterPrimaryPublish, primary);
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not save the plan.',
      );
    } finally {
      for (final path in [temporary, backupTemporary]) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          /* A later save can replace a leftover temporary file. */
        }
      }
    }
  }
}
