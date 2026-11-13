import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

Matcher failure(CalculationFailureCode code) =>
    isA<CalculationFailure>().having((error) => error.code, 'code', code);

void main() {
  RootSolution solve(
    double Function(double) f,
    double lo,
    double hi, {
    CalculationBudget? budget,
    int iterations = 256,
  }) => solveBracketed(
    function: f,
    lower: lo,
    upper: hi,
    budget: budget ?? CalculationBudget(),
    maxIterations: iterations,
  );

  test('analytic root is bracketed and meets residual', () {
    final result = solve((x) => x * x - 2, 0, 2);
    expect(result.value, closeTo(math.sqrt(2), 1e-10));
    expect(result.residual.abs(), lessThanOrEqualTo(1e-10));
    expect(result.iterations, lessThanOrEqualTo(258));
  });
  test('endpoint root is valid', () {
    expect(solve((x) => x - 3, 3, 9).value, 3);
    expect(solve((x) => x - 9, 3, 9).value, 9);
  });
  test('same-sign bracket fails instead of returning a number', () {
    expect(
      () => solve((x) => x * x + 1, -1, 1),
      throwsA(failure(CalculationFailureCode.invalidBracket)),
    );
  });
  test('discontinuity cannot pass on interval width alone', () {
    expect(
      () => solve((x) => x < 0 ? -1 : 1, -1, 1),
      throwsA(failure(CalculationFailureCode.nonConvergence)),
    );
  });
  test('NaN and infinity fail at input and at function evaluation', () {
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => solve((x) => x, invalid, 1),
        throwsA(failure(CalculationFailureCode.invalidInput)),
      );
      expect(
        () => solve((x) => invalid, 0, 1),
        throwsA(failure(CalculationFailureCode.nonFinite)),
      );
    }
  });
  test('iteration budget is shared across calls', () {
    final budget = CalculationBudget(maxIterations: 4);
    solve((x) => x, 0, 1, budget: budget);
    solve((x) => x, 0, 1, budget: budget);
    expect(
      () => solve((x) => x, 0, 1, budget: budget),
      throwsA(failure(CalculationFailureCode.budgetExceeded)),
    );
  });
  test('zero time budget fails before callback', () {
    var called = false;
    expect(
      () => solve(
        (x) {
          called = true;
          return x;
        },
        0,
        1,
        budget: CalculationBudget(maxElapsed: Duration.zero),
      ),
      throwsA(failure(CalculationFailureCode.budgetExceeded)),
    );
    expect(called, isFalse);
  });
  test('time is checked after a slow callback even if root found', () {
    final budget = CalculationBudget(
      maxElapsed: const Duration(milliseconds: 5),
    );
    expect(
      () => solve(
        (x) {
          final watch = Stopwatch()..start();
          while (watch.elapsedMilliseconds < 10) {}
          return 0;
        },
        0,
        1,
        budget: budget,
      ),
      throwsA(failure(CalculationFailureCode.budgetExceeded)),
    );
  });
  test('cancellation and nonconvergence are distinct', () {
    expect(
      () => solve(
        (x) => x,
        0,
        1,
        budget: CalculationBudget(isCancelled: () => true),
      ),
      throwsA(failure(CalculationFailureCode.cancelled)),
    );
    expect(
      () => solve((x) => x * x - 2, 0, 2, iterations: 1),
      throwsA(failure(CalculationFailureCode.nonConvergence)),
    );
  });
  test('large finite interval does not overflow midpoint or sign test', () {
    expect(solve((x) => x, -1e308, 1e308).value, 0);
  });
}
