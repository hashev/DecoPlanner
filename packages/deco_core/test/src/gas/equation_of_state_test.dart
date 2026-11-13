import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  test('25 roots match independent70-digit mpmath solver', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/independent/vdw-mpmath.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final tolerance = (fixture['tolerance_moles_per_litre'] as num).toDouble();
    for (final raw in fixture['cases'] as List) {
      final row = raw as Map<String, dynamic>;
      final gas = Gas(
        oxygen: (row['oxygen'] as num).toDouble(),
        helium: (row['helium'] as num).toDouble(),
      );
      final eos = GasEquationOfState(
        realGas: true,
        temperatureKelvin: (row['temperature_kelvin'] as num).toDouble(),
      );
      final pressure = (row['pressure_bar'] as num).toDouble();
      final density = eos.molesPerLitre(pressure, gas, CalculationBudget());
      expect(
        density,
        closeTo(double.parse(row['moles_per_litre'] as String), tolerance),
      );
      expect(
        eos.pressureBar(density, gas),
        closeTo(pressure, 1e-10 * pressure + 1e-10),
      );
    }
  });
  test(
    'ideal equation, vacuum and alternating temperatures have no global state',
    () {
      final air = Gas(oxygen: .21);
      final a = GasEquationOfState(temperatureKelvin: 294);
      final b = GasEquationOfState(realGas: true, temperatureKelvin: 310);
      expect(a.pressureBar(1, air), closeTo(24.44463, 1e-12));
      expect(a.molesPerLitre(0, air, CalculationBudget()), 0);
      final before = a.molesPerLitre(200, air, CalculationBudget());
      b.molesPerLitre(300, Gas(oxygen: .18, helium: .45), CalculationBudget());
      expect(a.molesPerLitre(200, air, CalculationBudget()), before);
      expect(a.pressureBar(0, air), 0);
    },
  );
  test(
    'invalid phase, excluded volume, nonfinite and budget failures are explicit',
    () {
      final air = Gas(oxygen: .21);
      expect(
        () => GasEquationOfState(temperatureKelvin: 0),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => GasEquationOfState(
          realGas: true,
          temperatureKelvin: 100,
        ).pressureBar(1, air),
        throwsA(isA<CalculationFailure>()),
      );
      final eos = GasEquationOfState(realGas: true);
      expect(
        () => eos.pressureBar(100, air),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => eos.molesPerLitre(double.infinity, air, CalculationBudget()),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => eos.molesPerLitre(200, air, CalculationBudget(maxIterations: 2)),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.budgetExceeded,
          ),
        ),
      );
    },
  );
}
