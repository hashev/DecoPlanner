import '../numerics/failure.dart';
import '../tissues/segments.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';
import 'calculation_state.dart';
import 'gas.dart';
import 'json.dart';

enum SegmentPhase { levelTravel, levelHold, ascent, decompression }

final class Segment {
  Segment({
    required this.physical,
    required this.phase,
    required this.startMin,
    required this.endState,
  }) {
    requireFinite(startMin, 'segment startMin', nonnegative: true);
    requireFinite(endMin, 'segment endMin', nonnegative: true);
  }
  final PropagationSegment physical;
  final SegmentPhase phase;
  final double startMin;
  double get endMin => startMin + physical.durationMin;
  final CalculationState endState;
  Map<String, Object?> toJson() => {
    'startDepthMetres': physical.startDepthMetres,
    'endDepthMetres': physical.endDepthMetres,
    'durationMin': physical.durationMin,
    'breathing': physical.breathing.toJson(),
    'phase': phase.name,
    'startMin': startMin,
    'endState': endState.toJson(),
  };
  factory Segment.fromJson(Map<String, Object?> json) => Segment(
    physical: PropagationSegment(
      startDepthMetres: doubleValue(
        json['startDepthMetres'],
        'startDepthMetres',
      ),
      endDepthMetres: doubleValue(json['endDepthMetres'], 'endDepthMetres'),
      durationMin: doubleValue(json['durationMin'], 'durationMin'),
      breathing: BreathingGas.fromJson(
        objectValue(json['breathing'], 'breathing'),
      ),
    ),
    phase: enumValue(json['phase'], SegmentPhase.values, 'phase'),
    startMin: doubleValue(json['startMin'], 'startMin'),
    endState: CalculationState.fromJson(
      objectValue(json['endState'], 'endState'),
    ),
  );
}

final class Stop {
  Stop({
    required this.depthMetres,
    required this.startMin,
    required this.durationMin,
    required this.breathing,
    required this.endState,
  }) {
    requireFinite(depthMetres, 'stop depth', nonnegative: true);
    requireFinite(startMin, 'stop startMin', nonnegative: true);
    requireFinite(durationMin, 'stop durationMin', nonnegative: true);
    requireFinite(endMin, 'stop endMin', nonnegative: true);
  }
  final double depthMetres, startMin, durationMin;
  double get endMin => startMin + durationMin;
  final BreathingGas breathing;
  final CalculationState endState;
}

final class CalculationResult {
  CalculationResult({
    required this.diveId,
    required this.modelVersion,
    required this.initialState,
    required this.pressure,
    required Iterable<Segment> segments,
    required this.firstStopMetres,
    required this.ascentMin,
    required this.decompressionMin,
  }) : segments = List.unmodifiable(segments) {
    if (diveId.isEmpty || modelVersion.isEmpty) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Result identity is required.',
      );
    }
    for (final entry in {
      'firstStopMetres': firstStopMetres,
      'ascentMin': ascentMin,
      'decompressionMin': decompressionMin,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    var time = 0.0, depth = 0.0;
    for (final segment in this.segments) {
      if (segment.startMin != time ||
          segment.physical.startDepthMetres != depth) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Result segments must be continuous in time and depth.',
        );
      }
      time = segment.endMin;
      depth = segment.physical.endDepthMetres;
    }
    if (decompressionMin > ascentMin || ascentMin > time) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Result duration metrics are inconsistent.',
      );
    }
  }
  final String diveId, modelVersion;
  final CalculationState initialState;
  final PressureContext pressure;
  final List<Segment> segments;
  final double firstStopMetres, ascentMin, decompressionMin;
  CalculationState get finalState =>
      segments.isEmpty ? initialState : segments.last.endState;
  TissueState get finalTissues => finalState.tissues;
  double get runtimeMin => segments.isEmpty ? 0 : segments.last.endMin;
  int get runtimeDisplayMin => runtimeMin.ceil();
  List<Stop> get stops => List.unmodifiable(
    segments
        .where((s) => s.phase == SegmentPhase.decompression)
        .map(
          (s) => Stop(
            depthMetres: s.physical.endDepthMetres,
            startMin: s.startMin,
            durationMin: s.physical.durationMin,
            breathing: s.physical.breathing,
            endState: s.endState,
          ),
        ),
  );
  Map<String, Object?> toJson() => {
    'diveId': diveId,
    'modelVersion': modelVersion,
    'initialState': initialState.toJson(),
    'pressure': {
      'surfaceBar': pressure.surfaceBar,
      'waterVapourBar': pressure.waterVapourBar,
      'barPerMetre': pressure.barPerMetre,
    },
    'segments': segments.map((s) => s.toJson()).toList(),
    'firstStopMetres': firstStopMetres,
    'ascentMin': ascentMin,
    'decompressionMin': decompressionMin,
  };
  factory CalculationResult.fromJson(
    Map<String, Object?> json,
  ) => CalculationResult(
    diveId: stringValue(json['diveId'], 'diveId'),
    modelVersion: stringValue(json['modelVersion'], 'modelVersion'),
    pressure: _readPressure(json['pressure']),
    initialState: CalculationState.fromJson(
      objectValue(json['initialState'], 'initialState'),
    ),
    segments: listValue(
      json['segments'],
      'segments',
    ).map((s) => Segment.fromJson(objectValue(s, 'segment'))),
    firstStopMetres: doubleValue(json['firstStopMetres'], 'firstStopMetres'),
    ascentMin: doubleValue(json['ascentMin'], 'ascentMin'),
    decompressionMin: doubleValue(json['decompressionMin'], 'decompressionMin'),
  );
}

PressureContext _readPressure(Object? value) {
  final json = objectValue(value, 'pressure');
  return PressureContext(
    surfaceBar: doubleValue(json['surfaceBar'], 'surfaceBar'),
    waterVapourBar: doubleValue(json['waterVapourBar'], 'waterVapourBar'),
    barPerMetre: doubleValue(json['barPerMetre'], 'barPerMetre'),
  );
}
