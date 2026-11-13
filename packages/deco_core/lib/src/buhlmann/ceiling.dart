import 'dart:math' as math;
import '../model/gas.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';
import 'coefficients.dart';

final class GradientFactors {
  GradientFactors({required this.low, required this.high}) {
    requireFinite(low, 'GF low');
    requireFinite(high, 'GF high');
    if (low <= 0 || high < low || high > 1) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Gradient factors must satisfy 0 < low <= high <= 1.',
      );
    }
  }
  final double low;
  final double high;
  double atDepth({
    required double depthMetres,
    required double firstStopMetres,
  }) {
    requireFinite(depthMetres, 'depthMetres', nonnegative: true);
    requireFinite(firstStopMetres, 'firstStopMetres', nonnegative: true);
    if (firstStopMetres == 0 || depthMetres == 0) return high;
    if (depthMetres >= firstStopMetres) return low;
    return high + (low - high) * (depthMetres / firstStopMetres).clamp(0, 1);
  }
}

final class CeilingResult {
  CeilingResult({
    required this.absoluteBar,
    required this.depthMetres,
    required this.leadingTissue,
    required Iterable<double> tissueCeilingsBar,
  }) : tissueCeilingsBar = List.unmodifiable(tissueCeilingsBar);
  final double absoluteBar;
  final double depthMetres;
  final int? leadingTissue;
  final List<double> tissueCeilingsBar;
}

final class BuhlmannModel {
  BuhlmannModel(this.coefficients);
  final BuhlmannCoefficients coefficients;

  ({double a, double b}) mixedCoefficients(TissueState state, int index) {
    final n2 = state.nitrogenBar[index];
    final he = state.heliumBar[index];
    final total = n2 + he;
    if (total == 0) return (a: 0, b: 1);
    return (
      a: (n2 * coefficients.n2A[index] + he * coefficients.heA[index]) / total,
      b: (n2 * coefficients.n2B[index] + he * coefficients.heB[index]) / total,
    );
  }

  CeilingResult ceiling(
    TissueState state,
    double gf,
    PressureContext pressure,
  ) {
    requireFinite(gf, 'gradient factor');
    if (gf <= 0 || gf > 1) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Gradient factor must be in (0,1].',
      );
    }
    var maximum = 0.0;
    int? leading;
    final ceilings = <double>[];
    for (var i = 0; i < 16; i++) {
      final total = state.nitrogenBar[i] + state.heliumBar[i];
      final mix = mixedCoefficients(state, i);
      final value = total == 0
          ? 0.0
          : math.max(0.0, (total - gf * mix.a) / (gf / mix.b - gf + 1));
      requireFinite(value, 'tissue ceiling', nonnegative: true);
      ceilings.add(value);
      if (value > maximum) {
        maximum = value;
        leading = i;
      }
    }
    return CeilingResult(
      absoluteBar: maximum,
      depthMetres: math.max(0, pressure.depthMetres(maximum)),
      leadingTissue: leading,
      tissueCeilingsBar: ceilings,
    );
  }

  /// Deepen the low-GF candidate until travel to it clears its own ceiling.
  /// No decompression stop is executed here; the schedule retains the source.
  double firstStop({
    required TissueState state,
    required double currentDepthMetres,
    required double ascentMetresPerMin,
    required BreathingGas breathing,
    required GradientFactors gf,
    required PressureContext pressure,
    required StopGrid grid,
    required CalculationBudget budget,
  }) {
    requireFinite(currentDepthMetres, 'currentDepthMetres', nonnegative: true);
    requireFinite(ascentMetresPerMin, 'ascentMetresPerMin', nonnegative: true);
    if (ascentMetresPerMin == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Ascent rate must be positive.',
      );
    }
    var candidate = grid.atOrDeeper(
      ceiling(state, gf.low, pressure).depthMetres,
    );
    while (candidate <= currentDepthMetres) {
      budget.consume();
      final projected = coefficients.kinetics.propagate(
        initial: state,
        pressure: pressure,
        breathing: breathing,
        startDepthMetres: currentDepthMetres,
        endDepthMetres: candidate,
        durationMin: (currentDepthMetres - candidate) / ascentMetresPerMin,
      );
      if (ceiling(projected, gf.low, pressure).depthMetres <= candidate) {
        while (candidate > 0) {
          budget.consume();
          final shallower = grid.nextShallower(candidate);
          final test = coefficients.kinetics.propagate(
            initial: state,
            pressure: pressure,
            breathing: breathing,
            startDepthMetres: currentDepthMetres,
            endDepthMetres: shallower,
            durationMin: (currentDepthMetres - shallower) / ascentMetresPerMin,
          );
          if (ceiling(test, gf.low, pressure).depthMetres > shallower) break;
          candidate = shallower;
        }
        return candidate;
      }
      candidate = candidate == 0
          ? grid.lastStopMetres
          : candidate + grid.stepMetres;
    }
    throw const CalculationFailure(
      CalculationFailureCode.nonConvergence,
      'No first-stop candidate at or below the current depth clears its ceiling.',
    );
  }
}
