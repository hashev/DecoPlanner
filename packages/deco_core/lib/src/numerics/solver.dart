import 'failure.dart';

/// Shared request budget. Cancellation/time checks are cooperative; the worker
/// must terminate its isolate to interrupt a blocking callback.
final class CalculationBudget {
  CalculationBudget({
    this.maxIterations = 100000,
    this.maxElapsed = const Duration(seconds: 10),
    bool Function()? isCancelled,
  }) : _isCancelled = isCancelled,
       _clock = Stopwatch()..start() {
    if (maxIterations <= 0 || maxElapsed.isNegative) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Budget must have positive iterations and nonnegative elapsed time.',
      );
    }
  }

  final int maxIterations;
  final Duration maxElapsed;
  final bool Function()? _isCancelled;
  final Stopwatch _clock;
  int _iterations = 0;
  int get iterations => _iterations;

  void check({bool includeIterations = true}) {
    if (_isCancelled?.call() ?? false) {
      throw CalculationFailure(
        CalculationFailureCode.cancelled,
        'Calculation cancelled.',
        iterations: _iterations,
      );
    }
    if (_clock.elapsed >= maxElapsed ||
        (includeIterations && _iterations >= maxIterations)) {
      throw CalculationFailure(
        CalculationFailureCode.budgetExceeded,
        'Calculation budget exhausted.',
        iterations: _iterations,
      );
    }
  }

  void consume() {
    check();
    _iterations++;
  }
}

final class RootSolution {
  const RootSolution(this.value, this.residual, this.iterations);
  final double value;
  final double residual;
  final int iterations;
}

/// Bracket-preserving bisection. Width alone never establishes a root: a
/// discontinuity with opposite endpoint signs must fail the residual test.
RootSolution solveBracketed({
  required double Function(double) function,
  required double lower,
  required double upper,
  required CalculationBudget budget,
  double residualTolerance = 1e-10,
  double positionTolerance = 1e-12,
  int maxIterations = 256,
}) {
  if (!lower.isFinite ||
      !upper.isFinite ||
      lower >= upper ||
      !residualTolerance.isFinite ||
      residualTolerance <= 0 ||
      !positionTolerance.isFinite ||
      positionTolerance <= 0 ||
      maxIterations <= 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Invalid root search parameters.',
    );
  }
  final startIterations = budget.iterations;
  double evaluate(double x) {
    budget.consume();
    final value = function(x);
    budget.check(includeIterations: false);
    // Check time/cancellation after callbacks, including a final successful one.
    // Iteration count was checked before invocation, so the last allowed
    // evaluation can still establish a root.
    if (!value.isFinite) {
      throw CalculationFailure(
        CalculationFailureCode.nonFinite,
        'Nonfinite root function value.',
        iterations: budget.iterations - startIterations,
      );
    }
    return value;
  }

  bool opposite(double a, double b) => a.isNegative != b.isNegative;
  var a = lower;
  var b = upper;
  var fa = evaluate(a);
  final fb = evaluate(b);
  if (fa.abs() <= residualTolerance) {
    return RootSolution(a, fa, budget.iterations - startIterations);
  }
  if (fb.abs() <= residualTolerance) {
    return RootSolution(b, fb, budget.iterations - startIterations);
  }
  if (!opposite(fa, fb)) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidBracket,
      'Endpoints do not bracket a root.',
    );
  }
  for (var i = 0; i < maxIterations; i++) {
    final width = b - a;
    final middle = width.isFinite ? a + width / 2 : a / 2 + b / 2;
    final fm = evaluate(middle);
    if (fm.abs() <= residualTolerance) {
      return RootSolution(middle, fm, budget.iterations - startIterations);
    }
    if (middle == a || middle == b || width.abs() <= positionTolerance) break;
    if (opposite(fa, fm)) {
      b = middle;
    } else {
      a = middle;
      fa = fm;
    }
  }
  throw CalculationFailure(
    CalculationFailureCode.nonConvergence,
    'No root satisfying the residual tolerance within search limits.',
    iterations: budget.iterations - startIterations,
  );
}
