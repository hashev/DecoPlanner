import '../numerics/failure.dart';

void requireFinite(double value, String field, {bool nonnegative = false}) {
  if (!value.isFinite || (nonnegative && value < 0)) {
    throw CalculationFailure(
      CalculationFailureCode.invalidInput,
      '$field must be finite${nonnegative ? ' and nonnegative' : ''}.',
    );
  }
}

enum DisplayUnits { metric, imperial }

/// Display conversion only. Never changes the physical settings of a request.
abstract final class Units {
  static const metresPerFoot = 0.3048;
  static const barPerAta = 1.01325;
  static const barPerPsi = 0.0689475729317831;
  static const litresPerCubicFoot = 28.316846592;

  static double metresToFeet(double metres) =>
      _convert(metres, 1 / metresPerFoot);
  static double feetToMetres(double feet) => _convert(feet, metresPerFoot);
  static double ataToBar(double ata) => _convert(ata, barPerAta);
  static double barToAta(double bar) => _convert(bar, 1 / barPerAta);
  static double psiToBar(double psi) => _convert(psi, barPerPsi);
  static double barToPsi(double bar) => _convert(bar, 1 / barPerPsi);
  static double litresToCubicFeet(double litres) =>
      _convert(litres, 1 / litresPerCubicFoot);
  static double cubicFeetToLitres(double feet) =>
      _convert(feet, litresPerCubicFoot);
  static double _convert(double value, double factor) {
    requireFinite(value, 'value');
    final result = value * factor;
    requireFinite(result, 'converted value');
    return result;
  }
}

/// Explicit hydrostatic context; pressure in bar, depth in metres.
final class PressureContext {
  PressureContext({
    required this.surfaceBar,
    required this.waterVapourBar,
    required this.barPerMetre,
  }) {
    requireFinite(surfaceBar, 'surfaceBar', nonnegative: true);
    requireFinite(waterVapourBar, 'waterVapourBar', nonnegative: true);
    requireFinite(barPerMetre, 'barPerMetre', nonnegative: true);
    if (surfaceBar <= waterVapourBar || barPerMetre == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Surface must exceed vapour pressure; hydrostatic gradient must be positive.',
      );
    }
  }
  final double surfaceBar;
  final double waterVapourBar;
  final double barPerMetre;

  double ambientBar(double depthMetres) {
    requireFinite(depthMetres, 'depthMetres', nonnegative: true);
    final result = surfaceBar + depthMetres * barPerMetre;
    requireFinite(result, 'ambientBar');
    return result;
  }

  double depthMetres(double ambientBar) {
    requireFinite(ambientBar, 'ambientBar', nonnegative: true);
    final result = (ambientBar - surfaceBar) / barPerMetre;
    requireFinite(result, 'depthMetres');
    return result;
  }
}

final class StopGrid {
  StopGrid({required this.stepMetres, required this.lastStopMetres}) {
    requireFinite(stepMetres, 'stepMetres', nonnegative: true);
    requireFinite(lastStopMetres, 'lastStopMetres', nonnegative: true);
    if (stepMetres == 0 || lastStopMetres < stepMetres) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Stop step must be positive and last stop at least one step.',
      );
    }
  }
  factory StopGrid.metric() => StopGrid(stepMetres: 3, lastStopMetres: 3);
  factory StopGrid.imperial() => StopGrid(
    stepMetres: Units.feetToMetres(10),
    lastStopMetres: Units.feetToMetres(10),
  );
  final double stepMetres;
  final double lastStopMetres;

  double atOrDeeper(double ceilingMetres) {
    requireFinite(ceilingMetres, 'ceilingMetres');
    if (ceilingMetres <= 0) return 0;
    if (ceilingMetres <= lastStopMetres) return lastStopMetres;
    return lastStopMetres +
        ((ceilingMetres - lastStopMetres) / stepMetres).ceil() * stepMetres;
  }

  double nextShallower(double depthMetres) {
    requireFinite(depthMetres, 'depthMetres', nonnegative: true);
    if (depthMetres <= lastStopMetres) return 0;
    final next = depthMetres - stepMetres;
    return next < lastStopMetres ? lastStopMetres : next;
  }
}
