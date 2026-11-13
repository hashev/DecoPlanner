import '../model/json.dart';
import 'vpm_parameters.dart';
import '../numerics/failure.dart';
import '../tissues/tissues.dart';
import '../units/units.dart';

/// Complete explicit VPM working state. All sixteen-component arrays are
/// defensively copied; transient iteration snapshots can be serialized too.
final class VpmState {
  VpmState({
    required this.modelVersion,
    required Iterable<double> initialRadiusNitrogenMetres,
    required Iterable<double> initialRadiusHeliumMetres,
    required Iterable<double> adjustedInitialRadiusNitrogenMetres,
    required Iterable<double> adjustedInitialRadiusHeliumMetres,
    required Iterable<double> maxCrushingPressureNitrogenBar,
    required Iterable<double> maxCrushingPressureHeliumBar,
    required Iterable<double> regeneratedRadiusNitrogenMetres,
    required Iterable<double> regeneratedRadiusHeliumMetres,
    required Iterable<double> adjustedCrushingPressureNitrogenBar,
    required Iterable<double> adjustedCrushingPressureHeliumBar,
    required Iterable<double> initialAllowableGradientNitrogenBar,
    required Iterable<double> initialAllowableGradientHeliumBar,
    required Iterable<double> allowableGradientNitrogenBar,
    required Iterable<double> allowableGradientHeliumBar,
    required Iterable<double> boyleGradientNitrogenBar,
    required Iterable<double> boyleGradientHeliumBar,
    required Iterable<double> maxActualGradientBar,
    required Iterable<double> surfacePhaseVolumeMin,
    required Iterable<double> totalPhaseVolumeMin,
    required Iterable<double> previousPhaseVolumeMin,
    required Iterable<double> ambientOnsetBar,
    required Iterable<double> tensionOnsetBar,
    required this.decoStartTissues,
    required this.ascentStartTissues,
    required this.segmentStartTissues,
    required this.surfaceBar,
    required this.vapourBar,
    required this.otherGasesBar,
    required this.maximumFirstStopMetres,
    required this.decoZoneStartMin,
    required this.savedRuntimeMin,
    required this.savedSegmentCount,
    required this.criticalVolumeIterations,
    required this.decoPhaseVolumeMin,
  }) : initialRadiusNitrogenMetres = checkedCompartments(
         initialRadiusNitrogenMetres,
         'initialRadiusNitrogenMetres',
         positive: true,
       ),
       initialRadiusHeliumMetres = checkedCompartments(
         initialRadiusHeliumMetres,
         'initialRadiusHeliumMetres',
         positive: true,
       ),
       adjustedInitialRadiusNitrogenMetres = checkedCompartments(
         adjustedInitialRadiusNitrogenMetres,
         'adjustedInitialRadiusNitrogenMetres',
         positive: true,
       ),
       adjustedInitialRadiusHeliumMetres = checkedCompartments(
         adjustedInitialRadiusHeliumMetres,
         'adjustedInitialRadiusHeliumMetres',
         positive: true,
       ),
       maxCrushingPressureNitrogenBar = checkedCompartments(
         maxCrushingPressureNitrogenBar,
         'maxCrushingPressureNitrogenBar',
       ),
       maxCrushingPressureHeliumBar = checkedCompartments(
         maxCrushingPressureHeliumBar,
         'maxCrushingPressureHeliumBar',
       ),
       regeneratedRadiusNitrogenMetres = checkedCompartments(
         regeneratedRadiusNitrogenMetres,
         'regeneratedRadiusNitrogenMetres',
         positive: true,
       ),
       regeneratedRadiusHeliumMetres = checkedCompartments(
         regeneratedRadiusHeliumMetres,
         'regeneratedRadiusHeliumMetres',
         positive: true,
       ),
       adjustedCrushingPressureNitrogenBar = checkedCompartments(
         adjustedCrushingPressureNitrogenBar,
         'adjustedCrushingPressureNitrogenBar',
       ),
       adjustedCrushingPressureHeliumBar = checkedCompartments(
         adjustedCrushingPressureHeliumBar,
         'adjustedCrushingPressureHeliumBar',
       ),
       initialAllowableGradientNitrogenBar = checkedCompartments(
         initialAllowableGradientNitrogenBar,
         'initialAllowableGradientNitrogenBar',
       ),
       initialAllowableGradientHeliumBar = checkedCompartments(
         initialAllowableGradientHeliumBar,
         'initialAllowableGradientHeliumBar',
       ),
       allowableGradientNitrogenBar = checkedCompartments(
         allowableGradientNitrogenBar,
         'allowableGradientNitrogenBar',
       ),
       allowableGradientHeliumBar = checkedCompartments(
         allowableGradientHeliumBar,
         'allowableGradientHeliumBar',
       ),
       boyleGradientNitrogenBar = checkedCompartments(
         boyleGradientNitrogenBar,
         'boyleGradientNitrogenBar',
       ),
       boyleGradientHeliumBar = checkedCompartments(
         boyleGradientHeliumBar,
         'boyleGradientHeliumBar',
       ),
       maxActualGradientBar = checkedCompartments(
         maxActualGradientBar,
         'maxActualGradientBar',
       ),
       surfacePhaseVolumeMin = checkedCompartments(
         surfacePhaseVolumeMin,
         'surfacePhaseVolumeMin',
       ),
       totalPhaseVolumeMin = checkedCompartments(
         totalPhaseVolumeMin,
         'totalPhaseVolumeMin',
       ),
       previousPhaseVolumeMin = checkedCompartments(
         previousPhaseVolumeMin,
         'previousPhaseVolumeMin',
       ),
       ambientOnsetBar = checkedCompartments(
         ambientOnsetBar,
         'ambientOnsetBar',
       ),
       tensionOnsetBar = checkedCompartments(
         tensionOnsetBar,
         'tensionOnsetBar',
       ) {
    if (modelVersion.isEmpty ||
        savedSegmentCount < 0 ||
        criticalVolumeIterations < 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Invalid VPM state metadata.',
      );
    }
    for (final entry in {
      'surfaceBar': surfaceBar,
      'vapourBar': vapourBar,
      'otherGasesBar': otherGasesBar,
      'maximumFirstStopMetres': maximumFirstStopMetres,
      'decoZoneStartMin': decoZoneStartMin,
      'savedRuntimeMin': savedRuntimeMin,
      'decoPhaseVolumeMin': decoPhaseVolumeMin,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    if (surfaceBar <= vapourBar) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Invalid VPM surface/vapour context.',
      );
    }
  }
  final String modelVersion;
  final List<double> initialRadiusNitrogenMetres;
  final List<double> initialRadiusHeliumMetres;
  final List<double> adjustedInitialRadiusNitrogenMetres;
  final List<double> adjustedInitialRadiusHeliumMetres;
  final List<double> maxCrushingPressureNitrogenBar;
  final List<double> maxCrushingPressureHeliumBar;
  final List<double> regeneratedRadiusNitrogenMetres;
  final List<double> regeneratedRadiusHeliumMetres;
  final List<double> adjustedCrushingPressureNitrogenBar;
  final List<double> adjustedCrushingPressureHeliumBar;
  final List<double> initialAllowableGradientNitrogenBar;
  final List<double> initialAllowableGradientHeliumBar;
  final List<double> allowableGradientNitrogenBar;
  final List<double> allowableGradientHeliumBar;
  final List<double> boyleGradientNitrogenBar;
  final List<double> boyleGradientHeliumBar;
  final List<double> maxActualGradientBar;
  final List<double> surfacePhaseVolumeMin;
  final List<double> totalPhaseVolumeMin;
  final List<double> previousPhaseVolumeMin;
  final List<double> ambientOnsetBar;
  final List<double> tensionOnsetBar;
  final TissueState decoStartTissues, ascentStartTissues, segmentStartTissues;
  final double surfaceBar, vapourBar, otherGasesBar, maximumFirstStopMetres;
  final double decoZoneStartMin, savedRuntimeMin, decoPhaseVolumeMin;
  final int savedSegmentCount, criticalVolumeIterations;
  factory VpmState.initial({
    required VpmParameters parameters,
    required int conservatism,
    required TissueState tissues,
    required PressureContext pressure,
  }) {
    final scale = parameters.radiusScale(conservatism);
    final nitrogen = List.filled(16, parameters.nitrogenRadiusMetres * scale);
    final helium = List.filled(16, parameters.heliumRadiusMetres * scale);
    final zero = List<double>.filled(16, 0);
    return VpmState(
      modelVersion: parameters.version,
      initialRadiusNitrogenMetres: nitrogen,
      initialRadiusHeliumMetres: helium,
      adjustedInitialRadiusNitrogenMetres: nitrogen,
      adjustedInitialRadiusHeliumMetres: helium,
      maxCrushingPressureNitrogenBar: zero,
      maxCrushingPressureHeliumBar: zero,
      regeneratedRadiusNitrogenMetres: nitrogen,
      regeneratedRadiusHeliumMetres: helium,
      adjustedCrushingPressureNitrogenBar: zero,
      adjustedCrushingPressureHeliumBar: zero,
      initialAllowableGradientNitrogenBar: zero,
      initialAllowableGradientHeliumBar: zero,
      allowableGradientNitrogenBar: zero,
      allowableGradientHeliumBar: zero,
      boyleGradientNitrogenBar: zero,
      boyleGradientHeliumBar: zero,
      maxActualGradientBar: zero,
      surfacePhaseVolumeMin: zero,
      totalPhaseVolumeMin: zero,
      previousPhaseVolumeMin: zero,
      ambientOnsetBar: zero,
      tensionOnsetBar: zero,
      decoStartTissues: tissues,
      ascentStartTissues: tissues,
      segmentStartTissues: tissues,
      surfaceBar: pressure.surfaceBar,
      vapourBar: pressure.waterVapourBar,
      otherGasesBar: parameters.otherGasesBar,
      maximumFirstStopMetres: 0,
      decoZoneStartMin: 0,
      savedRuntimeMin: 0,
      savedSegmentCount: 0,
      criticalVolumeIterations: 0,
      decoPhaseVolumeMin: 0,
    );
  }
  VpmState copyWith({
    Iterable<double>? initialRadiusNitrogenMetres,
    Iterable<double>? initialRadiusHeliumMetres,
    Iterable<double>? adjustedInitialRadiusNitrogenMetres,
    Iterable<double>? adjustedInitialRadiusHeliumMetres,
    Iterable<double>? maxCrushingPressureNitrogenBar,
    Iterable<double>? maxCrushingPressureHeliumBar,
    Iterable<double>? regeneratedRadiusNitrogenMetres,
    Iterable<double>? regeneratedRadiusHeliumMetres,
    Iterable<double>? adjustedCrushingPressureNitrogenBar,
    Iterable<double>? adjustedCrushingPressureHeliumBar,
    Iterable<double>? initialAllowableGradientNitrogenBar,
    Iterable<double>? initialAllowableGradientHeliumBar,
    Iterable<double>? allowableGradientNitrogenBar,
    Iterable<double>? allowableGradientHeliumBar,
    Iterable<double>? boyleGradientNitrogenBar,
    Iterable<double>? boyleGradientHeliumBar,
    Iterable<double>? maxActualGradientBar,
    Iterable<double>? surfacePhaseVolumeMin,
    Iterable<double>? totalPhaseVolumeMin,
    Iterable<double>? previousPhaseVolumeMin,
    Iterable<double>? ambientOnsetBar,
    Iterable<double>? tensionOnsetBar,
    String? modelVersion,
    TissueState? decoStartTissues,
    TissueState? ascentStartTissues,
    TissueState? segmentStartTissues,
    double? surfaceBar,
    double? vapourBar,
    double? otherGasesBar,
    double? maximumFirstStopMetres,
    double? decoZoneStartMin,
    double? savedRuntimeMin,
    double? decoPhaseVolumeMin,
    int? savedSegmentCount,
    int? criticalVolumeIterations,
  }) => VpmState(
    initialRadiusNitrogenMetres:
        initialRadiusNitrogenMetres ?? this.initialRadiusNitrogenMetres,
    initialRadiusHeliumMetres:
        initialRadiusHeliumMetres ?? this.initialRadiusHeliumMetres,
    adjustedInitialRadiusNitrogenMetres:
        adjustedInitialRadiusNitrogenMetres ??
        this.adjustedInitialRadiusNitrogenMetres,
    adjustedInitialRadiusHeliumMetres:
        adjustedInitialRadiusHeliumMetres ??
        this.adjustedInitialRadiusHeliumMetres,
    maxCrushingPressureNitrogenBar:
        maxCrushingPressureNitrogenBar ?? this.maxCrushingPressureNitrogenBar,
    maxCrushingPressureHeliumBar:
        maxCrushingPressureHeliumBar ?? this.maxCrushingPressureHeliumBar,
    regeneratedRadiusNitrogenMetres:
        regeneratedRadiusNitrogenMetres ?? this.regeneratedRadiusNitrogenMetres,
    regeneratedRadiusHeliumMetres:
        regeneratedRadiusHeliumMetres ?? this.regeneratedRadiusHeliumMetres,
    adjustedCrushingPressureNitrogenBar:
        adjustedCrushingPressureNitrogenBar ??
        this.adjustedCrushingPressureNitrogenBar,
    adjustedCrushingPressureHeliumBar:
        adjustedCrushingPressureHeliumBar ??
        this.adjustedCrushingPressureHeliumBar,
    initialAllowableGradientNitrogenBar:
        initialAllowableGradientNitrogenBar ??
        this.initialAllowableGradientNitrogenBar,
    initialAllowableGradientHeliumBar:
        initialAllowableGradientHeliumBar ??
        this.initialAllowableGradientHeliumBar,
    allowableGradientNitrogenBar:
        allowableGradientNitrogenBar ?? this.allowableGradientNitrogenBar,
    allowableGradientHeliumBar:
        allowableGradientHeliumBar ?? this.allowableGradientHeliumBar,
    boyleGradientNitrogenBar:
        boyleGradientNitrogenBar ?? this.boyleGradientNitrogenBar,
    boyleGradientHeliumBar:
        boyleGradientHeliumBar ?? this.boyleGradientHeliumBar,
    maxActualGradientBar: maxActualGradientBar ?? this.maxActualGradientBar,
    surfacePhaseVolumeMin: surfacePhaseVolumeMin ?? this.surfacePhaseVolumeMin,
    totalPhaseVolumeMin: totalPhaseVolumeMin ?? this.totalPhaseVolumeMin,
    previousPhaseVolumeMin:
        previousPhaseVolumeMin ?? this.previousPhaseVolumeMin,
    ambientOnsetBar: ambientOnsetBar ?? this.ambientOnsetBar,
    tensionOnsetBar: tensionOnsetBar ?? this.tensionOnsetBar,
    modelVersion: modelVersion ?? this.modelVersion,
    decoStartTissues: decoStartTissues ?? this.decoStartTissues,
    ascentStartTissues: ascentStartTissues ?? this.ascentStartTissues,
    segmentStartTissues: segmentStartTissues ?? this.segmentStartTissues,
    surfaceBar: surfaceBar ?? this.surfaceBar,
    vapourBar: vapourBar ?? this.vapourBar,
    otherGasesBar: otherGasesBar ?? this.otherGasesBar,
    maximumFirstStopMetres:
        maximumFirstStopMetres ?? this.maximumFirstStopMetres,
    decoZoneStartMin: decoZoneStartMin ?? this.decoZoneStartMin,
    savedRuntimeMin: savedRuntimeMin ?? this.savedRuntimeMin,
    decoPhaseVolumeMin: decoPhaseVolumeMin ?? this.decoPhaseVolumeMin,
    savedSegmentCount: savedSegmentCount ?? this.savedSegmentCount,
    criticalVolumeIterations:
        criticalVolumeIterations ?? this.criticalVolumeIterations,
  );
  Map<String, Object?> toJson() => {
    'modelVersion': modelVersion,
    'initialRadiusNitrogenMetres': initialRadiusNitrogenMetres,
    'initialRadiusHeliumMetres': initialRadiusHeliumMetres,
    'adjustedInitialRadiusNitrogenMetres': adjustedInitialRadiusNitrogenMetres,
    'adjustedInitialRadiusHeliumMetres': adjustedInitialRadiusHeliumMetres,
    'maxCrushingPressureNitrogenBar': maxCrushingPressureNitrogenBar,
    'maxCrushingPressureHeliumBar': maxCrushingPressureHeliumBar,
    'regeneratedRadiusNitrogenMetres': regeneratedRadiusNitrogenMetres,
    'regeneratedRadiusHeliumMetres': regeneratedRadiusHeliumMetres,
    'adjustedCrushingPressureNitrogenBar': adjustedCrushingPressureNitrogenBar,
    'adjustedCrushingPressureHeliumBar': adjustedCrushingPressureHeliumBar,
    'initialAllowableGradientNitrogenBar': initialAllowableGradientNitrogenBar,
    'initialAllowableGradientHeliumBar': initialAllowableGradientHeliumBar,
    'allowableGradientNitrogenBar': allowableGradientNitrogenBar,
    'allowableGradientHeliumBar': allowableGradientHeliumBar,
    'boyleGradientNitrogenBar': boyleGradientNitrogenBar,
    'boyleGradientHeliumBar': boyleGradientHeliumBar,
    'maxActualGradientBar': maxActualGradientBar,
    'surfacePhaseVolumeMin': surfacePhaseVolumeMin,
    'totalPhaseVolumeMin': totalPhaseVolumeMin,
    'previousPhaseVolumeMin': previousPhaseVolumeMin,
    'ambientOnsetBar': ambientOnsetBar,
    'tensionOnsetBar': tensionOnsetBar,
    'decoStartTissues': decoStartTissues.toJson(),
    'ascentStartTissues': ascentStartTissues.toJson(),
    'segmentStartTissues': segmentStartTissues.toJson(),
    'surfaceBar': surfaceBar,
    'vapourBar': vapourBar,
    'otherGasesBar': otherGasesBar,
    'maximumFirstStopMetres': maximumFirstStopMetres,
    'decoZoneStartMin': decoZoneStartMin,
    'savedRuntimeMin': savedRuntimeMin,
    'decoPhaseVolumeMin': decoPhaseVolumeMin,
    'savedSegmentCount': savedSegmentCount,
    'criticalVolumeIterations': criticalVolumeIterations,
  };
  factory VpmState.fromJson(Map<String, Object?> json) {
    Iterable<double> vector(String key) =>
        listValue(json[key], key).map((v) => doubleValue(v, key));
    double number(String key) => doubleValue(json[key], key);
    return VpmState(
      modelVersion: stringValue(json['modelVersion'], 'modelVersion'),
      initialRadiusNitrogenMetres: vector('initialRadiusNitrogenMetres'),
      initialRadiusHeliumMetres: vector('initialRadiusHeliumMetres'),
      adjustedInitialRadiusNitrogenMetres: vector(
        'adjustedInitialRadiusNitrogenMetres',
      ),
      adjustedInitialRadiusHeliumMetres: vector(
        'adjustedInitialRadiusHeliumMetres',
      ),
      maxCrushingPressureNitrogenBar: vector('maxCrushingPressureNitrogenBar'),
      maxCrushingPressureHeliumBar: vector('maxCrushingPressureHeliumBar'),
      regeneratedRadiusNitrogenMetres: vector(
        'regeneratedRadiusNitrogenMetres',
      ),
      regeneratedRadiusHeliumMetres: vector('regeneratedRadiusHeliumMetres'),
      adjustedCrushingPressureNitrogenBar: vector(
        'adjustedCrushingPressureNitrogenBar',
      ),
      adjustedCrushingPressureHeliumBar: vector(
        'adjustedCrushingPressureHeliumBar',
      ),
      initialAllowableGradientNitrogenBar: vector(
        'initialAllowableGradientNitrogenBar',
      ),
      initialAllowableGradientHeliumBar: vector(
        'initialAllowableGradientHeliumBar',
      ),
      allowableGradientNitrogenBar: vector('allowableGradientNitrogenBar'),
      allowableGradientHeliumBar: vector('allowableGradientHeliumBar'),
      boyleGradientNitrogenBar: vector('boyleGradientNitrogenBar'),
      boyleGradientHeliumBar: vector('boyleGradientHeliumBar'),
      maxActualGradientBar: vector('maxActualGradientBar'),
      surfacePhaseVolumeMin: vector('surfacePhaseVolumeMin'),
      totalPhaseVolumeMin: vector('totalPhaseVolumeMin'),
      previousPhaseVolumeMin: vector('previousPhaseVolumeMin'),
      ambientOnsetBar: vector('ambientOnsetBar'),
      tensionOnsetBar: vector('tensionOnsetBar'),
      ascentStartTissues: TissueState.fromJson(
        objectValue(json['ascentStartTissues'], 'ascentStartTissues'),
      ),
      segmentStartTissues: TissueState.fromJson(
        objectValue(json['segmentStartTissues'], 'segmentStartTissues'),
      ),
      decoStartTissues: TissueState.fromJson(
        objectValue(json['decoStartTissues'], 'decoStartTissues'),
      ),
      surfaceBar: number('surfaceBar'),
      vapourBar: number('vapourBar'),
      otherGasesBar: number('otherGasesBar'),
      maximumFirstStopMetres: number('maximumFirstStopMetres'),
      decoZoneStartMin: number('decoZoneStartMin'),
      savedRuntimeMin: number('savedRuntimeMin'),
      decoPhaseVolumeMin: number('decoPhaseVolumeMin'),
      savedSegmentCount: intValue(
        json['savedSegmentCount'],
        'savedSegmentCount',
      ),
      criticalVolumeIterations: intValue(
        json['criticalVolumeIterations'],
        'criticalVolumeIterations',
      ),
    );
  }
}
