import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  test('top-off mass balance, empty cylinder and identity', () {
    final air = Gas(oxygen: .21), ean32 = Gas(oxygen: .32);
    final result = topOff(
      initialGas: air,
      initialBar: 50,
      topUpGas: ean32,
      finalBar: 200,
    );
    expect(result.oxygen, closeTo(.2925, 1e-15));
    expect(result.helium, 0);
    expect(
      topOff(
        initialGas: air,
        initialBar: 0,
        topUpGas: ean32,
        finalBar: 200,
      ).oxygen,
      .32,
    );
    expect(
      identical(
        topOff(
          initialGas: air,
          initialBar: 200,
          topUpGas: ean32,
          finalBar: 200,
        ),
        air,
      ),
      isTrue,
    );
    expect(
      () => topOff(
        initialGas: air,
        initialBar: 200,
        topUpGas: ean32,
        finalBar: 100,
      ),
      throwsA(isA<CalculationFailure>()),
    );
  });
  test(
    'equalizer preserves PV and is invariant to order and common volume units',
    () {
      final result = equalizedPressureBar(
        firstBar: 50,
        firstWaterLitres: 12,
        secondBar: 200,
        secondWaterLitres: 50,
      );
      expect(result, closeTo(10600 / 62, 1e-12));
      expect(result * 62, closeTo(50 * 12 + 200 * 50, 1e-10));
      expect(
        equalizedPressureBar(
          firstBar: 200,
          firstWaterLitres: 50,
          secondBar: 50,
          secondWaterLitres: 12,
        ),
        result,
      );
      expect(
        equalizedPressureBar(
          firstBar: 100,
          firstWaterLitres: 12,
          secondBar: 100,
          secondWaterLitres: 50,
        ),
        100,
      );
      expect(
        equalizedPressureBar(
          firstBar: 0,
          firstWaterLitres: 12,
          secondBar: 0,
          secondWaterLitres: 50,
        ),
        0,
      );
      expect(
        equalizedPressureBar(
          firstBar: 50,
          firstWaterLitres: 1200,
          secondBar: 200,
          secondWaterLitres: 5000,
        ),
        result,
      );
    },
  );
  test(
    'empirical cylinder conversion keeps raw round trip, original display92.7/3365',
    () {
      final tank = CylinderCapacity(waterLitres: 12, workingBar: 232);
      expect(tank.nominalCubicFeet.toStringAsFixed(1), '92.7');
      expect(tank.workingPsi.round(), 3365);
      final back = CylinderCapacity.fromImperial(
        nominalCubicFeet: tank.nominalCubicFeet,
        workingPsi: tank.workingPsi,
      );
      expect(back.waterLitres, closeTo(12, 1e-12));
      expect(back.workingBar, closeTo(232, 1e-12));
    },
  );
  test(
    'cost uses purchased quantities, explicit reference basis and prices regardless fill order',
    () {
      final air = Gas(oxygen: .21), target = Gas(oxygen: .18, helium: .45);
      final eos = GasEquationOfState();
      final prices = FillPrices(
        oxygenPerLitre: .01,
        heliumPerLitre: .03,
        topUpFlat: 10,
      );
      final basis = ReferenceGasVolume(temperatureKelvin: 294, pressureBar: 1);
      for (final order in FillOrder.values) {
        final recipe = partialPressureMix(
          initialGas: air,
          initialBar: 0,
          targetGas: target,
          targetBar: 200,
          topUpGas: air,
          eos: eos,
          order: order,
        );
        final result = fillCost(
          recipe: recipe,
          waterLitres: 12,
          prices: prices,
          basis: basis,
        );
        expect(result.lines[1].referenceLitres, closeTo(1080, 1e-10));
        expect(result.lines[1].cost, closeTo(32.4, 1e-12));
        expect(result.total, closeTo(44.35949367088608, 1e-10));
        final free = fillCost(
          recipe: recipe,
          waterLitres: 12,
          prices: FillPrices(
            oxygenPerLitre: 0,
            heliumPerLitre: 0,
            topUpFlat: 0,
          ),
          basis: basis,
        );
        expect(free.total, 0);
      }
    },
  );
  test(
    'original controller cost1306 uses a flat top-up charge, not a litre price',
    () {
      final recipe = partialPressureMix(
        initialGas: Gas(oxygen: .21),
        initialBar: 0,
        targetGas: Gas(oxygen: 71 / 220, helium: 70 / 220),
        targetBar: 220,
        topUpGas: Gas(oxygen: .21),
        eos: GasEquationOfState(),
      );
      final result = fillCost(
        recipe: recipe,
        waterLitres: 24,
        prices: FillPrices(
          oxygenPerLitre: .10,
          heliumPerLitre: .70,
          topUpFlat: 10,
        ),
        basis: ReferenceGasVolume(temperatureKelvin: 294, pressureBar: 1),
      );
      expect(result.lines[0].referenceLitres, closeTo(1200, 1e-10));
      expect(result.lines[1].referenceLitres, closeTo(1680, 1e-10));
      expect(result.lines[2].cost, 10);
      expect(result.total, closeTo(1306, 1e-10));
      final pure = partialPressureMix(
        initialGas: Gas(oxygen: .21),
        initialBar: 0,
        targetGas: Gas(oxygen: 1),
        targetBar: 200,
        topUpGas: Gas(oxygen: .21),
        eos: GasEquationOfState(),
      );
      final noTopUp = fillCost(
        recipe: pure,
        waterLitres: 12,
        prices: FillPrices(
          oxygenPerLitre: .10,
          heliumPerLitre: .70,
          topUpFlat: 10,
        ),
        basis: ReferenceGasVolume(temperatureKelvin: 294, pressureBar: 1),
      );
      expect(noTopUp.lines[2].referenceLitres, 0);
      expect(noTopUp.lines[2].cost, 0);
    },
  );
  test('zero/negative/nonfinite cylinder and price inputs fail', () {
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => CylinderCapacity(waterLitres: invalid, workingBar: 232),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => equalizedPressureBar(
          firstBar: 50,
          firstWaterLitres: invalid,
          secondBar: 200,
          secondWaterLitres: 50,
        ),
        throwsA(isA<CalculationFailure>()),
      );
    }
    expect(
      () => FillPrices(oxygenPerLitre: -1, heliumPerLitre: 0, topUpFlat: 0),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => ReferenceGasVolume(temperatureKelvin: 294, pressureBar: 0),
      throwsA(isA<CalculationFailure>()),
    );
  });
}
