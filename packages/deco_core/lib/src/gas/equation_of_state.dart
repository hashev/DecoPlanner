import 'dart:math' as math;
import '../model/gas.dart';
import '../numerics/failure.dart';
import '../numerics/solver.dart';
import '../units/units.dart';

/// Versioned, explicit-temperature van der Waals reference model. Amount is
/// mol/L of water volume, pressure bar, temperature K. No static unit index.
final class GasEquationOfState {
  GasEquationOfState({this.realGas = false, this.temperatureKelvin = 294}) {
    requireFinite(temperatureKelvin, 'temperatureKelvin', nonnegative: true);
    if (temperatureKelvin == 0) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'Temperature must be positive.',
      );
    }
  }
  static const gasConstant = 0.083145;
  final bool realGas;
  final double temperatureKelvin;
  String get version => realGas ? 'vdw-double-v1' : 'ideal-double-v1';
  double get rt => gasConstant * temperatureKelvin;

  ({double a, double b}) coefficients(Gas gas) {
    final aRoot =
        gas.oxygen * math.sqrt(1.382) +
        gas.nitrogen * math.sqrt(1.37) +
        gas.helium * math.sqrt(.0346);
    final a = aRoot * aRoot;
    final b = gas.oxygen * .03186 + gas.nitrogen * .0387 + gas.helium * .0238;
    return (a: a, b: b);
  }

  void _validateGasPhase(Gas gas) {
    if (!realGas) return;
    final c = coefficients(gas);
    // Above the mixture's vdW critical temperature the isotherm is monotonic;
    // a bracketed root is unique. Do not silently choose a liquid branch.
    if (temperatureKelvin <= 8 * c.a / (27 * gasConstant * c.b)) {
      throw const CalculationFailure(
        CalculationFailureCode.invalidInput,
        'EOS gas-phase calculation requires temperature above its critical point.',
      );
    }
  }

  double pressureBar(double molesPerLitre, Gas gas) {
    requireFinite(molesPerLitre, 'molesPerLitre', nonnegative: true);
    _validateGasPhase(gas);
    if (molesPerLitre == 0) return 0;
    var value = rt * molesPerLitre;
    if (realGas) {
      final c = coefficients(gas);
      final available = 1 - c.b * molesPerLitre;
      if (available <= 0) {
        throw const CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Molar volume does not exceed excluded volume.',
        );
      }
      value = value / available - c.a * molesPerLitre * molesPerLitre;
    }
    requireFinite(value, 'EOS pressure', nonnegative: true);
    return value;
  }

  double molesPerLitre(double pressure, Gas gas, CalculationBudget budget) {
    requireFinite(pressure, 'pressureBar', nonnegative: true);
    _validateGasPhase(gas);
    budget.check();
    if (pressure == 0) return 0;
    if (!realGas) {
      final value = pressure / rt;
      requireFinite(value, 'molesPerLitre', nonnegative: true);
      return value;
    }
    final c = coefficients(gas);
    final upper = (1 - 1e-12) / c.b;
    final tolerance = 1e-10 * math.max(1.0, pressure);
    return solveBracketed(
      function: (n) => pressureBar(n, gas) - pressure,
      lower: 0,
      upper: upper,
      budget: budget,
      residualTolerance: tolerance,
      positionTolerance: 1e-14,
      maxIterations: 256,
    ).value;
  }
}
