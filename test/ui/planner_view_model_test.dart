import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real calculation and repetitive dependency invalidation preserve inputs',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
      expect(
        model.snapshot.result!.runtimeMin,
        closeTo(27.333333333333332, 1e-10),
      );
      final first = model.selected.id;
      model.addDive();
      final second = model.selected.id;
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
      final prior = model.snapshotFor(first).result!;
      final initial = model.snapshot.result!.initialState;
      final recovered = recoverSurface(
        prior.finalState,
        60,
        pressure: prior.pressure,
        kinetics: BuhlmannCoefficients.b().kinetics,
        parameters: VpmParameters(),
      );
      expect(initial.toJson(), recovered.toJson());
      model.select(0);
      final changed = Level(
        depthMetres: 30,
        durationMin: 25,
        breathing: model.selected.levels.first.breathing,
      );
      model.replaceLevels([changed]);
      expect(model.snapshotFor(first).status, PlanStatus.stale);
      expect(model.snapshotFor(second).status, PlanStatus.stale);
      expect(model.selected.levels.first.durationMin, 25);
      model.select(1);
      await model.calculate();
      expect(model.snapshotFor(first).status, PlanStatus.ready);
      expect(model.snapshotFor(second).status, PlanStatus.ready);
    },
  );
  test(
    'view-only theme/units edits do not invalidate or round physical inputs',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await model.calculate();
      final plan = jsonEncode(model.selected.toJson());
      final result = jsonEncode(model.snapshot.result!.toJson());
      for (var i = 0; i < 5; i++) {
        model.setUnits(DisplayUnits.imperial);
        model.setTheme(ThemeMode.dark);
        model.setUnits(DisplayUnits.metric);
        model.setTheme(ThemeMode.light);
      }
      expect(model.snapshot.status, PlanStatus.ready);
      expect(jsonEncode(model.selected.toJson()), plan);
      expect(jsonEncode(model.snapshot.result!.toJson()), result);
    },
  );
  test(
    'edit during worker calculation rejects late response without losing new input',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final pending = model.calculate();
      model.replaceLevels([
        Level(
          depthMetres: 40,
          durationMin: 30,
          breathing: model.selected.levels.first.breathing,
        ),
      ]);
      await pending;
      expect(model.snapshot.status, PlanStatus.draft);
      expect(model.snapshot.result, isNull);
      expect(model.selected.levels.first.depthMetres, 40);
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
    },
  );
  test(
    'numerical input error preserves profile and allows correction and retry',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final gas = model.selected.levels.first.breathing;
      model.replaceLevels([
        Level(depthMetres: 30, durationMin: 1, breathing: gas),
      ]);
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.error);
      expect(model.selected.levels.first.durationMin, 1);
      model.replaceLevels([
        Level(depthMetres: 30, durationMin: 20, breathing: gas),
      ]);
      await model.calculate();
      expect(model.snapshot.status, PlanStatus.ready);
    },
  );
  test(
    'reorder/delete keep stable dive identities and clear dependent results',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final first = model.selected.id;
      model.addDive();
      final second = model.selected.id;
      await model.calculate();
      model.moveDive(-1);
      expect(model.dives.map((d) => d.id), [second, first]);
      expect(model.snapshot.status, PlanStatus.stale);
      model.removeDive();
      expect(model.dives.single.id, first);
      model.removeDive();
      expect(model.dives.length, 1);
    },
  );
}
