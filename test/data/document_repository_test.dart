import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../support/document_fixtures.dart';

TypeMatcher<DocumentFailure> failure(DocumentFailureKind kind) =>
    isA<DocumentFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  late Directory root;
  late PlannerDocument first, second;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('deco-document-test-');
    first = documentFixture();
    second = documentFixture(name: 'План Б', revision: 2);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'list shows recovery and damaged documents but ignores temporary files',
    () async {
      final repo = DocumentRepository(root);
      expect(await repo.list(), isEmpty);
      await repo.save(first);
      await repo.save(second);
      await File(p.join(root.path, '${first.id}.json')).delete();
      await File(p.join(root.path, 'broken.json')).writeAsString('{bad');
      await File(p.join(root.path, 'orphan.pending')).writeAsString('{bad');
      final entries = await repo.list();
      expect(entries.map((e) => e.id), ['broken', first.id]..sort());
      expect(entries.singleWhere((e) => e.id == 'broken').failure, isNotNull);
      final recovered = entries.singleWhere((e) => e.id == first.id).loaded!;
      expect(recovered.recoveredFromBackup, isTrue);
      expect(recovered.document.toJson(), first.toJson());
    },
  );

  test(
    'rename preserves physical input, cached state and previous name',
    () async {
      final repo = DocumentRepository(root);
      await repo.save(first);
      final changed = first.modifiedAt.add(const Duration(minutes: 1));
      await repo.rename(first.id, 'Новое имя', modifiedAt: changed);
      expect(
        (await repo.load(first.id)).document.toJson(),
        first.copyWith(name: 'Новое имя', modifiedAt: changed).toJson(),
      );
      expect(
        decodePlannerDocument(
          await File(
            p.join(root.path, '${first.id}.last-good.json'),
          ).readAsBytes(),
        ).name,
        first.name,
      );
      await expectLater(
        repo.rename(first.id, ''),
        throwsA(failure(DocumentFailureKind.invalidDocument)),
      );
      expect((await repo.load(first.id)).document.name, 'Новое имя');
    },
  );

  test(
    'delete cannot be undone by queued saves or leftover backup copies',
    () async {
      final repo = DocumentRepository(root);
      await repo.save(first);
      await repo.save(second);
      final deletion = repo.delete(first.id);
      final lateSave = repo.save(second);
      await deletion;
      await expectLater(
        lateSave,
        throwsA(failure(DocumentFailureKind.notFound)),
      );
      expect(await repo.list(), isEmpty);
      await File(
        p.join(root.path, '${first.id}.last-good.json'),
      ).writeAsBytes(encodePlannerDocument(first));
      final reopened = DocumentRepository(root);
      await expectLater(
        reopened.load(first.id),
        throwsA(failure(DocumentFailureKind.notFound)),
      );
      expect(await reopened.list(), isEmpty);
      await reopened.delete(first.id);
      expect(
        await File(p.join(root.path, '${first.id}.last-good.json')).exists(),
        isFalse,
      );
    },
  );

  test(
    'verified save/load retains exact data and previous last-good revision',
    () async {
      final repo = DocumentRepository(root);
      await repo.save(first);
      expect((await repo.load(first.id)).document.toJson(), first.toJson());
      await repo.save(second);
      final loaded = await repo.load(first.id);
      expect(loaded.recoveredFromBackup, isFalse);
      expect(loaded.document.toJson(), second.toJson());
      final backup = File(p.join(root.path, '${first.id}.last-good.json'));
      expect(
        decodePlannerDocument(await backup.readAsBytes()).toJson(),
        first.toJson(),
      );
      expect(
        await root
            .list()
            .where((f) => p.extension(f.path) == '.pending')
            .isEmpty,
        isTrue,
      );
    },
  );

  for (final stage in SaveStage.values) {
    test(
      'fault at ${stage.name} retains a readable committed revision',
      () async {
        await DocumentRepository(root).save(first);
        final repo = DocumentRepository(
          root,
          saveHook: (at, path) {
            if (at == stage) {
              throw FileSystemException('Injected storage fault', path);
            }
          },
        );
        await expectLater(
          repo.save(second),
          throwsA(failure(DocumentFailureKind.io)),
        );
        final recovered = await DocumentRepository(root).load(first.id);
        final expected = stage == SaveStage.afterPrimaryPublish
            ? second
            : first;
        expect(recovered.document.toJson(), expected.toJson());
        expect(
          await root
              .list()
              .where((f) => p.extension(f.path) == '.pending')
              .isEmpty,
          isTrue,
        );
      },
    );
  }

  for (final stage in [
    SaveStage.afterTemporaryWrite,
    SaveStage.afterBackupWrite,
  ]) {
    test(
      'torn bytes at ${stage.name} never replace the previous document',
      () async {
        final normal = DocumentRepository(root);
        await normal.save(first);
        final repo = DocumentRepository(
          root,
          saveHook: (at, path) async {
            if (at == stage) await File(path).writeAsBytes([0], flush: true);
          },
        );
        await expectLater(
          repo.save(second),
          throwsA(failure(DocumentFailureKind.integrity)),
        );
        expect((await normal.load(first.id)).document.toJson(), first.toJson());
      },
    );
  }

  test('valid but wrong temporary payload is detected byte-for-byte', () async {
    await DocumentRepository(root).save(first);
    final wrong = encodePlannerDocument(
      documentFixture(name: 'План В', revision: 2),
    );
    expect(wrong.length, encodePlannerDocument(second).length);
    final repo = DocumentRepository(
      root,
      saveHook: (stage, path) async {
        if (stage == SaveStage.afterTemporaryWrite) {
          await File(path).writeAsBytes(wrong, flush: true);
        }
      },
    );
    await expectLater(
      repo.save(second),
      throwsA(failure(DocumentFailureKind.integrity)),
    );
    expect(
      (await DocumentRepository(root).load(first.id)).document.toJson(),
      first.toJson(),
    );
  });

  test(
    'corruption or missing primary recovers backup without overwriting either copy',
    () async {
      final repo = DocumentRepository(root);
      await repo.save(first);
      await repo.save(second);
      final primary = File(p.join(root.path, '${first.id}.json'));
      final backup = File(p.join(root.path, '${first.id}.last-good.json'));
      final backupBytes = await backup.readAsBytes();
      await primary.writeAsString('{bad');
      final loaded = await repo.load(first.id);
      expect(loaded.recoveredFromBackup, isTrue);
      expect(loaded.document.toJson(), first.toJson());
      expect(await primary.readAsString(), '{bad');
      final failedRepair = DocumentRepository(
        root,
        saveHook: (stage, path) {
          if (stage == SaveStage.beforePrimaryPublish) {
            throw FileSystemException('Failed repair', path);
          }
        },
      );
      await expectLater(
        failedRepair.save(second),
        throwsA(failure(DocumentFailureKind.io)),
      );
      expect(await backup.readAsBytes(), backupBytes);
      await primary.delete();
      expect((await repo.load(first.id)).recoveredFromBackup, isTrue);
      await repo.save(second);
      expect((await repo.load(first.id)).document.toJson(), second.toJson());
      expect(await backup.readAsBytes(), backupBytes);
    },
  );

  test(
    'future schema refuses save and load without replacing the previous data',
    () async {
      final repo = DocumentRepository(root);
      await repo.save(first);
      await repo.save(second);
      final primary = File(p.join(root.path, '${first.id}.json'));
      final raw = jsonDecode(await primary.readAsString()) as Map;
      raw['schemaVersion'] = 99;
      await primary.writeAsString(jsonEncode(raw));
      final before = await primary.readAsBytes();
      await expectLater(
        repo.load(first.id),
        throwsA(failure(DocumentFailureKind.unsupportedSchema)),
      );
      await expectLater(
        repo.save(first),
        throwsA(failure(DocumentFailureKind.unsupportedSchema)),
      );
      expect(await primary.readAsBytes(), before);
    },
  );

  test(
    'old calculation version loads as stale and remains intact after a failed save',
    () async {
      final raw = first.toJson();
      raw['modelVersion'] = 'old-version';
      (raw['plan'] as Map)['modelVersion'] = 'old-version';
      for (final value in (raw['results'] as Map).values) {
        ((value as Map)['result'] as Map)['modelVersion'] = 'old-version';
      }
      final old = PlannerDocument.fromJson(raw);
      final repo = DocumentRepository(root);
      await repo.save(old);
      expect((await repo.load(first.id)).document.usesCurrentModel, isFalse);
      final failed = DocumentRepository(
        root,
        saveHook: (at, path) {
          if (at == SaveStage.beforePrimaryPublish) {
            throw FileSystemException('Upgrade interrupted', path);
          }
        },
      );
      await expectLater(
        failed.save(second),
        throwsA(failure(DocumentFailureKind.io)),
      );
      expect((await repo.load(first.id)).document.toJson(), old.toJson());
    },
  );

  test(
    'queue recovers after an error and preserves save/read ordering',
    () async {
      var fail = true;
      final repo = DocumentRepository(
        root,
        saveHook: (stage, path) {
          if (fail && stage == SaveStage.beforeTemporaryWrite) {
            fail = false;
            throw FileSystemException('Once', path);
          }
        },
      );
      await expectLater(
        repo.save(first),
        throwsA(failure(DocumentFailureKind.io)),
      );
      final save1 = repo.save(first);
      final read1 = repo.load(first.id);
      final save2 = repo.save(second);
      final read2 = repo.load(first.id);
      await Future.wait([save1, save2]);
      expect((await read1).document.toJson(), first.toJson());
      expect((await read2).document.toJson(), second.toJson());
    },
  );

  test(
    'unsafe IDs, oversized files and orphan temporaries cannot replace a plan',
    () async {
      final repo = DocumentRepository(root);
      await expectLater(
        repo.load('../outside'),
        throwsA(failure(DocumentFailureKind.invalidDocument)),
      );
      await File(
        p.join(root.path, '${first.id}.pending'),
      ).writeAsBytes(encodePlannerDocument(second));
      await expectLater(
        repo.load(first.id),
        throwsA(failure(DocumentFailureKind.notFound)),
      );
      await repo.save(first);
      final small = DocumentRepository(root, maxBytes: 100);
      await expectLater(
        small.load(first.id),
        throwsA(failure(DocumentFailureKind.tooLarge)),
      );
      await expectLater(
        small.save(second),
        throwsA(failure(DocumentFailureKind.tooLarge)),
      );
      expect((await repo.load(first.id)).document.toJson(), first.toJson());
    },
  );

  test(
    'large document encoding and validation leave the parent event loop active',
    () async {
      final raw = first.toJson();
      raw['toolDrafts'] = {
        'large': {'draft': List.filled(1000000, 'x').join()},
      };
      final large = PlannerDocument.fromJson(raw);
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      try {
        await DocumentRepository(root).save(large);
      } finally {
        timer.cancel();
      }
      expect(ticks, greaterThan(0));
      expect(
        (await DocumentRepository(
          root,
        ).load(first.id)).document.toolDrafts['large']!['draft']!.length,
        1000000,
      );
    },
  );
}
