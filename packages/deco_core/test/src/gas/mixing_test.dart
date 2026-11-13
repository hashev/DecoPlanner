import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final air = Gas(oxygen: .21), target = Gas(oxygen: .18, helium: .45);
  test('ideal empty fill has exact analytical component pressures', () {
    final eos = GasEquationOfState();
    final recipe = partialPressureMix(
      initialGas: air,
      initialBar: 0,
      targetGas: target,
      targetBar: 200,
      topUpGas: air,
      eos: eos,
    );
    expect(recipe.heliumMolesPerLitre * eos.rt, closeTo(90, 1e-12));
    expect(recipe.topUpMolesPerLitre * eos.rt, closeTo(200 * .37 / .79, 1e-12));
    expect(
      recipe.oxygenMolesPerLitre * eos.rt,
      closeTo(36 - .21 * (74 / .79), 1e-12),
    );
    expect(recipe.steps.last.pressureAfterBar, closeTo(200, 1e-10));
    expect(recipe.drainedPressureBar, 0);
  });
  test(
    'drain solves maximum retained component balance rather than old gas sign',
    () {
      for (final real in [false, true]) {
        final eos = GasEquationOfState(realGas: real);
        final recipe = partialPressureMix(
          initialGas: air,
          initialBar: 200,
          targetGas: target,
          targetBar: 200,
          topUpGas: air,
          eos: eos,
        );
        expect(recipe.drainedPressureBar, greaterThan(0));
        expect(recipe.topUpMolesPerLitre, closeTo(0, 1e-12));
        expect(
          recipe.retainedMolesPerLitre * .79,
          closeTo(recipe.targetMolesPerLitre * .37, 1e-12),
        );
        // Independently sum each component, using target amount from the EOS.
        expect(
          recipe.retainedMolesPerLitre * .21 + recipe.oxygenMolesPerLitre,
          closeTo(recipe.targetMolesPerLitre * .18, 1e-12),
        );
        expect(
          recipe.heliumMolesPerLitre,
          closeTo(recipe.targetMolesPerLitre * .45, 1e-12),
        );
        expect(recipe.steps.last.pressureAfterBar, closeTo(200, 3e-8));
        final moreRetained = recipe.retainedMolesPerLitre + 1e-6;
        expect(
          moreRetained * .79,
          greaterThan(recipe.targetMolesPerLitre * .37),
        );
      }
    },
  );
  test(
    'O2/He order changes intermediate steps while preserving target and amounts',
    () {
      final eos = GasEquationOfState(realGas: true);
      FillRecipe fill(FillOrder order) => partialPressureMix(
        initialGas: air,
        initialBar: 50,
        targetGas: target,
        targetBar: 200,
        topUpGas: air,
        eos: eos,
        order: order,
      );
      final oxygen = fill(FillOrder.oxygenFirst),
          helium = fill(FillOrder.heliumFirst);
      expect(oxygen.steps.first.component, FillComponent.oxygen);
      expect(helium.steps.first.component, FillComponent.helium);
      expect(
        oxygen.steps.first.pressureAfterBar,
        isNot(closeTo(helium.steps.first.pressureAfterBar, 1e-6)),
      );
      expect(oxygen.oxygenMolesPerLitre, helium.oxygenMolesPerLitre);
      expect(oxygen.heliumMolesPerLitre, helium.heliumMolesPerLitre);
      expect(oxygen.steps.last.pressureAfterBar, closeTo(200, 3e-8));
      expect(helium.steps.last.pressureAfterBar, closeTo(200, 3e-8));
    },
  );
  test(
    'nitrogen-free topup supports feasible fills and rejects missing nitrogen',
    () {
      final heliox = Gas(oxygen: .18, helium: .82);
      expect(heliox.nitrogen, 0);
      final result = partialPressureMix(
        initialGas: heliox,
        initialBar: 0,
        targetGas: heliox,
        targetBar: 200,
        topUpGas: heliox,
        eos: GasEquationOfState(),
      );
      expect(result.oxygenMolesPerLitre, closeTo(0, 1e-12));
      expect(result.heliumMolesPerLitre, closeTo(0, 1e-12));
      expect(result.steps.last.pressureAfterBar, closeTo(200, 1e-12));
      expect(
        () => partialPressureMix(
          initialGas: heliox,
          initialBar: 50,
          targetGas: air,
          targetBar: 200,
          topUpGas: heliox,
          eos: GasEquationOfState(),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.impossibleMixture,
          ),
        ),
      );
    },
  );
  test(
    'real-gas trimix remainder drains using required additions in both orders',
    () {
      final initial = Gas(oxygen: .5, helium: .3);
      final top = Gas(oxygen: .21, helium: .1);
      final eos = GasEquationOfState(realGas: true);
      for (final order in FillOrder.values) {
        final recipe = partialPressureMix(
          initialGas: initial,
          initialBar: 200,
          targetGas: target,
          targetBar: 200,
          topUpGas: top,
          eos: eos,
          order: order,
        );
        expect(recipe.drainedPressureBar, greaterThan(0));
        expect(
          recipe.retainedMolesPerLitre * .2 + recipe.topUpMolesPerLitre * .69,
          closeTo(recipe.targetMolesPerLitre * .37, 1e-12),
        );
        expect(
          recipe.retainedMolesPerLitre * .5 +
              recipe.oxygenMolesPerLitre +
              recipe.topUpMolesPerLitre * .21,
          closeTo(recipe.targetMolesPerLitre * .18, 1e-12),
        );
        expect(
          recipe.retainedMolesPerLitre * .3 +
              recipe.heliumMolesPerLitre +
              recipe.topUpMolesPerLitre * .1,
          closeTo(recipe.targetMolesPerLitre * .45, 1e-12),
        );
        expect(recipe.steps.last.pressureAfterBar, closeTo(200, 3e-8));
        expect(
          recipe.steps.every(
            (step) =>
                step.pressureAfterBar.isFinite && step.addedMolesPerLitre >= 0,
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'already correct cylinder needs no additions; arbitrary topup balances every species',
    () {
      final eos = GasEquationOfState();
      final unchanged = partialPressureMix(
        initialGas: air,
        initialBar: 200,
        targetGas: air,
        targetBar: 200,
        topUpGas: air,
        eos: eos,
      );
      expect(unchanged.steps, isEmpty);
      expect(unchanged.drainedPressureBar, 0);
      final top = Gas(oxygen: .32, helium: .1);
      final recipe = partialPressureMix(
        initialGas: air,
        initialBar: 40,
        targetGas: target,
        targetBar: 200,
        topUpGas: top,
        eos: eos,
      );
      expect(
        recipe.retainedMolesPerLitre * .79 + recipe.topUpMolesPerLitre * .58,
        closeTo(recipe.targetMolesPerLitre * .37, 1e-12),
      );
      expect(
        recipe.retainedMolesPerLitre * .21 +
            recipe.oxygenMolesPerLitre +
            recipe.topUpMolesPerLitre * .32,
        closeTo(recipe.targetMolesPerLitre * .18, 1e-12),
      );
      expect(
        recipe.heliumMolesPerLitre + recipe.topUpMolesPerLitre * .1,
        closeTo(recipe.targetMolesPerLitre * .45, 1e-12),
      );
    },
  );
}
