import 'dart:math' as math;
import '../model/json.dart';
import '../model/gas.dart';
import '../tissues/segments.dart';
import '../numerics/failure.dart';
import '../units/units.dart';

final class OxygenState {
  OxygenState({this.cnsFraction = 0, this.otu = 0})
    : cnsUnavailableReason = null {
    final known = cnsFraction;
    if (known == null) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Use an explicit unavailable CNS state with a reason.',
      );
    }
    requireFinite(known, 'cnsFraction', nonnegative: true);
    requireFinite(otu, 'otu', nonnegative: true);
  }
  OxygenState.unavailable({required CalculationFailure reason, this.otu = 0})
    : cnsFraction = null,
      cnsUnavailableReason = reason {
    requireFinite(otu, 'otu', nonnegative: true);
    if (reason.code != CalculationFailureCode.outsideModelDomain) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'CNS unavailable reason must identify its model domain.',
      );
    }
  }
  final double? cnsFraction;
  final CalculationFailure? cnsUnavailableReason;
  final double otu;
  Map<String, Object?> toJson() => {
    'cnsFraction': cnsFraction,
    'otu': otu,
    'cnsUnavailableReason': cnsUnavailableReason?.toJson(),
  };
  factory OxygenState.fromJson(Map<String, Object?> json) {
    final otu = doubleValue(json['otu'], 'otu');
    if (json['cnsFraction'] == null) {
      return OxygenState.unavailable(
        otu: otu,
        reason: CalculationFailure.fromJson(
          objectValue(json['cnsUnavailableReason'], 'cnsUnavailableReason'),
        ),
      );
    }
    if (json['cnsUnavailableReason'] != null) {
      invalidJson('cnsUnavailableReason');
    }
    return OxygenState(
      cnsFraction: doubleValue(json['cnsFraction'], 'cnsFraction'),
      otu: otu,
    );
  }
}

abstract final class OxygenPolicy {
  static const version = 'baker-seven-bands-si90-v1';
  static const maximumOxygenAta = 1.6;
  static const _bands =
      <({double low, double high, double slope, double intercept})>[
        (low: .5, high: .6, slope: -1800, intercept: 1800),
        (low: .6, high: .7, slope: -1500, intercept: 1620),
        (low: .7, high: .8, slope: -1200, intercept: 1410),
        (low: .8, high: .9, slope: -900, intercept: 1170),
        (low: .9, high: 1.1, slope: -600, intercept: 900),
        (low: 1.1, high: 1.5, slope: -300, intercept: 570),
        (low: 1.5, high: 1.6, slope: -750, intercept: 1245),
      ];

  static OxygenState expose(
    OxygenState initial, {
    required double startOxygenBar,
    required double endOxygenBar,
    required double durationMin,
  }) {
    requireFinite(durationMin, 'durationMin', nonnegative: true);
    final start = _ata(startOxygenBar), end = _ata(endOxygenBar);
    if (durationMin == 0) return initial;
    var cns = 0.0;
    if (start == end) {
      if (start <= .5) return initial;
      final band = _bands.firstWhere((b) => start <= b.high);
      cns = durationMin / (band.slope * start + band.intercept);
    } else {
      final low = math.min(start, end), high = math.max(start, end);
      if (high <= .5) return initial;
      final rate = (high - low) / durationMin;
      for (final band in _bands) {
        final a = math.max(low, band.low), b = math.min(high, band.high);
        if (b <= a) continue;
        final firstLimit = band.slope * a + band.intercept;
        cns += _log1p(band.slope * (b - a) / firstLimit) / (band.slope * rate);
      }
    }
    final otu = initial.otu + _otuDoseAta(start, end, durationMin);
    final reason = initial.cnsUnavailableReason;
    if (reason != null) {
      return OxygenState.unavailable(reason: reason, otu: otu);
    }
    return OxygenState(cnsFraction: initial.cnsFraction! + cns, otu: otu);
  }

  static double otuDose({
    required double startOxygenBar,
    required double endOxygenBar,
    required double durationMin,
  }) {
    requireFinite(startOxygenBar, 'startOxygenBar', nonnegative: true);
    requireFinite(endOxygenBar, 'endOxygenBar', nonnegative: true);
    requireFinite(durationMin, 'durationMin', nonnegative: true);
    return _otuDoseAta(
      Units.barToAta(startOxygenBar),
      Units.barToAta(endOxygenBar),
      durationMin,
    );
  }

  static double _otuDoseAta(double start, double end, double durationMin) {
    if (durationMin == 0) return 0;
    final low = math.min(start, end), high = math.max(start, end);
    if (high <= .5) return 0;
    if (start == end) {
      final value = durationMin * math.pow(2 * (start - .5), 5 / 6);
      requireFinite(value, 'OTU dose', nonnegative: true);
      return value;
    }
    final a = math.max(low, .5), power = 11 / 6;
    final difference = a == .5
        ? math.pow(2 * (high - .5), power).toDouble()
        : math.pow(2 * (a - .5), power) *
              _expm1(power * _log1p((high - a) / (a - .5)));
    final value = 3 / 11 * difference / ((high - low) / durationMin);
    requireFinite(value, 'OTU dose', nonnegative: true);
    return value;
  }

  static OxygenState trackLinear(
    OxygenState initial, {
    required double startOxygenBar,
    required double endOxygenBar,
    required double durationMin,
  }) {
    if (durationMin == 0) return initial;
    try {
      return expose(
        initial,
        startOxygenBar: startOxygenBar,
        endOxygenBar: endOxygenBar,
        durationMin: durationMin,
      );
    } on CalculationFailure catch (error) {
      if (error.code != CalculationFailureCode.outsideModelDomain) rethrow;
      return OxygenState.unavailable(
        reason: initial.cnsUnavailableReason ?? error,
        otu:
            initial.otu +
            otuDose(
              startOxygenBar: startOxygenBar,
              endOxygenBar: endOxygenBar,
              durationMin: durationMin,
            ),
      );
    }
  }

  static OxygenState exposeSegment(
    OxygenState initial,
    PropagationSegment segment,
    PressureContext pressure,
  ) {
    final start = pressure.ambientBar(segment.startDepthMetres);
    final end = pressure.ambientBar(segment.endDepthMetres);
    final breathing = segment.breathing;
    if (breathing.mode == BreathingMode.oc) {
      return trackLinear(
        initial,
        startOxygenBar: start * breathing.gas.oxygen,
        endOxygenBar: end * breathing.gas.oxygen,
        durationMin: segment.durationMin,
      );
    }
    final setpoint = breathing.setpointBar!;
    if (start != end) {
      final fraction = (setpoint - start) / (end - start);
      if (fraction > 0 && fraction < 1) {
        final mid = trackLinear(
          initial,
          startOxygenBar: math.min(start, setpoint),
          endOxygenBar: setpoint,
          durationMin: segment.durationMin * fraction,
        );
        return trackLinear(
          mid,
          startOxygenBar: setpoint,
          endOxygenBar: math.min(end, setpoint),
          durationMin: segment.durationMin * (1 - fraction),
        );
      }
    }
    return trackLinear(
      initial,
      startOxygenBar: math.min(start, setpoint),
      endOxygenBar: math.min(end, setpoint),
      durationMin: segment.durationMin,
    );
  }

  static OxygenState surfaceInterval(OxygenState initial, double durationMin) {
    requireFinite(durationMin, 'surface interval', nonnegative: true);
    if (durationMin == 0) return initial;
    final reason = initial.cnsUnavailableReason;
    if (reason != null) {
      return OxygenState.unavailable(reason: reason, otu: initial.otu);
    }
    return OxygenState(
      cnsFraction:
          initial.cnsFraction! * math.exp(-math.ln2 * durationMin / 90),
      otu: initial.otu,
    );
  }

  static double _ata(double bar) {
    requireFinite(bar, 'oxygenBar', nonnegative: true);
    if (bar > maximumOxygenAta * Units.barPerAta) {
      throw const CalculationFailure(
        CalculationFailureCode.outsideModelDomain,
        'Oxygen exposure exceeds the published1.6ATA policy domain.',
      );
    }
    // Correct only division roundoff at the exact canonical upper boundary.
    return math.min(maximumOxygenAta, Units.barToAta(bar));
  }

  static double _log1p(double x) {
    if (x.abs() >= 1e-4) return math.log(1 + x);
    return x * (1 - x / 2 + x * x / 3 - x * x * x / 4 + x * x * x * x / 5);
  }

  static double _expm1(double x) {
    if (x.abs() >= 1e-4) return math.exp(x) - 1;
    return x * (1 + x / 2 + x * x / 6 + x * x * x / 24 + x * x * x * x / 120);
  }
}
