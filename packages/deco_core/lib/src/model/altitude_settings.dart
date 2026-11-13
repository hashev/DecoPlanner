import '../numerics/failure.dart';
import '../units/units.dart';
import 'json.dart';

final class AltitudeSettings {
  AltitudeSettings({
    this.enabled = false,
    this.seaLevelBar = Units.barPerAta,
    this.diveAltitudeMetres = 0,
    this.acclimatized = true,
    this.initialAltitudeMetres = 0,
    this.travelMin = 180,
    this.waitMin = 120,
  }) {
    for (final entry in {
      'seaLevelBar': seaLevelBar,
      'diveAltitudeMetres': diveAltitudeMetres,
      'initialAltitudeMetres': initialAltitudeMetres,
      'travelMin': travelMin,
      'waitMin': waitMin,
    }.entries) {
      requireFinite(entry.value, entry.key, nonnegative: true);
    }
    if (seaLevelBar == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Sea-level pressure must be positive.',
      );
    }
    if (enabled &&
        !acclimatized &&
        (initialAltitudeMetres >= diveAltitudeMetres || travelMin == 0)) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Altitude travel requires positive travel time and a higher destination.',
      );
    }
  }
  final bool enabled, acclimatized;
  final double diveAltitudeMetres,
      initialAltitudeMetres,
      travelMin,
      waitMin,
      seaLevelBar;
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'seaLevelBar': seaLevelBar,
    'acclimatized': acclimatized,
    'diveAltitudeMetres': diveAltitudeMetres,
    'initialAltitudeMetres': initialAltitudeMetres,
    'travelMin': travelMin,
    'waitMin': waitMin,
  };
  factory AltitudeSettings.fromJson(Map<String, Object?> json) =>
      AltitudeSettings(
        enabled: boolValue(json['enabled'], 'enabled'),
        seaLevelBar: doubleValue(json['seaLevelBar'], 'seaLevelBar'),
        acclimatized: boolValue(json['acclimatized'], 'acclimatized'),
        diveAltitudeMetres: doubleValue(
          json['diveAltitudeMetres'],
          'diveAltitudeMetres',
        ),
        initialAltitudeMetres: doubleValue(
          json['initialAltitudeMetres'],
          'initialAltitudeMetres',
        ),
        travelMin: doubleValue(json['travelMin'], 'travelMin'),
        waitMin: doubleValue(json['waitMin'], 'waitMin'),
      );
}
