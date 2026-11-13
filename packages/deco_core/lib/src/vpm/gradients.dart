import 'dart:math' as math;
import '../model/gas.dart';
import '../model/vpm_parameters.dart';
import '../model/vpm_state.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';

final class VpmGradients {
  VpmGradients({
    required this.parameters,
    required this.kinetics,
    required this.budget,
  });
  final VpmParameters parameters;
  final TissueKinetics kinetics;
  final CalculationBudget budget;

  double ceilingMetres(
    VpmState bubble,
    TissueState tissues,
    PressureContext pressure, {
    bool boyle = false,
  }) {
    final n = boyle
        ? bubble.boyleGradientNitrogenBar
        : bubble.allowableGradientNitrogenBar;
    final h = boyle
        ? bubble.boyleGradientHeliumBar
        : bubble.allowableGradientHeliumBar;
    var maximum = 0.0;
    for (var i = 0; i < 16; i++) {
      final total = tissues.nitrogenBar[i] + tissues.heliumBar[i];
      final gradient = total == 0
          ? math.min(n[i], h[i])
          : (n[i] * tissues.nitrogenBar[i] + h[i] * tissues.heliumBar[i]) /
                total;
      maximum = math.max(
        maximum,
        math.max(0, total + parameters.otherGasesBar - gradient),
      );
    }
    return math.max(0, pressure.depthMetres(maximum));
  }

  VpmState boyleCompensation(
    VpmState bubble, {
    required double nextDepthMetres,
    required PressureContext pressure,
  }) {
    final first = pressure.ambientBar(bubble.maximumFirstStopMetres) * 1e5;
    final next = pressure.ambientBar(nextDepthMetres) * 1e5;
    if (next > first) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Boyle target cannot exceed maximum first-stop pressure.',
      );
    }
    List<double> compensate(List<double> gradients) =>
        gradients.map((gradient) {
          budget.consume();
          if (gradient <= 0) {
            throw const CalculationFailure(
              CalculationFailureCode.invalidInput,
              'Boyle compensation needs positive allowable gradients.',
            );
          }
          if (first == next) return gradient;
          final g = gradient * 1e5;
          final a = next / (first + g), b = g / (first + g);
          final upper = math.pow(first / next, 1 / 3).toDouble();
          final x = solveBracketed(
            function: (x) => a * x * x * x + b * x * x - 1,
            lower: 1,
            upper: upper,
            budget: budget,
            residualTolerance: 1e-12,
            positionTolerance: 1e-13,
          ).value;
          return gradient / x;
        }).toList();
    return bubble.copyWith(
      boyleGradientNitrogenBar: compensate(bubble.allowableGradientNitrogenBar),
      boyleGradientHeliumBar: compensate(bubble.allowableGradientHeliumBar),
    );
  }

  VpmState phaseVolume(
    VpmState bubble, {
    required TissueState surfaceTissues,
    required PressureContext pressure,
    required double decoDurationMin,
  }) {
    requireFinite(decoDurationMin, 'decoDurationMin', nonnegative: true);
    final inspired = (pressure.surfaceBar - pressure.waterVapourBar) * .79;
    final times = <double>[];
    for (var i = 0; i < 16; i++) {
      budget.consume();
      final n = surfaceTissues.nitrogenBar[i] - inspired;
      final h = surfaceTissues.heliumBar[i];
      final kn = math.ln2 / kinetics.nitrogenHalfTimesMin[i];
      final kh = math.ln2 / kinetics.heliumHalfTimesMin[i];
      var time = 0.0;
      if (n > 0) {
        time = (h / kh + n / kn) / (h + n);
      } else if (n == 0 && h > 0) {
        time = 1 / kh;
      } else if (h + n > 0) {
        final decayTime = math.log(-n / h) / (kn - kh);
        final integral =
            h / kh * (1 - math.exp(-kh * decayTime)) +
            n / kn * (1 - math.exp(-kn * decayTime));
        time = integral / (h + n);
      }
      requireFinite(time, 'surface phase volume', nonnegative: true);
      times.add(time);
    }
    return bubble.copyWith(
      surfacePhaseVolumeMin: times,
      totalPhaseVolumeMin: times.map((t) => t + decoDurationMin),
      decoPhaseVolumeMin: decoDurationMin,
    );
  }

  bool isConverged(VpmState bubble) => List.generate(16, (i) => i).any(
    (i) =>
        (bubble.totalPhaseVolumeMin[i] - bubble.previousPhaseVolumeMin[i])
            .abs() <=
        1,
  );

  VpmState relaxGradients(VpmState bubble) {
    List<double> relax(List<double> initial, List<double> crushing) =>
        List.generate(16, (i) {
          budget.consume();
          final time = bubble.totalPhaseVolumeMin[i];
          if (time <= 0) {
            throw const CalculationFailure(
              CalculationFailureCode.invalidInput,
              'Critical volume requires a positive phase time.',
            );
          }
          final b =
              initial[i] * 1e5 +
              parameters.lambdaPascalMinutes *
                  parameters.surfaceTension /
                  (parameters.skinCompression * time);
          final c =
              parameters.surfaceTension *
              parameters.surfaceTension *
              parameters.lambdaPascalMinutes *
              crushing[i] *
              1e5 /
              (parameters.skinCompression * parameters.skinCompression * time);
          final discriminant = b * b - 4 * c;
          if (discriminant < 0) {
            throw const CalculationFailure(
              CalculationFailureCode.nonConvergence,
              'Critical-volume equation has no real allowable gradient.',
            );
          }
          final value = (b + math.sqrt(discriminant)) / 2 / 1e5;
          requireFinite(value, 'relaxed gradient', nonnegative: true);
          return value;
        });
    return bubble.copyWith(
      allowableGradientNitrogenBar: relax(
        bubble.initialAllowableGradientNitrogenBar,
        bubble.adjustedCrushingPressureNitrogenBar,
      ),
      allowableGradientHeliumBar: relax(
        bubble.initialAllowableGradientHeliumBar,
        bubble.adjustedCrushingPressureHeliumBar,
      ),
    );
  }

  VpmState recordActualGradient(
    VpmState bubble,
    TissueState tissues,
    double ambientBar,
  ) {
    requireFinite(ambientBar, 'ambientBar', nonnegative: true);
    return bubble.copyWith(
      maxActualGradientBar: List.generate(
        16,
        (i) => math.max(
          bubble.maxActualGradientBar[i],
          tissues.nitrogenBar[i] +
              tissues.heliumBar[i] +
              parameters.otherGasesBar -
              ambientBar,
        ),
      ),
    );
  }

  double projectedAscent({
    required VpmState bubble,
    required TissueState initial,
    required double fromMetres,
    required double candidateMetres,
    required BreathingGas breathing,
    required double ascentMetresPerMin,
    required PressureContext pressure,
    required StopGrid grid,
  }) {
    requireFinite(fromMetres, 'fromMetres', nonnegative: true);
    requireFinite(candidateMetres, 'candidateMetres', nonnegative: true);
    requireFinite(ascentMetresPerMin, 'ascentMetresPerMin', nonnegative: true);
    if (ascentMetresPerMin == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Ascent rate must be positive.',
      );
    }
    var candidate = candidateMetres;
    while (candidate <= fromMetres) {
      budget.consume();
      final test = kinetics.propagate(
        initial: initial,
        pressure: pressure,
        breathing: breathing,
        startDepthMetres: fromMetres,
        endDepthMetres: candidate,
        durationMin: (fromMetres - candidate) / ascentMetresPerMin,
      );
      if (ceilingMetres(bubble, test, pressure) <= candidate) return candidate;
      candidate = candidate == 0
          ? grid.lastStopMetres
          : candidate + grid.stepMetres;
    }
    throw const CalculationFailure(
      CalculationFailureCode.nonConvergence,
      'Projected ascent has no admissible first stop.',
    );
  }
}
