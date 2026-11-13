import 'dart:math' as math;
import '../model/gas.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../units/units.dart';
import 'equation_of_state.dart';

enum FillOrder { oxygenFirst, heliumFirst }

enum FillComponent { oxygen, helium, topUp }

final class FillStep {
  const FillStep({
    required this.component,
    required this.addedMolesPerLitre,
    required this.pressureAfterBar,
    required this.resultingGas,
  });
  final FillComponent component;
  final double addedMolesPerLitre, pressureAfterBar;
  final Gas resultingGas;
}

final class FillRecipe {
  FillRecipe({
    required this.retainedPressureBar,
    required this.drainedPressureBar,
    required this.retainedMolesPerLitre,
    required this.oxygenMolesPerLitre,
    required this.heliumMolesPerLitre,
    required this.topUpMolesPerLitre,
    required this.targetMolesPerLitre,
    required Iterable<FillStep> steps,
  }) : steps = List.unmodifiable(steps);
  final double retainedPressureBar, drainedPressureBar, retainedMolesPerLitre;
  final double oxygenMolesPerLitre, heliumMolesPerLitre, topUpMolesPerLitre;
  final double targetMolesPerLitre;
  final List<FillStep> steps;
}

/// Maximize retained starting gas subject to nonnegative additions of pure O2,
/// pure He and the selected top-up gas. Balance is solved in molar amounts,
/// never by testing the starting component in place of the required addition.
FillRecipe partialPressureMix({
  required Gas initialGas,
  required double initialBar,
  required Gas targetGas,
  required double targetBar,
  required Gas topUpGas,
  required GasEquationOfState eos,
  FillOrder order = FillOrder.oxygenFirst,
  CalculationBudget? budget,
}) {
  requireFinite(initialBar, 'initialBar', nonnegative: true);
  requireFinite(targetBar, 'targetBar', nonnegative: true);
  if (targetBar == 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Target pressure must be positive.',
    );
  }
  final limits = budget ?? CalculationBudget();
  final start = eos.molesPerLitre(initialBar, initialGas, limits);
  final target = eos.molesPerLitre(targetBar, targetGas, limits);
  final targetO = target * targetGas.oxygen,
      targetHe = target * targetGas.helium,
      targetN = target * targetGas.nitrogen;
  final numericalTolerance =
      64 * 2.220446049250313e-16 * math.max(1, math.max(start, target));
  var lower = 0.0, upper = start;
  Never impossible() => throw const CalculationFailure(
    CalculationFailureCode.impossibleMixture,
    'No feasible fill from the available component gases.',
  );
  // Each component addition is a+b*retained, constrained >=0.
  void constrain(double a, double b) {
    if (b > 0) {
      lower = math.max(lower, -a / b);
    } else if (b < 0) {
      upper = math.min(upper, -a / b);
    } else if (a < -numericalTolerance) {
      impossible();
    }
  }

  double retained, addTop, addO, addHe;
  if (topUpGas.nitrogen > 0) {
    final topA = targetN / topUpGas.nitrogen;
    final topB = -initialGas.nitrogen / topUpGas.nitrogen;
    constrain(topA, topB);
    constrain(
      targetO - topUpGas.oxygen * topA,
      -initialGas.oxygen - topUpGas.oxygen * topB,
    );
    constrain(
      targetHe - topUpGas.helium * topA,
      -initialGas.helium - topUpGas.helium * topB,
    );
    if (lower > upper + numericalTolerance ||
        upper < -numericalTolerance ||
        lower > start + numericalTolerance) {
      impossible();
    }
    retained = math.min(start, math.max(0, upper));
    addTop = topA + topB * retained;
    addO = targetO - retained * initialGas.oxygen - topUpGas.oxygen * addTop;
    addHe = targetHe - retained * initialGas.helium - topUpGas.helium * addTop;
  } else {
    if (initialGas.nitrogen > 0) {
      retained = targetN / initialGas.nitrogen;
      if (retained > start + numericalTolerance) impossible();
    } else {
      if (targetN > numericalTolerance) impossible();
      constrain(targetO, -initialGas.oxygen);
      constrain(targetHe, -initialGas.helium);
      if (lower > upper + numericalTolerance || upper < -numericalTolerance) {
        impossible();
      }
      retained = math.min(start, math.max(0, upper));
    }
    final needO = targetO - retained * initialGas.oxygen;
    final needHe = targetHe - retained * initialGas.helium;
    if (needO < -numericalTolerance || needHe < -numericalTolerance) {
      impossible();
    }
    final choices = <double>[
      if (topUpGas.oxygen > 0) needO / topUpGas.oxygen,
      if (topUpGas.helium > 0) needHe / topUpGas.helium,
    ];
    addTop = choices.reduce(math.min);
    addO = needO - topUpGas.oxygen * addTop;
    addHe = needHe - topUpGas.helium * addTop;
  }
  double nonnegative(double value) {
    requireFinite(value, 'component amount');
    if (value < -numericalTolerance) impossible();
    // Only analytically-zero roundoff within the stated 64-ULP amount bound.
    return value < 0 ? 0 : value;
  }

  retained = nonnegative(retained);
  addTop = nonnegative(addTop);
  addO = nonnegative(addO);
  addHe = nonnegative(addHe);
  var oxygen = retained * initialGas.oxygen;
  var helium = retained * initialGas.helium;
  var nitrogen = retained * initialGas.nitrogen;
  final retainedBar = retained == start
      ? initialBar
      : eos.pressureBar(retained, initialGas);
  final steps = <FillStep>[];
  void add(FillComponent component, double amount, Gas gas) {
    if (amount == 0) return;
    oxygen += amount * gas.oxygen;
    helium += amount * gas.helium;
    nitrogen += amount * gas.nitrogen;
    final total = oxygen + helium + nitrogen;
    final o = oxygen / total;
    final h = nitrogen == 0 ? 1 - o : helium / total;
    final mix = Gas(oxygen: o, helium: h);
    steps.add(
      FillStep(
        component: component,
        addedMolesPerLitre: amount,
        pressureAfterBar: eos.pressureBar(total, mix),
        resultingGas: mix,
      ),
    );
  }

  if (order == FillOrder.oxygenFirst) {
    add(FillComponent.oxygen, addO, Gas(oxygen: 1));
    add(FillComponent.helium, addHe, Gas(oxygen: 0, helium: 1));
  } else {
    add(FillComponent.helium, addHe, Gas(oxygen: 0, helium: 1));
    add(FillComponent.oxygen, addO, Gas(oxygen: 1));
  }
  add(FillComponent.topUp, addTop, topUpGas);
  if ((oxygen - targetO).abs() > numericalTolerance * 4 ||
      (helium - targetHe).abs() > numericalTolerance * 4 ||
      (nitrogen - targetN).abs() > numericalTolerance * 4) {
    throw const CalculationFailure(
      CalculationFailureCode.nonConvergence,
      'Fill component balance residual exceeded its roundoff bound.',
    );
  }
  return FillRecipe(
    retainedPressureBar: retainedBar,
    drainedPressureBar: math.max(0, initialBar - retainedBar),
    retainedMolesPerLitre: retained,
    oxygenMolesPerLitre: addO,
    heliumMolesPerLitre: addHe,
    topUpMolesPerLitre: addTop,
    targetMolesPerLitre: target,
    steps: steps,
  );
}
