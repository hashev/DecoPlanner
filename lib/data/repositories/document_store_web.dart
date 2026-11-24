import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import '../models/planner_document.dart';
import 'document_store.dart';

Future<DocumentStore> openDocumentStore() => IndexedDocumentStore.open();

const _store = 'plans';
const _io = DocumentFailure(
  DocumentFailureKind.io,
  'IndexedDB operation failed.',
);
const _missing = DocumentFailure(
  DocumentFailureKind.notFound,
  'Plan not found.',
);

extension type _Record._(JSObject _) implements JSObject {
  external factory _Record({
    required JSString id,
    JSUint8Array? primary,
    JSUint8Array? backup,
    JSBoolean? deleted,
  });
  external JSString get id;
  external JSUint8Array? get primary;
  external JSUint8Array? get backup;
  external JSBoolean? get deleted;
}

final class IndexedDocumentStore implements DocumentStore {
  IndexedDocumentStore._(this._db);

  final IDBDatabase _db;

  static Future<IndexedDocumentStore> open({
    String name = 'decoplanner-documents',
  }) async {
    try {
      final request = window.indexedDB.open(name, 1);
      final result = Completer<IndexedDocumentStore>();
      request.onupgradeneeded = ((Event _) {
        final db = request.result as IDBDatabase;
        db.createObjectStore(
          _store,
          IDBObjectStoreParameters(keyPath: 'id'.toJS),
        );
      }).toJS;
      request.onerror = ((Event _) {
        if (!result.isCompleted) result.completeError(_io);
      }).toJS;
      request.onblocked = request.onerror;
      request.onsuccess = ((Event _) {
        final db = request.result as IDBDatabase;
        if (result.isCompleted) {
          db.close();
          return;
        }
        final store = IndexedDocumentStore._(db);
        db.onversionchange = ((Event _) => store.close()).toJS;
        result.complete(store);
      }).toJS;
      return await result.future;
    } on DocumentFailure {
      rethrow;
    } catch (_) {
      throw _io;
    }
  }

  void close() => _db.close();

  Future<T> _transaction<T>({
    bool write = false,
    required IDBRequest Function(IDBObjectStore) request,
    required T Function(JSAny?, IDBObjectStore) read,
  }) async {
    try {
      final transaction = _db.transaction(
        _store.toJS,
        write ? 'readwrite' : 'readonly',
      );
      final store = transaction.objectStore(_store);
      final result = Completer<T>();
      late T value;
      Object? failure;
      transaction.oncomplete = ((Event _) => result.complete(value)).toJS;
      transaction.onabort = ((Event _) => result.completeError(
        failure ?? _io,
      )).toJS;
      final pending = request(store);
      pending.onsuccess = ((Event _) {
        try {
          // IndexedDB writes must be queued within the active request callback.
          value = read(pending.result, store);
        } catch (error) {
          failure = error is DocumentFailure ? error : _io;
          transaction.abort();
        }
      }).toJS;
      return await result.future;
    } on DocumentFailure {
      rethrow;
    } catch (_) {
      throw _io;
    }
  }

  _Record? _record(JSAny? value) => value == null ? null : value as _Record;

  void _checkId(String id) {
    if (!validDocumentId(id)) {
      throw const DocumentFailure(
        DocumentFailureKind.invalidDocument,
        'Invalid document identity.',
      );
    }
  }

  PlannerDocument _decode(JSUint8Array? bytes, String id) {
    if (bytes == null) throw _missing;
    final document = decodePlannerDocument(bytes.toDart);
    if (document.id != id) {
      throw const DocumentFailure(
        DocumentFailureKind.integrity,
        'Saved document identity does not match its key.',
      );
    }
    return document;
  }

  LoadedDocument _load(_Record? record, String id) {
    if (record == null || record.deleted?.toDart == true) throw _missing;
    try {
      return LoadedDocument(_decode(record.primary, id));
    } on DocumentFailure catch (error) {
      if (error.kind == DocumentFailureKind.unsupportedSchema ||
          error.kind == DocumentFailureKind.tooLarge ||
          record.backup == null) {
        rethrow;
      }
      return LoadedDocument(
        _decode(record.backup, id),
        recoveredFromBackup: true,
        primaryFailure: error,
      );
    }
  }

  @override
  Future<LoadedDocument> load(String id) async {
    _checkId(id);
    return _transaction(
      request: (store) => store.get(id.toJS),
      read: (value, _) => _load(_record(value), id),
    );
  }

  @override
  Future<List<DocumentEntry>> list() => _transaction(
    request: (store) => store.getAll(),
    read: (value, _) => [
      for (final record in (value as JSArray<_Record>).toDart)
        if (record.deleted?.toDart != true) _entry(record),
    ],
  );

  DocumentEntry _entry(_Record record) {
    final id = record.id.toDart;
    try {
      return DocumentEntry(id, loaded: _load(record, id));
    } on DocumentFailure catch (failure) {
      return DocumentEntry(id, failure: failure);
    }
  }

  void _put(IDBObjectStore store, _Record? previous, PlannerDocument document) {
    if (previous?.deleted?.toDart == true) throw _missing;
    final bytes = encodePlannerDocument(document).toJS;
    JSUint8Array? backup;
    if (previous != null) {
      try {
        final loaded = _load(previous, document.id);
        backup = loaded.recoveredFromBackup
            ? previous.backup
            : previous.primary;
      } on DocumentFailure catch (error) {
        if (error.kind == DocumentFailureKind.unsupportedSchema ||
            error.kind == DocumentFailureKind.tooLarge) {
          rethrow;
        }
      }
    }
    store.put(_Record(id: document.id.toJS, primary: bytes, backup: backup));
  }

  @override
  Future<void> save(PlannerDocument document) => _transaction<void>(
    write: true,
    request: (store) => store.get(document.id.toJS),
    read: (value, store) => _put(store, _record(value), document),
  );

  @override
  Future<void> rename(String id, String name, {DateTime? modifiedAt}) async {
    _checkId(id);
    await _transaction<void>(
      write: true,
      request: (store) => store.get(id.toJS),
      read: (value, store) {
        final record = _record(value);
        final document = _load(record, id).document.copyWith(
          name: name,
          modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
        );
        _put(store, record, document);
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    _checkId(id);
    await _transaction<void>(
      write: true,
      request: (store) => store.put(_Record(id: id.toJS, deleted: true.toJS)),
      read: (_, _) {},
    );
  }
}
