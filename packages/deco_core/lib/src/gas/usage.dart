import '../model/gas.dart';
import '../model/request.dart';
import '../model/result.dart';
import '../numerics/failure.dart';
import '../units/units.dart';

enum GasUseKind { openCircuit, ccrOxygen }

final class SegmentGasUse {
  const SegmentGasUse({
    required this.segmentIndex,
    required this.kind,
    required this.gas,
    required this.litres,
  });
  final int segmentIndex;
  final GasUseKind kind;
  final Gas gas;
  final double litres;
}

final class TimeRatio {
  TimeRatio({required this.bottomMin, required this.comparedMin}) {
    requireFinite(bottomMin, 'ratio bottomMin', nonnegative: true);
    requireFinite(comparedMin, 'ratio comparedMin', nonnegative: true);
  }
  final double bottomMin, comparedMin;
  double? get exact => bottomMin == 0 ? null : comparedMin / bottomMin;
  double? get percent => exact == null ? null : 100 * exact!;
  double? get roundedBottomUnits => exact == null
      ? null
      : exact! == 0 || exact! >= 1
      ? 1
      : (1 / exact!).roundToDouble();
  double? get roundedComparedUnits => exact == null
      ? null
      : exact! < 1
      ? (exact! == 0 ? 0 : 1)
      : (exact! * 10).roundToDouble() / 10;
  bool get roundedUnderestimates =>
      exact != null &&
      roundedComparedUnits! / roundedBottomUnits! < exact! - 1e-12;
}

final class GasUseTotal {
  const GasUseTotal({
    required this.kind,
    required this.gas,
    required this.litres,
    required this.durationMin,
    required this.decompressionMin,
    required this.stopCount,
    required this.ratio,
  });
  final GasUseKind kind;
  final Gas gas;
  final double litres, durationMin, decompressionMin;
  final int stopCount;
  final TimeRatio ratio;
  double? get averageMinPerStop =>
      stopCount == 0 ? null : decompressionMin / stopCount;
}

final class StopGroup {
  const StopGroup({
    required this.shallowestMetres,
    required this.deepestMetres,
    required this.durationMin,
    required this.stopCount,
    required this.ratio,
  });
  final double shallowestMetres, deepestMetres, durationMin;
  final int stopCount;
  final TimeRatio ratio;
  double get averageMinPerStop => durationMin / stopCount;
}

final class GasUsageReport {
  GasUsageReport({
    required Iterable<SegmentGasUse> segments,
    required Iterable<GasUseTotal> gases,
    required Iterable<StopGroup> stopGroups,
    required this.bottomMin,
    required this.ascentMin,
    required this.decompressionMin,
    required this.hasCcr,
  }) : segments = List.unmodifiable(segments),
       gases = List.unmodifiable(gases),
       stopGroups = List.unmodifiable(stopGroups);
  final List<SegmentGasUse> segments;
  final List<GasUseTotal> gases;
  final List<StopGroup> stopGroups;
  final double bottomMin, ascentMin, decompressionMin;

  /// CCR diluent/flush/leaks/loop volume are not estimated by the OCR model.
  final bool hasCcr;
  double get totalLitres => gases.fold(0.0, (sum, g) => sum + g.litres);
  TimeRatio get decompressionRatio =>
      TimeRatio(bottomMin: bottomMin, comparedMin: decompressionMin);
  TimeRatio get ascentRatio =>
      TimeRatio(bottomMin: bottomMin, comparedMin: ascentMin);
}

final class _UsageAccumulator {
  _UsageAccumulator(this.kind, this.gas);
  final GasUseKind kind;
  final Gas gas;
  double litres = 0, duration = 0, decompression = 0;
  final stops = <double>{};
}

/// Raw one-diver amounts, without reserves. RMV is multiplied by mean ambient
/// ATA; CCR metabolic oxygen uses elapsed time once, independently of depth.
GasUsageReport calculateGasUsage(
  CalculationResult result,
  CalculationSettings settings, {
  int stopsPerGroup = 5,
}) {
  if (stopsPerGroup <= 0) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Stop group size must be positive.',
    );
  }
  final segments = <SegmentGasUse>[];
  final gases = <(GasUseKind, double, double), _UsageAccumulator>{};
  final groups = <int, List<Segment>>{};
  var bottom = 0.0, ascent = 0.0, deco = 0.0;
  var ccr = false;
  final grid = settings.stopGrid;
  for (var i = 0; i < result.segments.length; i++) {
    final segment = result.segments[i], physical = segment.physical;
    final entered =
        segment.phase == SegmentPhase.levelTravel ||
        segment.phase == SegmentPhase.levelHold;
    final duration = physical.durationMin;
    if (entered) {
      bottom += duration;
    } else {
      ascent += duration;
    }
    if (segment.phase == SegmentPhase.decompression) {
      deco += duration;
      final position =
          (physical.endDepthMetres - grid.lastStopMetres) / grid.stepMetres;
      final index = position.round();
      if (index < 0 || (position - index).abs() > 1e-8) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'A stop does not lie on the supplied physical grid.',
        );
      }
      final group = index < 2 ? 0 : 1 + (index - 2) ~/ stopsPerGroup;
      groups.putIfAbsent(group, () => []).add(segment);
    }
    final closed = physical.breathing.mode == BreathingMode.ccr;
    ccr = ccr || closed;
    final kind = closed ? GasUseKind.ccrOxygen : GasUseKind.openCircuit;
    final gas = closed ? Gas(oxygen: 1) : physical.breathing.gas;
    final rate = closed
        ? (entered
              ? settings.bottomOxygenLitresPerMin
              : settings.decoOxygenLitresPerMin)
        : (entered
              ? settings.bottomRmvLitresPerMin
              : settings.decoRmvLitresPerMin);
    final mean = (physical.startDepthMetres + physical.endDepthMetres) / 2;
    final litres =
        rate *
        duration *
        (closed ? 1 : result.pressure.ambientBar(mean) / Units.barPerAta);
    requireFinite(litres, 'segment usage', nonnegative: true);
    segments.add(
      SegmentGasUse(segmentIndex: i, kind: kind, gas: gas, litres: litres),
    );
    final total = gases.putIfAbsent((
      kind,
      gas.oxygen,
      gas.helium,
    ), () => _UsageAccumulator(kind, gas));
    total.litres += litres;
    total.duration += duration;
    requireFinite(total.litres, 'gas total', nonnegative: true);
    if (segment.phase == SegmentPhase.decompression) {
      total.stops.add(physical.endDepthMetres);
      total.decompression += duration;
    }
  }
  return GasUsageReport(
    segments: segments,
    bottomMin: bottom,
    ascentMin: ascent,
    decompressionMin: deco,
    hasCcr: ccr,
    gases: [
      for (final g in gases.values)
        GasUseTotal(
          kind: g.kind,
          gas: g.gas,
          litres: g.litres,
          durationMin: g.duration,
          decompressionMin: g.decompression,
          stopCount: g.stops.length,
          ratio: TimeRatio(bottomMin: bottom, comparedMin: g.duration),
        ),
    ],
    stopGroups: [
      for (final entry
          in (groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key))))
        _stopGroup(entry.value, bottom),
    ],
  );
}

StopGroup _stopGroup(List<Segment> segments, double bottom) {
  final depths = segments.map((s) => s.physical.endDepthMetres).toSet().toList()
    ..sort();
  final duration = segments.fold(0.0, (sum, s) => sum + s.physical.durationMin);
  return StopGroup(
    shallowestMetres: depths.first,
    deepestMetres: depths.last,
    durationMin: duration,
    stopCount: depths.length,
    ratio: TimeRatio(bottomMin: bottom, comparedMin: duration),
  );
}

/// Legacy-compatible linear water-volume estimate, separate from fill EOS and
/// nominal cylinder conversion. Does not include reserves or subtract a start pressure.
final class TankRequirement {
  TankRequirement({
    required this.freeLitres,
    required this.waterLitres,
    required this.cylinderCount,
    required this.workingBar,
  }) {
    for (final entry in {
      'freeLitres': freeLitres,
      'waterLitres': waterLitres,
      'workingBar': workingBar,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    if (waterLitres == 0 || workingBar == 0 || cylinderCount <= 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Tank size, count and working pressure must be positive.',
      );
    }
    requireFinite(
      waterLitres * cylinderCount,
      'total tank volume',
      nonnegative: true,
    );
    requireFinite(requiredBar, 'requiredBar', nonnegative: true);
  }
  final double freeLitres, waterLitres, workingBar;
  final int cylinderCount;
  double get requiredBar => freeLitres / (waterLitres * cylinderCount);
  bool get exceedsWorkingPressure => requiredBar > workingBar;
}
