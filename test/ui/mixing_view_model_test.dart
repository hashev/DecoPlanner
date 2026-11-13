import 'dart:async';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/tools/mixing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/mixing_fixtures.dart';

void main() {
  test(
    'real isolate calculates physical partial and real continuous recipes',
    () async {
      final vm = MixingViewModel();
      addTearDown(vm.dispose);
      await vm.calculate(input());
      expect(vm.current, isTrue);
      expect(
        vm.result!.partial!.steps.last.pressureAfterBar,
        closeTo(200, 1e-9),
      );
      final revision = vm.recipeRevision;
      await vm.calculate(
        input(
          method: MixingMethod.continuous,
          real: true,
          target: Gas(oxygen: .18, helium: .45),
        ),
      );
      expect(vm.current, isTrue);
      expect(vm.recipeRevision, greaterThan(revision!));
      expect(
        vm.result!.continuous!.steps.last.resultingGas.oxygen,
        closeTo(.18, 1e-9),
      );
      expect(
        vm.result!.costRecipe.heliumMolesPerLitre,
        vm.result!.continuous!.heliumMolesPerLitre,
      );
    },
  );
  test(
    'stale completion cannot restore old instructions after input changes',
    () async {
      final done = Completer<MixingResult>();
      final vm = MixingViewModel(calculate: (_) => done.future);
      addTearDown(vm.dispose);
      final request = input();
      final future = vm.calculate(request);
      expect(vm.status, MixingStatus.calculating);
      vm.invalidate();
      done.complete(calculateMixing(request));
      await future;
      expect(vm.current, isFalse);
      expect(vm.result, isNull);
      expect(vm.status, MixingStatus.draft);
    },
  );
  test(
    'impossible recipe retains old snapshot without current success and recovers',
    () async {
      final vm = MixingViewModel();
      addTearDown(vm.dispose);
      await vm.calculate(input());
      final old = vm.result;
      await vm.calculate(
        input(target: Gas(oxygen: 0), topUp: Gas(oxygen: .21)),
      );
      expect(vm.failure!.code, CalculationFailureCode.impossibleMixture);
      expect(vm.result, same(old));
      expect(vm.current, isFalse);
      await vm.calculate(
        input(initial: Gas(oxygen: 1), target: Gas(oxygen: .21), start: 200),
      );
      expect(vm.current, isTrue);
      expect(vm.result!.drainedBar, greaterThan(0));
    },
  );
}
