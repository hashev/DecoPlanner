import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final pressure = PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  );
  final air = Gas(oxygen: .21),
      ean32 = Gas(oxygen: .32),
      trimix = Gas(oxygen: .18, helium: .45);
  test(
    'MOD/min depth solve partial-pressure equation with explicit ATA/bar',
    () {
      expect(
        GasProperties.maximumDepthMetres(ean32, Units.ataToBar(1.6), pressure),
        closeTo(40.53, 1e-12),
      );
      expect(
        GasProperties.minimumDepthMetres(air, Units.ataToBar(.18), pressure),
        0,
      );
      final hypoxic = Gas(oxygen: .1, helium: .7);
      expect(
        GasProperties.minimumDepthMetres(
          hypoxic,
          Units.ataToBar(.18),
          pressure,
        ),
        closeTo(8.106, 1e-12),
      );
      final mod = GasProperties.maximumDepthMetres(trimix, 1.4, pressure)!;
      expect(pressure.ambientBar(mod) * trimix.oxygen, closeTo(1.4, 1e-14));
      expect(
        GasProperties.maximumDepthMetres(
          Gas(oxygen: 0, helium: 1),
          1.6,
          pressure,
        ),
        isNull,
      );
      expect(
        GasProperties.minimumDepthMetres(Gas(oxygen: 0), .18, pressure),
        isNull,
      );
      expect(
        GasProperties.maximumDepthMetres(Gas(oxygen: 1), .5, pressure),
        isNull,
      );
    },
  );
  test('air END is physical depth for every supported narcosis factor', () {
    for (final factor in [0.0, .3, 1.0, 2.0]) {
      expect(
        GasProperties.equivalentNarcoticDepthMetres(air, 30, factor, pressure),
        closeTo(30, 1e-12),
      );
    }
    expect(
      GasProperties.equivalentNarcoticDepthMetres(trimix, 40, 0, pressure),
      lessThan(
        GasProperties.equivalentNarcoticDepthMetres(trimix, 40, 1, pressure),
      ),
    );
  });
  test('reference densities and equal-air depth', () {
    expect(
      GasProperties.densityGramsPerLitre(air, 0, pressure),
      closeTo(1.2878, 1e-14),
    );
    expect(
      GasProperties.densityGramsPerLitre(Gas(oxygen: 1), 0, pressure),
      1.43,
    );
    expect(
      GasProperties.densityGramsPerLitre(
        Gas(oxygen: 0, helium: 1),
        0,
        pressure,
      ),
      .18,
    );
    expect(
      GasProperties.equivalentAirDensityDepthMetres(air, 30, pressure),
      closeTo(30, 1e-12),
    );
    expect(
      GasProperties.densityGramsPerLitre(trimix, 30, pressure),
      lessThan(GasProperties.densityGramsPerLitre(air, 30, pressure)),
    );
  });
  test('density preserves three saved original presentation observations', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/gas_properties/legacy-density.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final raw in fixture['cases'] as List) {
      final row = raw as Map<String, dynamic>;
      final input = row['request'] as Map<String, dynamic>;
      final expected = row['expected_display'] as Map<String, dynamic>;
      final gas = Gas(
        oxygen: (input['oxygen'] as num).toDouble(),
        helium: (input['helium'] as num).toDouble(),
      );
      final depth = (input['depth_m'] as num).toDouble();
      expect(
        GasProperties.densityGramsPerLitre(
          gas,
          depth,
          pressure,
        ).toStringAsFixed(1),
        expected['density_g_l'],
      );
      expect(
        GasProperties.equivalentAirDensityDepthMetres(
          gas,
          depth,
          pressure,
        ).toStringAsFixed(1),
        expected['equivalent_air_density_depth_m'],
      );
    }
  });
  test('custom mix satisfies PO2 and END before presentation rounding', () {
    for (final factor in [0.0, .3, 1.0, 2.0]) {
      final gas = GasProperties.customMix(
        depthMetres: 45,
        oxygenBar: Units.ataToBar(1.3),
        maximumEndMetres: 30,
        oxygenNarcosis: factor,
        pressure: pressure,
      );
      expect(
        gas.oxygen * pressure.ambientBar(45),
        closeTo(Units.ataToBar(1.3), 1e-14),
      );
      expect(
        GasProperties.equivalentNarcoticDepthMetres(gas, 45, factor, pressure),
        closeTo(30, 1e-12),
      );
    }
    final gas = GasProperties.customMix(
      depthMetres: 45,
      oxygenBar: Units.ataToBar(1.3),
      maximumEndMetres: 30,
      oxygenNarcosis: 1,
      pressure: pressure,
    );
    expect((gas.oxygen * 100).toStringAsFixed(1), '23.9');
    expect((gas.helium * 100).toStringAsFixed(1), '27.2');
  });
  test(
    'nonbinding END uses zero helium; invalid targets and fractions fail',
    () {
      final gas = GasProperties.customMix(
        depthMetres: 10,
        oxygenBar: 1,
        maximumEndMetres: 50,
        oxygenNarcosis: 1,
        pressure: pressure,
      );
      expect(gas.helium, 0);
      expect(
        () => GasProperties.customMix(
          depthMetres: 45,
          oxygenBar: 3,
          maximumEndMetres: 0,
          oxygenNarcosis: 2,
          pressure: pressure,
        ),
        throwsA(isA<CalculationFailure>()),
      );
      for (final invalid in [double.nan, double.infinity, -1.0, 0.0]) {
        expect(
          () => GasProperties.maximumDepthMetres(air, invalid, pressure),
          throwsA(isA<CalculationFailure>()),
        );
      }
      expect(() => Gas(oxygen: -.1), throwsA(isA<CalculationFailure>()));
      expect(
        () => Gas(oxygen: .8, helium: .3),
        throwsA(isA<CalculationFailure>()),
      );
    },
  );
}
