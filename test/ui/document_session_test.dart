import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:deco_planner/ui/features/documents/document_session.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../support/document_fixtures.dart';

void main() {
  late Directory root;
  late PlannerViewModel model;
  late DocumentRepository repo;
  late DocumentSession session;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('deco-session-');
    model = PlannerViewModel();
    repo = DocumentRepository(root);
    session = DocumentSession(
      model: model,
      repository: repo,
      autosaveDelay: const Duration(milliseconds: 10),
    );
  });
  tearDown(() async {
    session.dispose();
    model.dispose();
    await root.delete(recursive: true);
  });

  test(
    'catalog edits preserve plan copies and round-trip into a new plan',
    () async {
      final before = jsonEncode(model.planRequest.toJson());
      final set = GasSetPreset(
        id: 'deco-set',
        name: 'EAN50',
        switches: [
          GasSwitch(
            depthMetres: 21,
            breathing: BreathingGas.oc(Gas(oxygen: .5)),
          ),
        ],
      );
      final tank = TankPreset(
        id: 'tank-1',
        name: 'AL80',
        waterLitres: 11.1,
        workingBar: 207,
      );
      session.saveGasSet(set);
      session.saveTank(tank);
      expect(jsonEncode(model.planRequest.toJson()), before);
      expect(await session.save(), isTrue);
      final savedId = session.document.id;
      model.replaceSwitches(set.switches);
      session.deleteGasSet(set.id);
      session.deleteTank(tank.id);
      expect(model.selected.switches.single.breathing.gas.oxygen, .5);
      expect(await session.save(), isTrue);
      session.saveGasSet(set);
      session.saveTank(tank);
      expect(await session.create(), isTrue);
      expect(session.document.gasSets.single.toJson(), set.toJson());
      expect(session.document.tanks.single.toJson(), tank.toJson());
      expect(model.selected.switches, isEmpty);
      expect(await session.open(savedId), isTrue);
      expect(session.document.gasSets.single.toJson(), set.toJson());
    },
  );

  test(
    'saved defaults do not alter current plan and survive creating/reopening a new plan',
    () async {
      final original = model.selected.settings;
      final defaults = CalculationSettings.fromJson({
        ...original.toJson(),
        'gfLow': .4,
        'bottomRmvLitresPerMin': 23.0,
      });
      final revision = model.planRequest.revision;
      session.saveDefaultSettings(defaults);
      expect(model.selected.settings, same(original));
      expect(model.planRequest.revision, revision);
      expect(await session.save(), isTrue);
      final firstId = session.document.id;
      expect(await session.create(), isTrue);
      final nextId = session.document.id;
      expect(model.selected.settings.toJson(), defaults.toJson());
      expect(session.defaultSettings!.toJson(), defaults.toJson());
      expect(await session.open(firstId), isTrue);
      expect(model.selected.settings.toJson(), original.toJson());
      expect(await session.open(nextId), isTrue);
      expect(model.selected.settings.toJson(), defaults.toJson());
    },
  );

  test(
    'named comparisons survive save/new/open and clear without changing input',
    () async {
      await model.calculateSelection();
      final snapshot = ComparisonSnapshot(
        id: 'comparison-1',
        name: 'До изменения',
        capturedAt: DateTime.utc(2026, 11, 13),
        plan: model.planRequest,
        results: model.storedResults,
      );
      final original = jsonEncode(model.planRequest.toJson());
      session.saveComparison(snapshot);
      expect(jsonEncode(model.planRequest.toJson()), original);
      expect(await session.save(), isTrue);
      final id = session.document.id;
      model.setSurfaceInterval(45);
      expect(session.document.comparisons.single.toJson(), snapshot.toJson());
      expect(await session.create(), isTrue);
      expect(session.document.comparisons, isEmpty);
      expect(await session.open(id), isTrue);
      expect(session.document.comparisons.single.toJson(), snapshot.toJson());
      expect(model.selected.surfaceIntervalMin, 45);
      session.clearComparisons();
      expect(model.selected.surfaceIntervalMin, 45);
      expect(await session.save(), isTrue);
      expect((await repo.load(id)).document.comparisons, isEmpty);
    },
  );

  test(
    'metadata changed during disk save is retained and published by the next save',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      var blocked = false;
      session.dispose();
      session = DocumentSession(
        model: model,
        repository: DocumentRepository(
          root,
          saveHook: (stage, path) async {
            if (stage == SaveStage.beforePrimaryPublish && !blocked) {
              blocked = true;
              entered.complete();
              await release.future;
            }
          },
        ),
        autosaveDelay: const Duration(days: 1),
      );
      final saving = session.save();
      await entered.future;
      final tank = TankPreset(
        id: 'new-tank',
        name: 'During save',
        waterLitres: 12,
        workingBar: 232,
      );
      session.saveTank(tank);
      release.complete();
      expect(await saving, isTrue);
      expect(session.document.tanks.single.toJson(), tank.toJson());
      expect(session.dirty, isTrue);
      expect(await session.save(), isTrue);
      expect(session.dirty, isFalse);
      expect(
        (await repo.load(session.document.id)).document.tanks.single.toJson(),
        tank.toJson(),
      );
    },
  );

  test(
    'profile preference retains exact previous inputs once after successful recalculation',
    () async {
      model.setToolDraft('profile:keepPrevious', 'true');
      await model.calculateSelection();
      final first = model.snapshot.result!, original = model.planRequest;
      expect(session.document.comparisons, isEmpty);
      model.replaceSettings(
        CalculationSettings.fromJson({
          ...model.selected.settings.toJson(),
          'gfLow': .4,
        }),
      );
      expect(
        session.knownProfile(model.selected.id)!.plan.toJson(),
        original.toJson(),
      );
      await model.calculateSelection();
      expect(session.document.comparisons.length, 1);
      final saved = session.document.comparisons.single;
      expect(saved.results[model.selected.id]!.result, same(first));
      expect(saved.plan.toJson(), original.toJson());
      model.setTheme(ThemeMode.dark);
      model.setUnits(DisplayUnits.imperial);
      expect(session.document.comparisons.length, 1);
      model.setToolDraft('profile:keepPrevious', 'false');
      model.setSurfaceInterval(45);
      await model.calculateSelection();
      expect(session.document.comparisons.single.id, saved.id);
      expect(await session.save(), isTrue);
      expect(
        (await repo.load(
          session.document.id,
        )).document.comparisons.single.toJson(),
        saved.toJson(),
      );
    },
  );
  test(
    'reset retains a frozen graph or clears it according to preference without duplicate IDs',
    () async {
      model.setToolDraft('profile:keepPrevious', 'true');
      await model.calculateSelection();
      final old = model.snapshot.result!;
      session.prepareProfileReset();
      model.resetSelected();
      expect(
        session.document.comparisons.single.results[model.selected.id]!.result,
        same(old),
      );
      expect(
        session
            .knownProfile(model.selected.id)!
            .results[model.selected.id]!
            .result,
        same(old),
      );
      await model.calculateSelection();
      expect(session.document.comparisons.length, 1);
      model.setToolDraft('profile:keepComparisonsOnReset', 'false');
      session.prepareProfileReset();
      model.resetSelected();
      expect(session.document.comparisons, isEmpty);
      expect(session.knownProfile(model.selected.id), isNull);
      expect(model.snapshot.result, isNotNull);
      expect(model.snapshot.status, PlanStatus.stale);
    },
  );

  test(
    'restore preserves complete inputs and cached state but requires recalculation',
    () async {
      final document = documentFixture();
      await repo.save(document);
      expect(await session.open(document.id), isTrue);
      expect(model.planRequest.toJson(), document.plan.toJson());
      for (final entry in document.results.entries) {
        expect(model.snapshotFor(entry.key).status, PlanStatus.stale);
        expect(
          model.snapshotFor(entry.key).result!.toJson(),
          entry.value.result.toJson(),
        );
        expect(
          model.storedResults[entry.key]!.dependencyVersion,
          entry.value.dependencyVersion,
        );
      }
      expect(model.units, document.preferences.units);
      expect(session.dirty, isFalse);
      model.addDive();
      expect(model.dives.map((d) => d.id).toSet().length, model.dives.length);
      expect(await session.save(), isTrue);
      expect((await repo.load(document.id)).document.plan.dives.length, 3);
    },
  );

  test(
    'autosave coalesces edits and opening current document cannot discard input',
    () async {
      model.setSurfaceInterval(45);
      model.setSurfaceInterval(60);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (session.dirty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(session.dirty, isFalse);
      expect(
        (await repo.load(
          session.document.id,
        )).document.plan.dives.first.surfaceIntervalMin,
        60,
      );
      model.setSurfaceInterval(180);
      expect(await session.open(session.document.id), isTrue);
      expect(model.selected.surfaceIntervalMin, 180);
    },
  );

  test(
    'invalid and future imports leave current input and identity intact',
    () async {
      model.setSurfaceInterval(45);
      final before = model.planRequest.toJson(), id = session.document.id;
      for (final bytes in [
        Uint8List.fromList([0]),
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({'format': 'decoplanner-plan', 'schemaVersion': 99}),
          ),
        ),
      ]) {
        expect(await session.importBytes(bytes), isFalse);
        expect(model.planRequest.toJson(), before);
        expect(session.document.id, id);
        expect(session.failure, isNotNull);
      }
      expect(
        await session.importBytes(Uint8List(maximumDocumentBytes + 1)),
        isFalse,
      );
      expect(session.failure!.kind, DocumentFailureKind.tooLarge);
      expect(model.planRequest.toJson(), before);
    },
  );

  test(
    'import uses new identity, preserves original and exports exact physical state',
    () async {
      final document = documentFixture();
      await repo.save(document);
      expect(
        await session.importBytes(encodePlannerDocument(document)),
        isTrue,
      );
      expect(session.document.id, isNot(document.id));
      expect(
        (await repo.load(document.id)).document.toJson(),
        document.toJson(),
      );
      final exported = decodePlannerDocument(await session.exportBytes());
      expect(exported.plan.toJson(), document.plan.toJson());
      expect(
        exported.results.map((k, v) => MapEntry(k, v.toJson())),
        document.results.map((k, v) => MapEntry(k, v.toJson())),
      );
      expect(model.snapshot.status, PlanStatus.stale);
    },
  );

  test(
    'failed autosave retains input and blocks switching until save recovers',
    () async {
      await repo.save(documentFixture());
      var failing = true;
      session.dispose();
      session = DocumentSession(
        model: model,
        repository: DocumentRepository(
          root,
          saveHook: (stage, path) {
            if (failing && stage == SaveStage.beforePrimaryPublish) {
              throw FileSystemException('Injected', path);
            }
          },
        ),
        autosaveDelay: const Duration(days: 1),
      );
      model.setSurfaceInterval(180);
      final id = session.document.id;
      expect(await session.open('plan-a'), isFalse);
      expect(session.document.id, id);
      expect(model.selected.surfaceIntervalMin, 180);
      expect(session.dirty, isTrue);
      failing = false;
      expect(await session.save(), isTrue);
      expect(session.failure, isNull);
      expect(await session.open('plan-a'), isTrue);
    },
  );

  test(
    'deleting current document starts a fresh identity without resurrection',
    () async {
      await session.save();
      final id = session.document.id;
      model.setSurfaceInterval(45);
      expect(await session.delete(id), isTrue);
      expect(session.document.id, isNot(id));
      await session.save();
      expect((await repo.list()).map((e) => e.id), isNot(contains(id)));
      expect(model.selected.surfaceIntervalMin, 0);
    },
  );

  test(
    'startup restores newest saved plan without saving transient default',
    () async {
      final original = documentFixture();
      await repo.save(original);
      final transient = session.document.id;
      await session.initialize();
      expect(session.document.id, original.id);
      expect(model.planRequest.toJson(), original.plan.toJson());
      expect((await repo.list()).map((e) => e.id), isNot(contains(transient)));
    },
  );

  test(
    'previous model results survive a new calculation as a frozen comparison',
    () async {
      final raw = documentFixture().toJson();
      raw['modelVersion'] = 'previous-model';
      (raw['plan'] as Map)['modelVersion'] = 'previous-model';
      for (final value in (raw['results'] as Map).values) {
        ((value as Map)['result'] as Map)['modelVersion'] = 'previous-model';
      }
      final original = PlannerDocument.fromJson(raw);
      await repo.save(original);
      await session.open(original.id);
      expect(model.snapshot.status, PlanStatus.stale);
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
      expect(await session.save(), isTrue);
      final upgraded = (await repo.load(original.id)).document;
      expect(upgraded.usesCurrentModel, isTrue);
      final history = upgraded.comparisons.last;
      expect(history.modelVersion, 'previous-model');
      expect(
        history.results.map((k, v) => MapEntry(k, v.toJson())),
        original.results.map((k, v) => MapEntry(k, v.toJson())),
      );
      expect(
        upgraded.results.values.every(
          (r) => r.result.modelVersion == calculationModelVersion,
        ),
        isTrue,
      );
    },
  );

  test('restored IDs never collide when adding dives or branches', () async {
    final original = documentFixture();
    final raw = original.toJson();
    final plan = raw['plan'] as Map;
    final dives = plan['dives'] as List;
    final oldId = (dives.first as Map)['id'];
    (dives.first as Map)['id'] = 'dive-1';
    final branches = plan['bailouts'] as List;
    for (final branch in branches) {
      (branch as Map)['sourceDiveId'] = 'dive-1';
      branch['id'] = 'bailout-1';
    }
    raw['results'] = <String, Object?>{};
    expect(oldId, isNotNull);
    await repo.save(PlannerDocument.fromJson(raw));
    await session.open(original.id);
    model.saveBailout(
      runtimeMin: 10,
      initialOcGas: Gas(oxygen: .21),
      switches: [],
    );
    expect(model.selectedBailout!.id, 'bailout-2');
    model.addDive();
    expect(model.selected.id, 'dive-2');
  });
}
