import 'dart:math' as math;
import '../model/gas.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../units/units.dart';
import 'equation_of_state.dart';

enum ContinuousVariant { twoStreams, singleStream }

enum ContinuousPath { oxygenHeliumThenNitrox, nitroxThenHeliair }

enum ContinuousStepKind { oxygen, helium, blend }

final class ContinuousFillStep {
  const ContinuousFillStep({
    required this.kind,
    required this.addedMolesPerLitre,
    required this.feedGas,
    required this.resultingGas,
    required this.pressureAfterBar,
    required this.airFraction,
    required this.oxygenFraction,
    required this.heliumFraction,
  });
  final ContinuousStepKind kind;
  final double addedMolesPerLitre, pressureAfterBar;
  final Gas feedGas, resultingGas;

  /// Fractions of the source streams, all at the same reference conditions.
  final double airFraction, oxygenFraction, heliumFraction;
}

final class ContinuousRecipe {
  ContinuousRecipe({
    required this.retainedPressureBar,
    required this.drainedPressureBar,
    required this.retainedMolesPerLitre,
    required this.targetMolesPerLitre,
    required this.oxygenMolesPerLitre,
    required this.heliumMolesPerLitre,
    required this.airMolesPerLitre,
    required Iterable<ContinuousFillStep> steps,
  }) : steps = List.unmodifiable(steps);
  final double retainedPressureBar, drainedPressureBar;
  final double retainedMolesPerLitre, targetMolesPerLitre;

  /// Total purchased source amounts, including prefill and blended components.
  final double oxygenMolesPerLitre, heliumMolesPerLitre, airMolesPerLitre;
  final List<ContinuousFillStep> steps;
}

/// Jointly maximizes retained gas, then continuous addition, then the first
/// stream. Pure O2/He prefill is allowed; caps apply to each continuous feed.
ContinuousRecipe continuousMix({
  required Gas initialGas,
  required double initialBar,
  required Gas targetGas,
  required double targetBar,
  required GasEquationOfState eos,
  ContinuousVariant variant = ContinuousVariant.singleStream,
  ContinuousPath path = ContinuousPath.oxygenHeliumThenNitrox,
  double maximumOxygenFraction = 1,
  double maximumHeliumFraction = 1,
  CalculationBudget? budget,
}) {
  requireFinite(initialBar, 'initialBar', nonnegative: true);
  requireFinite(targetBar, 'targetBar', nonnegative: true);
  for (final limit in [maximumOxygenFraction, maximumHeliumFraction]) {
    requireFinite(limit, 'continuous fraction limit', nonnegative: true);
    if (limit > 1) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Continuous fraction limits must be in0..1.',
      );
    }
  }
  if (targetBar == 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Target pressure must be positive.',
    );
  }
  final limits = budget ?? CalculationBudget();
  final start = eos.molesPerLitre(initialBar, initialGas, limits);
  final target = eos.molesPerLitre(targetBar, targetGas, limits);
  // Amounts are normalized by the target amount to keep feasibility scales fixed.
  final a0 = targetGas.nitrogen / .79, ar = -initialGas.nitrogen / .79;
  final o0 = targetGas.oxygen - .21 * a0, or = -initialGas.oxygen - .21 * ar;
  final h0 = targetGas.helium, hr = -initialGas.helium;
  final o = maximumOxygenFraction, h = maximumHeliumFraction;
  final single = variant == ContinuousVariant.singleStream;
  final oxHe = path == ContinuousPath.oxygenHeliumThenNitrox;
  final n = single ? 3 : 4;
  final constraints = <_Constraint>[];
  void add(List<double> coefficients, double upper) =>
      constraints.add(_Constraint(coefficients, upper));
  for (var i = 0; i < n; i++) {
    add(List.generate(n, (j) => i == j ? -1.0 : 0.0), 0);
  }
  add([1, ...List.filled(n - 1, 0.0)], start / target);
  add([-ar, ...List.filled(n - 1, 0.0)], a0);
  late List<List<double>> objectives;
  if (single) {
    // x = retained, added O2 in feed, added He in feed.
    add([-or, 1, 0], o0);
    add([-hr, 0, 1], h0);
    add([(.21 - o) * ar, 1 - o, -o], (o - .21) * a0);
    add([-h * ar, -h, 1 - h], h * a0);
    objectives = [
      [1, 0, 0],
      [ar, 1, 1],
      [0, 1, 0],
    ];
  } else if (oxHe) {
    // x = retained, O2/He in nitrogen-free feed, added O2 in nitrox.
    add([-or, 1, 0, 1], o0);
    add([-hr, 0, 1, 0], h0);
    add([0, 1 - o, -o, 0], 0);
    add([0, -h, 1 - h, 0], 0);
    add([(.21 - o) * ar, 0, 0, 1 - o], (o - .21) * a0);
    objectives = [
      [1, 0, 0, 0],
      [ar, 1, 1, 1],
      [0, 1, 1, 0],
      [0, 1, 0, 0],
    ];
  } else {
    // x = retained, added O2 in nitrox, air in nitrox, He in heliair.
    add([-or, 1, 0, 0], o0);
    add([-hr, 0, 0, 1], h0);
    add([-ar, 0, 1, 0], a0);
    add([0, 1 - o, .21 - o, 0], 0);
    add([(.21 - o) * ar, 0, o - .21, -o], (o - .21) * a0);
    add([-h * ar, 0, h, 1 - h], h * a0);
    objectives = [
      [1, 0, 0, 0],
      [ar, 1, 0, 1],
      [0, 1, 1, 0],
      [0, 1, 0, 0],
    ];
  }
  final x = _maximize(constraints, objectives, limits);
  const tolerance = 2e-11;
  double nonnegative(double value) {
    if (!value.isFinite || value < -tolerance) {
      throw const CalculationFailure(
        CalculationFailureCode.nonConvergence,
        'Continuous allocation has an invalid amount.',
      );
    }
    return value < 0 ? 0 : value;
  }

  final retained = nonnegative(x[0]);
  final air = nonnegative(a0 + ar * retained);
  final availableO = nonnegative(o0 + or * retained);
  final availableHe = nonnegative(h0 + hr * retained);
  final feeds =
      <List<double>>[]; // source O2, He, air, in normalized molar amounts
  late double preO, preHe;
  if (single) {
    preO = nonnegative(availableO - x[1]);
    preHe = nonnegative(availableHe - x[2]);
    feeds.add([x[1], x[2], air]);
  } else if (oxHe) {
    preO = nonnegative(availableO - x[1] - x[3]);
    preHe = nonnegative(availableHe - x[2]);
    feeds.addAll([
      [x[1], x[2], 0],
      [x[3], 0, air],
    ]);
  } else {
    preO = nonnegative(availableO - x[1]);
    preHe = nonnegative(availableHe - x[3]);
    feeds.addAll([
      [x[1], 0, x[2]],
      [0, x[3], nonnegative(air - x[2])],
    ]);
  }
  var amount = retained;
  var oxygen = retained * initialGas.oxygen;
  var helium = retained * initialGas.helium;
  var nitrogen = retained * initialGas.nitrogen;
  final steps = <ContinuousFillStep>[];
  void append(ContinuousStepKind kind, List<double> source) {
    final parts = source.map(nonnegative).toList();
    final total = parts.reduce((a, b) => a + b);
    if (total == 0) return;
    final fo = (parts[0] + .21 * parts[2]) / total;
    final fh = parts[1] / total;
    if (kind == ContinuousStepKind.blend &&
        (fo > o + tolerance || fh > h + tolerance)) {
      throw const CalculationFailure(
        CalculationFailureCode.nonConvergence,
        'Continuous feed exceeds a fraction limit.',
      );
    }
    Gas composition(double oxygen, double helium, double nitrogen) {
      final sum = oxygen + helium + nitrogen;
      final f = oxygen / sum;
      return Gas(oxygen: f, helium: nitrogen == 0 ? 1 - f : helium / sum);
    }

    final feed = composition(
      parts[0] + .21 * parts[2],
      parts[1],
      .79 * parts[2],
    );
    amount += total;
    oxygen += parts[0] + .21 * parts[2];
    helium += parts[1];
    nitrogen += .79 * parts[2];
    final resulting = composition(oxygen, helium, nitrogen);
    steps.add(
      ContinuousFillStep(
        kind: kind,
        addedMolesPerLitre: total * target,
        feedGas: feed,
        resultingGas: resulting,
        pressureAfterBar: eos.pressureBar(amount * target, resulting),
        oxygenFraction: parts[0] / total,
        heliumFraction: parts[1] / total,
        airFraction: parts[2] / total,
      ),
    );
  }

  append(ContinuousStepKind.oxygen, [preO, 0, 0]);
  append(ContinuousStepKind.helium, [0, preHe, 0]);
  for (final feed in feeds) {
    append(ContinuousStepKind.blend, feed);
  }
  if ((amount - 1).abs() > tolerance ||
      (oxygen - targetGas.oxygen).abs() > tolerance ||
      (helium - targetGas.helium).abs() > tolerance ||
      (nitrogen - targetGas.nitrogen).abs() > tolerance) {
    throw const CalculationFailure(
      CalculationFailureCode.nonConvergence,
      'Continuous recipe does not satisfy the component balance.',
    );
  }
  final retainedAmount = retained * target;
  final retainedBar = (retainedAmount - start).abs() <= tolerance * target
      ? initialBar
      : eos.pressureBar(retainedAmount, initialGas);
  return ContinuousRecipe(
    retainedPressureBar: retainedBar,
    drainedPressureBar: math.max(0, initialBar - retainedBar),
    retainedMolesPerLitre: retainedAmount,
    targetMolesPerLitre: target,
    oxygenMolesPerLitre: availableO * target,
    heliumMolesPerLitre: availableHe * target,
    airMolesPerLitre: air * target,
    steps: steps,
  );
}

final class _Constraint {
  const _Constraint(this.a, this.b);
  final List<double> a;
  final double b;
}

double _dot(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

// At most four variables and fourteen half-spaces. Enumerate their vertices;
// there is no iterative repair loop or dependence on a third-party LP package.
List<double> _maximize(
  List<_Constraint> constraints,
  List<List<double>> objectives,
  CalculationBudget budget,
) {
  final n = objectives.first.length;
  List<double>? best;
  List<double>? scores;
  void evaluate(List<int> selected) {
    budget.consume();
    final rows = [
      for (final i in selected) [...constraints[i].a, constraints[i].b],
    ];
    for (var column = 0; column < n; column++) {
      var pivot = column;
      for (var row = column + 1; row < n; row++) {
        if (rows[row][column].abs() > rows[pivot][column].abs()) pivot = row;
      }
      if (rows[pivot][column].abs() < 1e-13) return;
      final swap = rows[pivot];
      rows[pivot] = rows[column];
      rows[column] = swap;
      final divisor = rows[column][column];
      for (var j = column; j <= n; j++) {
        rows[column][j] /= divisor;
      }
      for (var row = 0; row < n; row++) {
        if (row == column) continue;
        final factor = rows[row][column];
        for (var j = column; j <= n; j++) {
          rows[row][j] -= factor * rows[column][j];
        }
      }
    }
    final x = rows.map((row) => row[n]).toList();
    if (x.any((v) => !v.isFinite) ||
        constraints.any((c) => _dot(c.a, x) > c.b + 1e-12)) {
      return;
    }
    final candidate = objectives.map((a) => _dot(a, x)).toList();
    var better = best == null;
    if (!better) {
      for (var i = 0; i < candidate.length; i++) {
        final delta = candidate[i] - scores![i];
        if (delta.abs() > 1e-12) {
          better = delta > 0;
          break;
        }
      }
    }
    if (better) {
      best = x;
      scores = candidate;
    }
  }

  void choose(List<int> selected, int start) {
    if (selected.length == n) {
      evaluate(selected);
      return;
    }
    for (var i = start; i <= constraints.length - (n - selected.length); i++) {
      selected.add(i);
      choose(selected, i + 1);
      selected.removeLast();
    }
  }

  choose([], 0);
  if (best == null) {
    throw const CalculationFailure(
      CalculationFailureCode.impossibleMixture,
      'No continuous recipe satisfies the component balances and feed limits.',
    );
  }
  budget.check(includeIterations: false);
  return best!;
}
