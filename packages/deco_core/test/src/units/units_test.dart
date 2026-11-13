import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/legacy_pressure_depth.dart';

void main() {
  test('ATA, bar and psi are distinct; conversions round trip unrounded', () {
    expect(Units.ataToBar(1), 1.01325);
    for (final value in [0.0, 0.123456789, 1.01325, 300.0]) {
      expect(Units.ataToBar(Units.barToAta(value)), closeTo(value, 1e-12));
      expect(Units.psiToBar(Units.barToPsi(value)), closeTo(value, 1e-12));
      expect(
        Units.feetToMetres(Units.metresToFeet(value)),
        closeTo(value, 1e-12),
      );
      expect(
        Units.cubicFeetToLitres(Units.litresToCubicFeet(value)),
        closeTo(value, 1e-12),
      );
    }
  });
  test(
    'legacy pressure-depth conventions normalize same physical pressure',
    () {
      final metric = LegacyPressureDepth.metric();
      final imperial = LegacyPressureDepth.imperial();
      expect(metric.toBar(10.1325), 1.01325);
      expect(imperial.toBar(33), 1.01325);
      expect(metric.toBar(0.627), closeTo(0.0627, 1e-15));
      for (final pressure in [0.0493, 0.7509345, 1.01325, 5.123456789]) {
        expect(
          metric.toBar(metric.fromBar(pressure)),
          closeTo(pressure, 1e-14),
        );
        expect(
          imperial.toBar(imperial.fromBar(pressure)),
          closeTo(pressure, 1e-14),
        );
      }
    },
  );
  test(
    'display changes preserve hydrostatic context and physical stop grid',
    () {
      final context = PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: .0627,
        barPerMetre: .1,
      );
      final grid = StopGrid.metric();
      final feet = Units.metresToFeet(30);
      expect(
        context.ambientBar(Units.feetToMetres(feet)),
        context.ambientBar(30),
      );
      expect(context.depthMetres(context.ambientBar(30)), closeTo(30, 1e-13));
      expect(grid.stepMetres, 3);
      expect(StopGrid.imperial().stepMetres, 3.048);
      expect(grid.atOrDeeper(9.0001), 12);
      expect(grid.atOrDeeper(0), 0);
      expect(grid.nextShallower(3), 0);
      final six = StopGrid(stepMetres: 3, lastStopMetres: 6);
      expect(six.atOrDeeper(1), 6);
      expect(six.nextShallower(9), 6);
      expect(six.nextShallower(6), 0);
    },
  );
  test('invalid and overflowing physical input fails at boundary', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => Units.ataToBar(value), throwsA(isA<CalculationFailure>()));
    }
    expect(() => Units.metresToFeet(1e308), throwsA(isA<CalculationFailure>()));
    expect(
      () => StopGrid(stepMetres: 0, lastStopMetres: 3),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => PressureContext(
        surfaceBar: .01,
        waterVapourBar: .0627,
        barPerMetre: .1,
      ),
      throwsA(isA<CalculationFailure>()),
    );
  });
}
