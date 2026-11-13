import 'package:deco_core/deco_core.dart';

/// Metric single-dive research adapter. Altitude/repetitive inputs must use
/// their own state normalizer, never silently fall back to surface defaults.
DiveRequest legacyOcRequest(Map<String, dynamic> source) {
  final options = (source['settings'] as Map<String, dynamic>?) ?? {};
  if (options['altitude_enabled'] == true || source['dives'] != null) {
    throw ArgumentError(
      'Altitude/repetitive state requires explicit normalization.',
    );
  }
  final rows = (source['levels'] as List).cast<List>();
  final switches = (source['deco'] as List?) ?? [];
  BreathingGas gas(num oxygen, num helium) =>
      BreathingGas.oc(Gas(oxygen: oxygen / 100, helium: helium / 100));
  return DiveRequest(
    id: source['id'] as String,
    levels: rows.map(
      (row) => Level(
        depthMetres: (row[0] as num).toDouble(),
        durationMin: (row[1] as num).toDouble(),
        breathing: gas(row[2] as num, row[3] as num),
      ),
    ),
    switches: switches.cast<List>().map(
      (row) => GasSwitch(
        depthMetres: (row[0] as num).toDouble(),
        breathing: gas(row[1] as num, row[2] as num),
        minimumStopMin: row.length > 4 ? (row[4] as num).toDouble() : null,
      ),
    ),
    settings: CalculationSettings(
      model: source['model'] == 'vpm'
          ? DecompressionModel.vpmB
          : source['model'] == 'c'
          ? DecompressionModel.buhlmannC
          : DecompressionModel.buhlmannB,
      vpmConservatism: (source['conservatism'] as int?) ?? 2,
      vpm: VpmParameters(
        criticalVolumeEnabled: options['critical_volume'] != false,
      ),
      pressure: PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: source['model'] == 'vpm' ? .0493 : .0627,
        barPerMetre: .1,
      ),
      stopGrid: StopGrid(
        stepMetres: 3,
        lastStopMetres: options['last_stop_double'] == true ? 6 : 3,
      ),
      gradientFactors: GradientFactors(
        low: (options['gf_low'] as num?)?.toDouble() ?? .3,
        high: (options['gf_high'] as num?)?.toDouble() ?? .85,
      ),
    ),
  );
}
