import 'dart:math' as math;
import '../model/gas.dart';
import '../numerics/failure.dart';
import '../units/units.dart';

/// Empirical gas properties at the research reference conditions; density is
/// the specified linear model, not a temperature-dependent fill EOS.
abstract final class GasProperties {
  static double? maximumDepthMetres(
    Gas gas,
    double limitOxygenBar,
    PressureContext pressure,
  ) {
    _positive(limitOxygenBar, 'limitOxygenBar');
    if (gas.oxygen == 0) return null;
    final maximumAmbient = limitOxygenBar / gas.oxygen;
    if (maximumAmbient < pressure.surfaceBar) return null;
    return pressure.depthMetres(maximumAmbient);
  }

  static double? minimumDepthMetres(
    Gas gas,
    double minimumOxygenBar,
    PressureContext pressure,
  ) {
    _positive(minimumOxygenBar, 'minimumOxygenBar');
    if (gas.oxygen == 0) return null;
    return math.max(0, pressure.depthMetres(minimumOxygenBar / gas.oxygen));
  }

  static double equivalentNarcoticDepthMetres(
    Gas gas,
    double depthMetres,
    double oxygenNarcosis,
    PressureContext pressure,
  ) {
    _narcosis(oxygenNarcosis);
    final narcoticFraction = gas.nitrogen + gas.oxygen * oxygenNarcosis;
    final airFraction = .79 + .21 * oxygenNarcosis;
    return pressure.depthMetres(
      pressure.ambientBar(depthMetres) * narcoticFraction / airFraction,
    );
  }

  static double densityGramsPerLitre(
    Gas gas,
    double depthMetres,
    PressureContext pressure,
  ) {
    final surfaceDensity =
        gas.oxygen * 1.43 + gas.helium * .18 + gas.nitrogen * 1.25;
    final result =
        surfaceDensity * Units.barToAta(pressure.ambientBar(depthMetres));
    requireFinite(result, 'gas density', nonnegative: true);
    return result;
  }

  static double equivalentAirDensityDepthMetres(
    Gas gas,
    double depthMetres,
    PressureContext pressure,
  ) => pressure.depthMetres(
    densityGramsPerLitre(gas, depthMetres, pressure) / 1.2878 * Units.barPerAta,
  );

  /// PO2 target is in bar, END bound in metres. A nonbinding END bound gives
  /// an oxygen/nitrogen mix with zero helium; impossible oxygen-only narcosis
  /// constraints fail explicitly instead of producing negative fractions.
  static Gas customMix({
    required double depthMetres,
    required double oxygenBar,
    required double maximumEndMetres,
    required double oxygenNarcosis,
    required PressureContext pressure,
  }) {
    _positive(oxygenBar, 'oxygenBar');
    requireFinite(maximumEndMetres, 'maximumEndMetres');
    _narcosis(oxygenNarcosis);
    final ambient = pressure.ambientBar(depthMetres);
    final oxygen = oxygenBar / ambient;
    final referencePressure =
        pressure.surfaceBar + maximumEndMetres * pressure.barPerMetre;
    requireFinite(
      referencePressure,
      'END reference pressure',
      nonnegative: true,
    );
    final narcotic = (.79 + .21 * oxygenNarcosis) * referencePressure / ambient;
    requireFinite(narcotic, 'narcotic fraction', nonnegative: true);
    final nitrogen = narcotic - oxygen * oxygenNarcosis;
    if (oxygen > 1 || nitrogen < 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'PO2 and END targets cannot be achieved by a physical gas.',
      );
    }
    final helium = math.max(0.0, 1 - oxygen - nitrogen);
    return Gas(oxygen: oxygen, helium: helium);
  }

  static void _positive(double value, String name) {
    requireFinite(value, name, nonnegative: true);
    if (value == 0) {
      throw CalculationFailure(
        CalculationFailureCode.invalidInput,
        '$name must be positive.',
      );
    }
  }

  static void _narcosis(double value) {
    requireFinite(value, 'oxygenNarcosis', nonnegative: true);
    if (value > 2) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Oxygen narcosis factor must be in [0,2].',
      );
    }
  }
}
