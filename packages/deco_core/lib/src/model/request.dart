import '../buhlmann/ceiling.dart';
import '../numerics/failure.dart';
import '../units/units.dart';
import 'gas.dart';
import 'json.dart';
import 'vpm_parameters.dart';
import 'calculation_state.dart';
import 'altitude_settings.dart';

enum DecompressionModel { buhlmannB, buhlmannC, vpmB }

final class CalculationSettings {
  CalculationSettings({
    required this.model,
    VpmParameters? vpm,
    AltitudeSettings? altitude,
    required this.pressure,
    required this.stopGrid,
    required this.gradientFactors,
    this.descentMetresPerMin = 10,
    this.ascentMetresPerMin = 9,
    this.minimumStopMin = 1,
    this.includeDescentInLevelTime = true,
    this.lowSetpointBar = .7,
    this.vpmConservatism = 2,
    this.bottomRmvLitresPerMin = 20,
    this.decoRmvLitresPerMin = 15,
    this.bottomOxygenLitresPerMin = .7,
    this.decoOxygenLitresPerMin = .5,
  }) : vpm = vpm ?? VpmParameters(),
       altitude = altitude ?? AltitudeSettings() {
    for (final entry in {
      'descentMetresPerMin': descentMetresPerMin,
      'ascentMetresPerMin': ascentMetresPerMin,
      'minimumStopMin': minimumStopMin,
      'lowSetpointBar': lowSetpointBar,
      'bottomRmvLitresPerMin': bottomRmvLitresPerMin,
      'decoRmvLitresPerMin': decoRmvLitresPerMin,
      'bottomOxygenLitresPerMin': bottomOxygenLitresPerMin,
      'decoOxygenLitresPerMin': decoOxygenLitresPerMin,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    if (descentMetresPerMin == 0 ||
        ascentMetresPerMin == 0 ||
        minimumStopMin == 0 ||
        lowSetpointBar == 0 ||
        vpmConservatism < 0 ||
        vpmConservatism > 4) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Travel rates, stop duration and low setpoint must be positive; VPM index0–4.',
      );
    }
  }
  final DecompressionModel model;
  final VpmParameters vpm;
  final AltitudeSettings altitude;
  final PressureContext pressure;
  final StopGrid stopGrid;
  final GradientFactors gradientFactors;
  final double descentMetresPerMin, ascentMetresPerMin, minimumStopMin;
  final bool includeDescentInLevelTime;
  final double lowSetpointBar;
  final int vpmConservatism;
  final double bottomRmvLitresPerMin, decoRmvLitresPerMin;
  final double bottomOxygenLitresPerMin, decoOxygenLitresPerMin;
  Map<String, Object?> toJson() => {
    'model': model.name,
    'vpm': vpm.toJson(),
    'altitude': altitude.toJson(),
    'surfaceBar': pressure.surfaceBar,
    'waterVapourBar': pressure.waterVapourBar,
    'barPerMetre': pressure.barPerMetre,
    'stepMetres': stopGrid.stepMetres,
    'lastStopMetres': stopGrid.lastStopMetres,
    'gfLow': gradientFactors.low,
    'gfHigh': gradientFactors.high,
    'descentMetresPerMin': descentMetresPerMin,
    'ascentMetresPerMin': ascentMetresPerMin,
    'minimumStopMin': minimumStopMin,
    'includeDescentInLevelTime': includeDescentInLevelTime,
    'lowSetpointBar': lowSetpointBar,
    'vpmConservatism': vpmConservatism,
    'bottomRmvLitresPerMin': bottomRmvLitresPerMin,
    'decoRmvLitresPerMin': decoRmvLitresPerMin,
    'bottomOxygenLitresPerMin': bottomOxygenLitresPerMin,
    'decoOxygenLitresPerMin': decoOxygenLitresPerMin,
  };
  factory CalculationSettings.fromJson(Map<String, Object?> json) {
    double number(String key) => doubleValue(json[key], key);
    return CalculationSettings(
      vpm: VpmParameters.fromJson(objectValue(json['vpm'], 'vpm')),
      altitude: AltitudeSettings.fromJson(
        objectValue(json['altitude'], 'altitude'),
      ),
      model: enumValue(json['model'], DecompressionModel.values, 'model'),
      pressure: PressureContext(
        surfaceBar: number('surfaceBar'),
        waterVapourBar: number('waterVapourBar'),
        barPerMetre: number('barPerMetre'),
      ),
      stopGrid: StopGrid(
        stepMetres: number('stepMetres'),
        lastStopMetres: number('lastStopMetres'),
      ),
      gradientFactors: GradientFactors(
        low: number('gfLow'),
        high: number('gfHigh'),
      ),
      descentMetresPerMin: number('descentMetresPerMin'),
      ascentMetresPerMin: number('ascentMetresPerMin'),
      minimumStopMin: number('minimumStopMin'),
      includeDescentInLevelTime: boolValue(
        json['includeDescentInLevelTime'],
        'includeDescentInLevelTime',
      ),
      lowSetpointBar: number('lowSetpointBar'),
      vpmConservatism: intValue(json['vpmConservatism'], 'vpmConservatism'),
      bottomRmvLitresPerMin: number('bottomRmvLitresPerMin'),
      decoRmvLitresPerMin: number('decoRmvLitresPerMin'),
      bottomOxygenLitresPerMin: number('bottomOxygenLitresPerMin'),
      decoOxygenLitresPerMin: number('decoOxygenLitresPerMin'),
    );
  }
}

final class Level {
  Level({
    required this.depthMetres,
    required this.durationMin,
    required this.breathing,
  }) {
    requireFinite(depthMetres, 'depthMetres', nonnegative: true);
    requireFinite(durationMin, 'durationMin', nonnegative: true);
  }
  final double depthMetres, durationMin;
  final BreathingGas breathing;
  Map<String, Object?> toJson() => {
    'depthMetres': depthMetres,
    'durationMin': durationMin,
    'breathing': breathing.toJson(),
  };
  factory Level.fromJson(Map<String, Object?> json) => Level(
    depthMetres: doubleValue(json['depthMetres'], 'depthMetres'),
    durationMin: doubleValue(json['durationMin'], 'durationMin'),
    breathing: BreathingGas.fromJson(
      objectValue(json['breathing'], 'breathing'),
    ),
  );
}

final class GasSwitch {
  GasSwitch({
    required this.depthMetres,
    required this.breathing,
    this.lost = false,
    this.minimumStopMin,
  }) {
    requireFinite(depthMetres, 'switch depth', nonnegative: true);
    final min = minimumStopMin;
    if (min != null) {
      requireFinite(min, 'gas minimumStopMin', nonnegative: true);
      if (min == 0) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Gas stop minimum must be positive.',
        );
      }
    }
  }
  final double depthMetres;
  final BreathingGas breathing;
  final bool lost;
  final double? minimumStopMin;
  Map<String, Object?> toJson() => {
    'depthMetres': depthMetres,
    'breathing': breathing.toJson(),
    'lost': lost,
    'minimumStopMin': minimumStopMin,
  };
  factory GasSwitch.fromJson(Map<String, Object?> json) => GasSwitch(
    depthMetres: doubleValue(json['depthMetres'], 'depthMetres'),
    breathing: BreathingGas.fromJson(
      objectValue(json['breathing'], 'breathing'),
    ),
    lost: boolValue(json['lost'], 'lost'),
    minimumStopMin: json['minimumStopMin'] == null
        ? null
        : doubleValue(json['minimumStopMin'], 'minimumStopMin'),
  );
}

final class DiveRequest {
  DiveRequest({
    required this.id,
    required Iterable<Level> levels,
    required this.settings,
    Iterable<GasSwitch> switches = const [],
    this.surfaceIntervalMin = 0,
    this.initialState,
  }) : levels = List.unmodifiable(levels),
       switches = List.unmodifiable(switches) {
    if (id.isEmpty || this.levels.isEmpty) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Dive needs an id and at least one level.',
      );
    }
    requireFinite(surfaceIntervalMin, 'surfaceIntervalMin', nonnegative: true);
  }
  final String id;
  final List<Level> levels;
  final List<GasSwitch> switches;
  final CalculationSettings settings;
  final double surfaceIntervalMin;
  final CalculationState? initialState;
  Map<String, Object?> toJson() => {
    'id': id,
    'levels': levels.map((l) => l.toJson()).toList(),
    'switches': switches.map((s) => s.toJson()).toList(),
    'settings': settings.toJson(),
    'surfaceIntervalMin': surfaceIntervalMin,
    'initialState': initialState?.toJson(),
  };
  factory DiveRequest.fromJson(Map<String, Object?> json) => DiveRequest(
    id: stringValue(json['id'], 'id'),
    levels: listValue(
      json['levels'],
      'levels',
    ).map((v) => Level.fromJson(objectValue(v, 'level'))),
    switches: listValue(
      json['switches'],
      'switches',
    ).map((v) => GasSwitch.fromJson(objectValue(v, 'switch'))),
    settings: CalculationSettings.fromJson(
      objectValue(json['settings'], 'settings'),
    ),
    surfaceIntervalMin: doubleValue(
      json['surfaceIntervalMin'],
      'surfaceIntervalMin',
    ),
    initialState: json['initialState'] == null
        ? null
        : CalculationState.fromJson(
            objectValue(json['initialState'], 'initialState'),
          ),
  );
}
