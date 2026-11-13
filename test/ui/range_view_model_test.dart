import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/calculation_worker.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/range/range_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'invalid range becomes typed error; corrected request recovers',
    () async {
      final model = PlannerViewModel(), range = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(range.dispose);
      Future<void> run(List<RangeVariant> variants) => range.calculate(
        source: model.selected,
        depths: RangeAxis(first: 30, last: 30, step: 3),
        durations: RangeAxis(first: 20, last: 20, step: 1),
        variants: variants,
        inputRevision: 0,
        dependencyVersion: 'test',
      );
      await run([]);
      expect(range.status, RangeStatus.error);
      expect(
        range.failure!.calculationFailure!.code,
        CalculationFailureCode.invalidInput,
      );
      expect(range.inputsCurrent, isFalse);
      await run([RangeVariant.base]);
      expect(range.status, RangeStatus.complete);
      expect(range.cells.single.failure, isNull);
    },
  );
  test(
    'immediate cancellation cannot be resurrected after subscription cleanup',
    () async {
      final model = PlannerViewModel(), range = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(range.dispose);
      final pending = range.calculate(
        source: model.selected,
        depths: RangeAxis(first: 30, last: 30, step: 3),
        durations: RangeAxis(first: 20, last: 20, step: 1),
        variants: [RangeVariant.base],
        inputRevision: 0,
        dependencyVersion: 'test',
      );
      range.cancel();
      await pending;
      expect(range.status, RangeStatus.cancelled);
      expect(range.cells, isEmpty);
      expect(range.failure?.kind, isNot(WorkerFailureKind.unexpected));
    },
  );
}
