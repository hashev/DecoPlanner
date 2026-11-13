import 'dart:math' as math;
import '../model/gas.dart';
import '../model/json.dart';
import '../numerics/failure.dart';
import '../units/units.dart';

List<double> checkedCompartments(
  Iterable<double> values,
  String name, {
  bool positive = false,
}) {
  final copy = List<double>.unmodifiable(values);
  if (copy.length != 16) {
    throw CalculationFailure(
      CalculationFailureCode.invalidInput,
      '$name must contain exactly sixteen values.',
    );
  }
  for (final value in copy) {
    requireFinite(value, name, nonnegative: true);
    if (positive && value == 0) {
      throw CalculationFailure(
        CalculationFailureCode.invalidInput,
        '$name must be positive.',
      );
    }
  }
  return copy;
}

final class TissueState {
  TissueState({
    required Iterable<double> nitrogenBar,
    required Iterable<double> heliumBar,
  }) : nitrogenBar = checkedCompartments(nitrogenBar, 'nitrogenBar'),
       heliumBar = checkedCompartments(heliumBar, 'heliumBar');
  factory TissueState.equilibrium({required double inspiredNitrogenBar}) =>
      TissueState(
        nitrogenBar: List.filled(16, inspiredNitrogenBar),
        heliumBar: List.filled(16, 0),
      );
  final List<double> nitrogenBar;
  final List<double> heliumBar;
  Map<String, Object> toJson() => {
    'nitrogenBar': nitrogenBar,
    'heliumBar': heliumBar,
  };
  factory TissueState.fromJson(Map<String, Object?> json) => TissueState(
    nitrogenBar: listValue(
      json['nitrogenBar'],
      'nitrogenBar',
    ).map((v) => doubleValue(v, 'nitrogenBar')),
    heliumBar: listValue(
      json['heliumBar'],
      'heliumBar',
    ).map((v) => doubleValue(v, 'heliumBar')),
  );
}

final class TissueKinetics {
  TissueKinetics({
    required Iterable<double> nitrogenHalfTimesMin,
    required Iterable<double> heliumHalfTimesMin,
  }) : nitrogenHalfTimesMin = checkedCompartments(
         nitrogenHalfTimesMin,
         'nitrogenHalfTimesMin',
         positive: true,
       ),
       heliumHalfTimesMin = checkedCompartments(
         heliumHalfTimesMin,
         'heliumHalfTimesMin',
         positive: true,
       );
  final List<double> nitrogenHalfTimesMin;
  final List<double> heliumHalfTimesMin;

  TissueState propagate({
    required TissueState initial,
    required PressureContext pressure,
    required BreathingGas breathing,
    required double startDepthMetres,
    required double endDepthMetres,
    required double durationMin,
  }) {
    requireFinite(durationMin, 'durationMin', nonnegative: true);
    final ambientStart = pressure.ambientBar(startDepthMetres);
    final ambientEnd = pressure.ambientBar(endDepthMetres);
    if (durationMin == 0) {
      if (startDepthMetres != endDepthMetres) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Movement cannot take zero time.',
        );
      }
      return initial;
    }
    TissueState advance(TissueState state, double a, double b, double dt) {
      final start = inspiredInert(a, pressure.waterVapourBar, breathing);
      final end = inspiredInert(b, pressure.waterVapourBar, breathing);
      List<double> evolve(
        List<double> old,
        List<double> half,
        double pi0,
        double pi1,
      ) => List.generate(
        16,
        (i) => schreiner(
          initial: old[i],
          inspiredStart: pi0,
          inspiredRate: (pi1 - pi0) / dt,
          durationMin: dt,
          rateConstant: math.ln2 / half[i],
        ),
      );
      return TissueState(
        nitrogenBar: evolve(
          state.nitrogenBar,
          nitrogenHalfTimesMin,
          start.nitrogen,
          end.nitrogen,
        ),
        heliumBar: evolve(
          state.heliumBar,
          heliumHalfTimesMin,
          start.helium,
          end.helium,
        ),
      );
    }

    // Split the CCR clipping kink exactly in ambient pressure coordinates.
    final transition = breathing.setpointBar;
    if (transition != null && ambientStart != ambientEnd) {
      final splitAmbient = transition + pressure.waterVapourBar;
      final fraction =
          (splitAmbient - ambientStart) / (ambientEnd - ambientStart);
      if (fraction > 0 && fraction < 1) {
        final mid = advance(
          initial,
          ambientStart,
          splitAmbient,
          durationMin * fraction,
        );
        return advance(
          mid,
          splitAmbient,
          ambientEnd,
          durationMin * (1 - fraction),
        );
      }
    }
    return advance(initial, ambientStart, ambientEnd, durationMin);
  }
}

({double nitrogen, double helium}) inspiredInert(
  double ambientBar,
  double vapourBar,
  BreathingGas breathing,
) {
  requireFinite(ambientBar, 'ambientBar', nonnegative: true);
  requireFinite(vapourBar, 'vapourBar', nonnegative: true);
  final dry = ambientBar - vapourBar;
  if (dry < 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Ambient pressure below water vapour pressure.',
    );
  }
  final gas = breathing.gas;
  if (breathing.mode == BreathingMode.oc) {
    return (nitrogen: dry * gas.nitrogen, helium: dry * gas.helium);
  }
  final inert = math.max(0.0, dry - breathing.setpointBar!);
  final inertFraction = gas.nitrogen + gas.helium;
  return (
    nitrogen: inert * gas.nitrogen / inertFraction,
    helium: inert * gas.helium / inertFraction,
  );
}

double haldane({
  required double initial,
  required double inspired,
  required double durationMin,
  required double rateConstant,
}) => schreiner(
  initial: initial,
  inspiredStart: inspired,
  inspiredRate: 0,
  durationMin: durationMin,
  rateConstant: rateConstant,
);

double schreiner({
  required double initial,
  required double inspiredStart,
  required double inspiredRate,
  required double durationMin,
  required double rateConstant,
}) {
  requireFinite(initial, 'initial', nonnegative: true);
  requireFinite(inspiredStart, 'inspiredStart', nonnegative: true);
  requireFinite(inspiredRate, 'inspiredRate');
  requireFinite(durationMin, 'durationMin', nonnegative: true);
  requireFinite(rateConstant, 'rateConstant', nonnegative: true);
  if (rateConstant == 0 ||
      inspiredStart + inspiredRate * durationMin < -1e-12) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Invalid inspired pressure trajectory or rate constant.',
    );
  }
  if (durationMin == 0) return initial;
  if (inspiredRate == 0) {
    final value =
        inspiredStart +
        (initial - inspiredStart) * math.exp(-rateConstant * durationMin);
    requireFinite(value, 'tissue pressure', nonnegative: true);
    return value;
  }
  final x = rateConstant * durationMin;
  // Stable 1-exp(-x), and x-(1-exp(-x)) for very short segments.
  final uptake = x < 1e-4
      ? x * (1 - x / 2 + x * x / 6 - x * x * x / 24)
      : 1 - math.exp(-x);
  final ramp = x < 1e-4
      ? x * x * (.5 - x / 6 + x * x / 24 - x * x * x / 120)
      : x - uptake;
  final value =
      initial +
      (inspiredStart - initial) * uptake +
      inspiredRate / rateConstant * ramp;
  requireFinite(value, 'tissue pressure', nonnegative: true);
  return value;
}
