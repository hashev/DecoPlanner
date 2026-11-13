import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void setCcr(
  PlannerViewModel model, {
  DecompressionModel engine = DecompressionModel.buhlmannB,
}) {
  model.replaceSettings(
    CalculationSettings.fromJson({
      ...model.selected.settings.toJson(),
      'model': engine.name,
    }),
  );
  model.replaceLevels([
    Level(
      depthMetres: 45,
      durationMin: 25,
      breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
    ),
  ]);
}

void saveBranch(PlannerViewModel model, {String? id, double point = 12.5}) =>
    model.saveBailout(
      id: id,
      runtimeMin: point,
      initialOcGas: Gas(oxygen: .21, helium: .35),
      switches: [
        GasSwitch(depthMetres: 21, breathing: BreathingGas.oc(Gas(oxygen: .5))),
        GasSwitch(depthMetres: 6, breathing: BreathingGas.oc(Gas(oxygen: 1))),
      ],
    );

void main() {
  test(
    'editing dive1 invalidates every dive and bailout in a three-dive sequence',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        if (i > 0) model.addDive();
        setCcr(model);
        saveBranch(model);
        ids.addAll([model.selected.id, model.selectedBailout!.id]);
        await model.calculateSelection();
      }
      final old = {for (final id in ids) id: model.snapshotFor(id).result!};
      final levels = model.dives
          .map((d) => jsonEncode(d.levels.map((l) => l.toJson()).toList()))
          .toList();
      model.setToolDraft('mixing:invalid-raw', '-not-a-number');
      model.select(0);
      setCcr(model);
      for (final id in ids) {
        expect(model.snapshotFor(id).status, PlanStatus.stale);
        expect(model.snapshotFor(id).result, same(old[id]));
      }
      expect(
        model.dives.map(
          (d) => jsonEncode(d.levels.map((l) => l.toJson()).toList()),
        ),
        levels,
      );
      expect(model.toolDraft['mixing:invalid-raw'], '-not-a-number');
    },
  );

  for (final engine in DecompressionModel.values) {
    test(
      'linked ${engine.name} escape calculates its CCR dependency and preserves it',
      () async {
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        setCcr(model, engine: engine);
        saveBranch(model);
        final id = model.selectedBailout!.id;
        await model.calculateSelection();
        expect(model.snapshot.status, PlanStatus.ready);
        expect(model.displaySnapshot.status, PlanStatus.ready);
        expect(model.displaySnapshot.result!.diveId, id);
        final original = jsonEncode(model.snapshot.result!.toJson());
        final branch = model.displaySnapshot.result!;
        expect(
          branch.segments.first.physical.breathing.mode,
          BreathingMode.ccr,
        );
        expect(branch.segments.last.physical.breathing.mode, BreathingMode.oc);
        model.selectBailout(null);
        expect(jsonEncode(model.displaySnapshot.result!.toJson()), original);
        model.selectBailout(id);
        saveBranch(model, id: id, point: 20);
        expect(model.snapshot.status, PlanStatus.ready);
        expect(model.displaySnapshot.status, PlanStatus.stale);
        await model.calculateSelection();
        expect(model.displaySnapshot.status, PlanStatus.ready);
        expect(jsonEncode(model.snapshot.result!.toJson()), original);
      },
    );
  }

  test(
    'source edits invalidate linked and following results; branch edits do not invalidate main sequence',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      setCcr(model);
      saveBranch(model);
      await model.calculateSelection();
      final branchId = model.selectedBailout!.id;
      model.addDive();
      final second = model.selected.id;
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
      model.select(0);
      model.selectBailout(branchId);
      saveBranch(model, id: branchId, point: 20);
      expect(model.snapshotFor(second).status, PlanStatus.ready);
      await model.calculateSelection();
      model.setUnits(DisplayUnits.imperial);
      expect(model.displaySnapshot.status, PlanStatus.ready);
      setCcr(model);
      expect(model.snapshot.status, PlanStatus.stale);
      expect(model.snapshotFor(branchId).status, PlanStatus.stale);
      expect(model.snapshotFor(second).status, PlanStatus.stale);
    },
  );

  test(
    'source edit during branch preparation cancels late result and preserves inputs',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      setCcr(model);
      saveBranch(model);
      final running = model.calculateSelection();
      model.replaceLevels([
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: BreathingGas.ccr(Gas(oxygen: .21), 1.2),
        ),
      ]);
      await running;
      expect(model.selected.levels.single.depthMetres, 30);
      expect(model.displaySnapshot.status, PlanStatus.draft);
      expect(model.displaySnapshot.result, isNull);
      expect(model.calculating, isFalse);
      await model.calculateSelection();
      expect(model.displaySnapshot.status, PlanStatus.ready);
    },
  );

  test(
    'invalid branch fails separately, editing recovers and removal preserves source',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      setCcr(model);
      saveBranch(model, point: 10000);
      await model.calculateSelection();
      expect(model.snapshot.status, PlanStatus.ready);
      expect(model.displaySnapshot.status, PlanStatus.error);
      final id = model.selectedBailout!.id;
      saveBranch(model, id: id);
      await model.calculateSelection();
      expect(model.displaySnapshot.status, PlanStatus.ready);
      model.replaceLevels([
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: BreathingGas.oc(Gas(oxygen: .21)),
        ),
      ]);
      saveBranch(model, id: id);
      await model.calculateSelection();
      expect(model.displaySnapshot.status, PlanStatus.error);
      setCcr(model);
      await model.calculateSelection();
      expect(model.displaySnapshot.status, PlanStatus.ready);
      model.removeSelectedBailout();
      expect(model.selectedDiveBailouts, isEmpty);
      expect(model.selectedBailout, isNull);
      expect(model.snapshot.status, PlanStatus.ready);
    },
  );

  test(
    'removing source removes its linked branches and foreign selection is rejected',
    () {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      setCcr(model);
      saveBranch(model);
      final id = model.selectedBailout!.id;
      model.addDive();
      expect(() => model.selectBailout(id), throwsArgumentError);
      model.select(0);
      model.removeDive();
      expect(model.bailouts, isEmpty);
    },
  );
}
