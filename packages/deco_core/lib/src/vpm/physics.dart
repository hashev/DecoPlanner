import 'dart:math' as math;
import '../model/vpm_parameters.dart';
import '../model/vpm_state.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../tissues/segments.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';

final class VpmPhysics {
  VpmPhysics({
    required this.parameters,
    required this.kinetics,
    required this.budget,
  });
  final VpmParameters parameters;
  final TissueKinetics kinetics;
  final CalculationBudget budget;

  VpmState crushingAfterDescent({
    required VpmState bubble,
    required TissueState initialTissues,
    required PropagationSegment segment,
    required PressureContext pressure,
  }) {
    if (segment.endDepthMetres < segment.startDepthMetres) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Crushing update requires descent or constant depth.',
      );
    }
    if (!segment.isMovement) return bubble;
    final ending = segment.propagate(initialTissues, kinetics, pressure);
    final ambientStart = pressure.ambientBar(segment.startDepthMetres);
    final ambientEnd = pressure.ambientBar(segment.endDepthMetres);
    final onset = parameters.onsetImpermeabilityBar;
    final onsetPa = onset * 1e5;
    final crushN = List<double>.of(bubble.maxCrushingPressureNitrogenBar);
    final crushHe = List<double>.of(bubble.maxCrushingPressureHeliumBar);
    final onsetAmbient = List<double>.of(bubble.ambientOnsetBar);
    final onsetTension = List<double>.of(bubble.tensionOnsetBar);
    final gammaDifference =
        parameters.skinCompression - parameters.surfaceTension;
    for (var i = 0; i < 16; i++) {
      budget.consume();
      final startTension =
          initialTissues.nitrogenBar[i] +
          initialTissues.heliumBar[i] +
          parameters.otherGasesBar;
      final endTension =
          ending.nitrogenBar[i] +
          ending.heliumBar[i] +
          parameters.otherGasesBar;
      final endGradient = ambientEnd - endTension;
      if (endGradient <= onset) {
        crushN[i] = math.max(crushN[i], endGradient);
        crushHe[i] = math.max(crushHe[i], endGradient);
        continue;
      }
      final startGradient = ambientStart - startTension;
      if (startGradient == onset) {
        onsetAmbient[i] = ambientStart;
        onsetTension[i] = startTension;
      } else if (startGradient < onset) {
        TissueState atTime(double time) => kinetics.propagate(
          initial: initialTissues,
          pressure: pressure,
          breathing: segment.breathing,
          startDepthMetres: segment.startDepthMetres,
          endDepthMetres:
              segment.startDepthMetres +
              (segment.endDepthMetres - segment.startDepthMetres) *
                  time /
                  segment.durationMin,
          durationMin: time,
        );
        final root = solveBracketed(
          function: (time) {
            final state = atTime(time);
            final ambient =
                ambientStart +
                (ambientEnd - ambientStart) * time / segment.durationMin;
            return ambient -
                state.nitrogenBar[i] -
                state.heliumBar[i] -
                parameters.otherGasesBar -
                onset;
          },
          lower: 0,
          upper: segment.durationMin,
          budget: budget,
          residualTolerance: 1e-10,
          positionTolerance: 1e-12,
        );
        final tissues = atTime(root.value);
        onsetAmbient[i] =
            ambientStart +
            (ambientEnd - ambientStart) * root.value / segment.durationMin;
        onsetTension[i] =
            tissues.nitrogenBar[i] +
            tissues.heliumBar[i] +
            parameters.otherGasesBar;
      }
      if (onsetAmbient[i] <= 0 || onsetTension[i] <= 0) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Impermeable descent needs its onset state.',
        );
      }
      double impermeable(double initialRadius) {
        final onsetRadius =
            1 / (onsetPa / (2 * gammaDifference) + 1 / initialRadius);
        final differencePa = (ambientEnd - onsetAmbient[i]) * 1e5;
        final tensionPa = onsetTension[i] * 1e5;
        final a = differencePa + tensionPa + 2 * gammaDifference / onsetRadius;
        final beta = 2 * gammaDifference / (a * onsetRadius);
        final delta = tensionPa / a;
        // Radius is microscopic: normalize by onsetRadius before solving so
        // an absolute polynomial tolerance cannot accept every trial radius.
        final x = solveBracketed(
          function: (x) => x * x * x - beta * x * x - delta,
          lower: beta,
          upper: 1,
          budget: budget,
          residualTolerance: 1e-12,
          positionTolerance: 1e-13,
        ).value;
        final result =
            (onsetPa + differencePa + tensionPa * (1 - 1 / (x * x * x))) / 1e5;
        requireFinite(
          result,
          'impermeable crushing pressure',
          nonnegative: true,
        );
        return result;
      }

      crushN[i] = math.max(
        crushN[i],
        impermeable(bubble.adjustedInitialRadiusNitrogenMetres[i]),
      );
      crushHe[i] = math.max(
        crushHe[i],
        impermeable(bubble.adjustedInitialRadiusHeliumMetres[i]),
      );
    }
    return bubble.copyWith(
      maxCrushingPressureNitrogenBar: crushN,
      maxCrushingPressureHeliumBar: crushHe,
      ambientOnsetBar: onsetAmbient,
      tensionOnsetBar: onsetTension,
      segmentStartTissues: initialTissues,
    );
  }

  VpmState regenerate(VpmState bubble, double diveTimeMin) {
    requireFinite(diveTimeMin, 'diveTimeMin', nonnegative: true);
    final decay = math.exp(-diveTimeMin / parameters.regenerationMin);
    final regenN = <double>[],
        regenHe = <double>[],
        adjustN = <double>[],
        adjustHe = <double>[];
    final gradientN = <double>[], gradientHe = <double>[];
    ({double radius, double crush, double gradient}) gas(
      double radius,
      double crushingBar,
    ) {
      final crushed = crushingBar == 0
          ? radius
          : 1 /
                (crushingBar *
                        1e5 /
                        (2 *
                            (parameters.skinCompression -
                                parameters.surfaceTension)) +
                    1 / radius);
      final regenerated = radius + (crushed - radius) * decay;
      // Algebraically cancelled ratio also defines the zero-crushing limit,
      // avoiding the source expression's0/0 when crushed==initial radius.
      final adjusted = crushingBar * (crushed / regenerated) * decay;
      final gradient =
          2 *
          parameters.surfaceTension *
          (parameters.skinCompression - parameters.surfaceTension) /
          (regenerated * parameters.skinCompression) /
          1e5;
      return (radius: regenerated, crush: adjusted, gradient: gradient);
    }

    for (var i = 0; i < 16; i++) {
      budget.consume();
      final n = gas(
        bubble.adjustedInitialRadiusNitrogenMetres[i],
        bubble.maxCrushingPressureNitrogenBar[i],
      );
      final he = gas(
        bubble.adjustedInitialRadiusHeliumMetres[i],
        bubble.maxCrushingPressureHeliumBar[i],
      );
      regenN.add(n.radius);
      regenHe.add(he.radius);
      adjustN.add(n.crush);
      adjustHe.add(he.crush);
      gradientN.add(n.gradient);
      gradientHe.add(he.gradient);
    }
    return bubble.copyWith(
      regeneratedRadiusNitrogenMetres: regenN,
      regeneratedRadiusHeliumMetres: regenHe,
      adjustedCrushingPressureNitrogenBar: adjustN,
      adjustedCrushingPressureHeliumBar: adjustHe,
      initialAllowableGradientNitrogenBar: gradientN,
      initialAllowableGradientHeliumBar: gradientHe,
      allowableGradientNitrogenBar: gradientN,
      allowableGradientHeliumBar: gradientHe,
      boyleGradientNitrogenBar: List<double>.filled(16, 0),
      boyleGradientHeliumBar: List<double>.filled(16, 0),
    );
  }
}
