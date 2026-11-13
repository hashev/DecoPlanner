import '../model/gas.dart';
import '../numerics/failure.dart';
import '../units/units.dart';
import 'equation_of_state.dart';
import 'mixing.dart';

void _positive(double value, String name) {
  requireFinite(value, name, nonnegative: true);
  if (value == 0) {
    throw CalculationFailure(
      CalculationFailureCode.invalidInput,
      '$name must be positive.',
    );
  }
}

Gas topOff({
  required Gas initialGas,
  required double initialBar,
  required Gas topUpGas,
  required double finalBar,
}) {
  requireFinite(initialBar, 'initialBar', nonnegative: true);
  _positive(finalBar, 'finalBar');
  if (finalBar < initialBar) {
    throw const CalculationFailure(
      CalculationFailureCode.invalidInput,
      'Top-off cannot reduce cylinder pressure.',
    );
  }
  if (finalBar == initialBar) return initialGas;
  final retainedFraction = initialBar / finalBar;
  return Gas(
    oxygen:
        initialGas.oxygen * retainedFraction +
        topUpGas.oxygen * (1 - retainedFraction),
    helium:
        initialGas.helium * retainedFraction +
        topUpGas.helium * (1 - retainedFraction),
  );
}

double equalizedPressureBar({
  required double firstBar,
  required double firstWaterLitres,
  required double secondBar,
  required double secondWaterLitres,
}) {
  requireFinite(firstBar, 'firstBar', nonnegative: true);
  requireFinite(secondBar, 'secondBar', nonnegative: true);
  _positive(firstWaterLitres, 'firstWaterLitres');
  _positive(secondWaterLitres, 'secondWaterLitres');
  final total = firstWaterLitres + secondWaterLitres;
  requireFinite(total, 'total water volume');
  final firstWeight = firstWaterLitres / total;
  final result = firstBar * firstWeight + secondBar * (1 - firstWeight);
  requireFinite(result, 'equalized pressure', nonnegative: true);
  return result;
}

/// The planner's empirical nominal-capacity conversion. Separate from ideal
/// gas volumes and vdW: pressure correction is 1+0.0002615*bar.
final class CylinderCapacity {
  CylinderCapacity({required this.waterLitres, required this.workingBar}) {
    _positive(waterLitres, 'waterLitres');
    _positive(workingBar, 'workingBar');
  }
  final double waterLitres, workingBar;
  double get workingPsi => Units.barToPsi(workingBar);
  double get nominalCubicFeet {
    final litres = workingBar * waterLitres / (1 + .0002615 * workingBar);
    requireFinite(litres, 'nominal volume', nonnegative: true);
    return Units.litresToCubicFeet(litres);
  }

  factory CylinderCapacity.fromImperial({
    required double nominalCubicFeet,
    required double workingPsi,
  }) {
    _positive(nominalCubicFeet, 'nominalCubicFeet');
    _positive(workingPsi, 'workingPsi');
    final bar = Units.psiToBar(workingPsi);
    final water =
        Units.cubicFeetToLitres(nominalCubicFeet) / bar * (1 + .0002615 * bar);
    return CylinderCapacity(waterLitres: water, workingBar: bar);
  }
}

/// Basis for quoted free gas volumes. Temperature and reference pressure are
/// explicit; this does not assume fill temperature or conflate1bar and1ATA.
final class ReferenceGasVolume {
  ReferenceGasVolume({
    required this.temperatureKelvin,
    required this.pressureBar,
  }) {
    _positive(temperatureKelvin, 'reference temperatureKelvin');
    _positive(pressureBar, 'reference pressureBar');
  }
  final double temperatureKelvin, pressureBar;
  double litresForMoles(double moles) {
    requireFinite(moles, 'moles', nonnegative: true);
    final volume =
        moles *
        GasEquationOfState.gasConstant *
        temperatureKelvin /
        pressureBar;
    requireFinite(volume, 'reference litres', nonnegative: true);
    return volume;
  }
}

final class FillPrices {
  FillPrices({
    required this.oxygenPerLitre,
    required this.heliumPerLitre,
    required this.topUpFlat,
  }) {
    requireFinite(oxygenPerLitre, 'oxygen price', nonnegative: true);
    requireFinite(heliumPerLitre, 'helium price', nonnegative: true);
    requireFinite(topUpFlat, 'flat top-up price', nonnegative: true);
  }
  final double oxygenPerLitre, heliumPerLitre, topUpFlat;
}

final class FillCostLine {
  const FillCostLine(this.component, this.referenceLitres, this.cost);
  final FillComponent component;
  final double referenceLitres, cost;
}

final class FillCost {
  FillCost(Iterable<FillCostLine> lines) : lines = List.unmodifiable(lines);
  final List<FillCostLine> lines;
  double get total => lines.fold(0.0, (sum, line) => sum + line.cost);
}

FillCost fillCost({
  required FillRecipe recipe,
  required double waterLitres,
  required FillPrices prices,
  required ReferenceGasVolume basis,
}) {
  _positive(waterLitres, 'waterLitres');
  final amounts = [
    recipe.oxygenMolesPerLitre,
    recipe.heliumMolesPerLitre,
    recipe.topUpMolesPerLitre,
  ];
  final unitPrices = [
    prices.oxygenPerLitre,
    prices.heliumPerLitre,
    prices.topUpFlat,
  ];
  final lines = <FillCostLine>[];
  for (var i = 0; i < 3; i++) {
    final volume = basis.litresForMoles(amounts[i] * waterLitres);
    final cost = i == 2
        ? (amounts[i] > 0 ? prices.topUpFlat : 0.0)
        : volume * unitPrices[i];
    requireFinite(cost, 'cost', nonnegative: true);
    lines.add(FillCostLine(FillComponent.values[i], volume, cost));
  }
  final result = FillCost(lines);
  requireFinite(result.total, 'total cost', nonnegative: true);
  return result;
}
