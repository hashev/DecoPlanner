import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/planner_document.dart';

enum DocumentExport { cancelled, saved, shared, handedOff }

abstract interface class DocumentFiles {
  Future<Uint8List?> pickJson();
  Future<DocumentExport> exportJson(Uint8List bytes, String name, Rect origin);
}

String documentFileName(String name) {
  var safe = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (safe.isEmpty) safe = 'plan';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)',
    caseSensitive: false,
  ).hasMatch(safe)) {
    safe = '_$safe';
  }
  if (safe.length > 100) safe = String.fromCharCodes(safe.runes.take(80));
  return safe.toLowerCase().endsWith('.json') ? safe : '$safe.json';
}

final class NativeDocumentFiles implements DocumentFiles {
  const NativeDocumentFiles();
  static const _types = [
    XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    ),
  ];

  @override
  Future<Uint8List?> pickJson() async {
    try {
      final file = await openFile(acceptedTypeGroups: _types);
      if (file == null) return null;
      if (await file.length() > maximumDocumentBytes) {
        throw const DocumentFailure(
          DocumentFailureKind.tooLarge,
          'Selected plan exceeds the size limit.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > maximumDocumentBytes) {
          throw const DocumentFailure(
            DocumentFailureKind.tooLarge,
            'Selected plan exceeds the size limit.',
          );
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not read the selected plan.',
      );
    } on PlatformException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not open the file picker.',
      );
    } on MissingPluginException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'File selection is unavailable.',
      );
    }
  }

  @override
  Future<DocumentExport> exportJson(
    Uint8List bytes,
    String name,
    Rect origin,
  ) async {
    final filename = documentFileName(name);
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'application/json')],
            fileNameOverrides: [filename],
            sharePositionOrigin: origin,
          ),
        );
        return switch (result.status) {
          ShareResultStatus.dismissed => DocumentExport.cancelled,
          ShareResultStatus.success => DocumentExport.shared,
          ShareResultStatus.unavailable => DocumentExport.handedOff,
        };
      }
      final target = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: _types,
      );
      if (target == null) return DocumentExport.cancelled;
      await File(target.path).writeAsBytes(bytes, flush: true);
      return DocumentExport.saved;
    } on FileSystemException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not export the plan.',
      );
    } on PlatformException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'Could not open the export dialog.',
      );
    } on MissingPluginException {
      throw const DocumentFailure(
        DocumentFailureKind.io,
        'File export is unavailable.',
      );
    }
  }
}
