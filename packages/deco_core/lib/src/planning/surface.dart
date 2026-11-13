import 'dart:math' as math;
import '../buhlmann/coefficients.dart';
import '../model/calculation_state.dart';
import '../model/gas.dart';
import '../model/request.dart';
import '../model/vpm_state.dart';
import '../model/vpm_parameters.dart';
import '../numerics/failure.dart';
import '../oxygen/oxygen.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';

/// First-layer US Standard Atmosphere1976, geometric altitude in metres.
/// Sea-level calibration remains physical data when display units change.
double barometricPressureBar(
  double altitudeMetres, {
  double seaLevelBar = Units.barPerAta,
}) {
  requireFinite(altitudeMetres, 'altitudeMetres', nonnegative: true);
  requireFinite(seaLevelBar, 'seaLevelBar', nonnegative: true);
  if (altitudeMetres > 11000 || seaLevelBar == 0) {
    throw const CalculationFailure(
      CalculationFailureCode.outsideModelDomain,
      'Atmosphere model requires altitude0–11000m and positive sea-level pressure.',
    );
  }
  final height = altitudeMetres / 1000;
  final geopotential = height * 6369 / (height + 6369);
  final temperature = 288.15 - 6.5 * geopotential;
  final factor = 9.80665 * 28.9644 / 8.31432;
  final pressure =
      seaLevelBar * math.exp(math.log(288.15 / temperature) * factor / (-6.5));
  requireFinite(pressure, 'barometric pressure', nonnegative: true);
  return pressure;
}

final class PreparedSurfaceState {
  const PreparedSurfaceState(this.pressure, this.state);
  final PressureContext pressure;
  final CalculationState state;
}

OxygenState _surfaceAir(
  OxygenState oxygen,
  double startBar,
  double endBar,
  double minutes,
) {
  final start = startBar * .21,
      end = endBar * .21,
      threshold = Units.ataToBar(.5);
  if (math.max(start, end) <= threshold) {
    return OxygenPolicy.surfaceInterval(oxygen, minutes);
  }
  if (math.min(start, end) > threshold) {
    return OxygenPolicy.trackLinear(
      oxygen,
      startOxygenBar: start,
      endOxygenBar: end,
      durationMin: minutes,
    );
  }
  final fraction = (threshold - start) / (end - start);
  if (start > threshold) {
    final mid = OxygenPolicy.trackLinear(
      oxygen,
      startOxygenBar: start,
      endOxygenBar: threshold,
      durationMin: minutes * fraction,
    );
    return OxygenPolicy.surfaceInterval(mid, minutes * (1 - fraction));
  }
  final mid = OxygenPolicy.surfaceInterval(oxygen, minutes * fraction);
  return OxygenPolicy.trackLinear(
    mid,
    startOxygenBar: threshold,
    endOxygenBar: end,
    durationMin: minutes * (1 - fraction),
  );
}

PreparedSurfaceState prepareInitialSurface(
  CalculationSettings settings, {
  CalculationState? supplied,
}) {
  final altitude = settings.altitude;
  final pressure = altitude.enabled
      ? PressureContext(
          surfaceBar: barometricPressureBar(
            altitude.diveAltitudeMetres,
            seaLevelBar: altitude.seaLevelBar,
          ),
          waterVapourBar: settings.pressure.waterVapourBar,
          barPerMetre: settings.pressure.barPerMetre,
        )
      : settings.pressure;
  if (supplied != null) return PreparedSurfaceState(pressure, supplied);
  final parameters = settings.vpm;
  final kinetics = BuhlmannCoefficients.b().kinetics;
  final isVpm = settings.model == DecompressionModel.vpmB;
  final startPressure = altitude.enabled && !altitude.acclimatized
      ? barometricPressureBar(
          altitude.initialAltitudeMetres,
          seaLevelBar: altitude.seaLevelBar,
        )
      : pressure.surfaceBar;
  var tissues = TissueState.equilibrium(
    inspiredNitrogenBar: (startPressure - pressure.waterVapourBar) * .79,
  );
  var oxygen = OxygenState();
  VpmState? bubble = isVpm
      ? VpmState.initial(
          parameters: parameters,
          conservatism: settings.vpmConservatism,
          tissues: tissues,
          pressure: pressure,
        )
      : null;
  if (altitude.enabled && !altitude.acclimatized) {
    final old = tissues;
    final rate =
        (pressure.surfaceBar - startPressure) / altitude.travelMin * .79;
    tissues = TissueState(
      nitrogenBar: List.generate(
        16,
        (i) => schreiner(
          initial: old.nitrogenBar[i],
          inspiredStart: (startPressure - pressure.waterVapourBar) * .79,
          inspiredRate: rate,
          durationMin: altitude.travelMin,
          rateConstant: math.ln2 / kinetics.nitrogenHalfTimesMin[i],
        ),
      ),
      heliumBar: old.heliumBar,
    );
    oxygen = _surfaceAir(
      oxygen,
      startPressure,
      pressure.surfaceBar,
      altitude.travelMin,
    );
    if (bubble != null) {
      final decay = math.exp(-altitude.waitMin / parameters.regenerationMin);
      List<double> adjusted(List<double> radii) => List.generate(16, (i) {
        final radius = radii[i];
        final gradient =
            (tissues.nitrogenBar[i] +
                tissues.heliumBar[i] +
                parameters.otherGasesBar -
                pressure.surfaceBar) *
            1e5;
        final critical =
            2 *
            parameters.surfaceTension *
            (parameters.skinCompression - parameters.surfaceTension) /
            (radius * parameters.skinCompression);
        if (gradient > critical) {
          final formed =
              2 *
              parameters.surfaceTension *
              (parameters.skinCompression - parameters.surfaceTension) /
              (gradient * parameters.skinCompression);
          return radius + (radius - formed) * decay;
        }
        final denominator =
            gradient /
                (2 * (parameters.surfaceTension - parameters.skinCompression)) +
            1 / radius;
        if (denominator <= 0) {
          throw const CalculationFailure(
            CalculationFailureCode.nonConvergence,
            'Altitude radius equation has no positive radius.',
          );
        }
        final expanded = 1 / denominator;
        return radius + (expanded - radius) * decay;
      });
      final n = adjusted(bubble.initialRadiusNitrogenMetres),
          h = adjusted(bubble.initialRadiusHeliumMetres);
      bubble = bubble.copyWith(
        initialRadiusNitrogenMetres: n,
        initialRadiusHeliumMetres: h,
        adjustedInitialRadiusNitrogenMetres: n,
        adjustedInitialRadiusHeliumMetres: h,
        regeneratedRadiusNitrogenMetres: n,
        regeneratedRadiusHeliumMetres: h,
      );
    }
    tissues = kinetics.propagate(
      initial: tissues,
      pressure: pressure,
      breathing: BreathingGas.oc(Gas(oxygen: .21)),
      startDepthMetres: 0,
      endDepthMetres: 0,
      durationMin: altitude.waitMin,
    );
    oxygen = _surfaceAir(
      oxygen,
      pressure.surfaceBar,
      pressure.surfaceBar,
      altitude.waitMin,
    );
  }
  bubble = bubble?.copyWith(
    decoStartTissues: tissues,
    ascentStartTissues: tissues,
    segmentStartTissues: tissues,
  );
  return PreparedSurfaceState(
    pressure,
    CalculationState(tissues: tissues, oxygen: oxygen, vpm: bubble),
  );
}

/// Commit instantaneous post-dive excitation at the result boundary. Subsequent
/// SI0 is identity; positive surface time relaxes the committed radius to base.
VpmState finalizeSurfaceBubbles(VpmState bubble, VpmParameters parameters) {
  List<double> excite(
    List<double> base,
    List<double> initialGradient,
    List<double> crushing,
  ) => List.generate(16, (i) {
    if (bubble.maxActualGradientBar[i] <= initialGradient[i]) return base[i];
    final denominator =
        bubble.maxActualGradientBar[i] * 1e5 * parameters.skinCompression -
        parameters.surfaceTension * crushing[i] * 1e5;
    if (denominator <= 0) {
      throw const CalculationFailure(
        CalculationFailureCode.nonConvergence,
        'Repetitive excitation requires a positive radius denominator.',
      );
    }
    final radius =
        2 *
        parameters.surfaceTension *
        (parameters.skinCompression - parameters.surfaceTension) /
        denominator;
    return base[i] + (base[i] - radius);
  });
  return bubble.copyWith(
    adjustedInitialRadiusNitrogenMetres: excite(
      bubble.initialRadiusNitrogenMetres,
      bubble.initialAllowableGradientNitrogenBar,
      bubble.adjustedCrushingPressureNitrogenBar,
    ),
    adjustedInitialRadiusHeliumMetres: excite(
      bubble.initialRadiusHeliumMetres,
      bubble.initialAllowableGradientHeliumBar,
      bubble.adjustedCrushingPressureHeliumBar,
    ),
  );
}

CalculationState recoverSurface(
  CalculationState initial,
  double minutes, {
  required PressureContext pressure,
  required TissueKinetics kinetics,
  required VpmParameters parameters,
}) {
  requireFinite(minutes, 'surface interval', nonnegative: true);
  if (minutes == 0) return initial;
  final tissues = kinetics.propagate(
    initial: initial.tissues,
    pressure: pressure,
    breathing: BreathingGas.oc(Gas(oxygen: .21)),
    startDepthMetres: 0,
    endDepthMetres: 0,
    durationMin: minutes,
  );
  var bubble = initial.vpm;
  if (bubble != null) {
    final decay = math.exp(-minutes / parameters.regenerationMin);
    List<double> radii(List<double> base, List<double> current) =>
        List.generate(16, (i) => base[i] + (current[i] - base[i]) * decay);
    bubble = bubble.copyWith(
      adjustedInitialRadiusNitrogenMetres: radii(
        bubble.initialRadiusNitrogenMetres,
        bubble.adjustedInitialRadiusNitrogenMetres,
      ),
      adjustedInitialRadiusHeliumMetres: radii(
        bubble.initialRadiusHeliumMetres,
        bubble.adjustedInitialRadiusHeliumMetres,
      ),
    );
  }
  return CalculationState(
    tissues: tissues,
    oxygen: _surfaceAir(
      initial.oxygen,
      pressure.surfaceBar,
      pressure.surfaceBar,
      minutes,
    ),
    vpm: bubble,
  );
}
