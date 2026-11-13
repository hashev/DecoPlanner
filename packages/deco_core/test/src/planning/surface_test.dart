import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final data =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-altitude-surface-transitions.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final raw in data['altitude_cases'] as List) {
    final item = raw as Map<String, dynamic>;
    test(
      'independent altitude${item['dive_altitude_m']}m acclim${item['acclimatized']} c${item['conservatism']}',
      () {
        final settings = CalculationSettings(
          model: DecompressionModel.vpmB,
          pressure: PressureContext(
            surfaceBar: 1,
            waterVapourBar: .0493,
            barPerMetre: .1,
          ),
          stopGrid: StopGrid.metric(),
          gradientFactors: GradientFactors(low: .3, high: .85),
          vpmConservatism: item['conservatism'] as int,
          altitude: AltitudeSettings(
            enabled: true,
            seaLevelBar: 1,
            diveAltitudeMetres: (item['dive_altitude_m'] as num).toDouble(),
            initialAltitudeMetres: 0,
            acclimatized: item['acclimatized'] as bool,
            travelMin: (item['travel_min'] as num).toDouble(),
            waitMin: (item['wait_min'] as num).toDouble(),
          ),
        );
        final prepared = prepareInitialSurface(settings);
        final expected = item['expected'] as Map<String, dynamic>;
        expect(
          prepared.pressure.surfaceBar,
          closeTo(expected['surface_bar'] as num, 1e-12),
        );
        final tissues = expected['tissues'] as Map<String, dynamic>;
        final bubble = prepared.state.vpm!.toJson();
        for (var i = 0; i < 16; i++) {
          expect(
            prepared.state.tissues.nitrogenBar[i],
            closeTo((tissues['nitrogenBar'] as List)[i] as num, 1e-10),
          );
          expect(
            prepared.state.tissues.heliumBar[i],
            closeTo((tissues['heliumBar'] as List)[i] as num, 1e-10),
          );
        }
        for (final key in [
          'initialRadiusNitrogenMetres',
          'initialRadiusHeliumMetres',
          'adjustedInitialRadiusNitrogenMetres',
          'adjustedInitialRadiusHeliumMetres',
        ]) {
          for (var i = 0; i < 16; i++) {
            expect(
              (bubble[key] as List)[i],
              closeTo((expected[key] as List)[i] as num, 1e-15),
              reason: '$key tissue$i',
            );
          }
        }
        expect(prepared.state.oxygen.cnsFraction, 0);
        expect(prepared.state.oxygen.otu, 0);
      },
    );
  }
  test(
    'post-dive excitation and all SI values match independent full influencing states',
    () {
      final source = data['post_dive'] as Map<String, dynamic>;
      final raw = VpmState.fromJson(
        (source['raw_bubble'] as Map).cast<String, Object?>(),
      );
      final expected = source['finalized_bubble'] as Map<String, dynamic>;
      final parameters = VpmParameters();
      final finalized = finalizeSurfaceBubbles(raw, parameters);
      for (final key in [
        'adjustedInitialRadiusNitrogenMetres',
        'adjustedInitialRadiusHeliumMetres',
      ]) {
        for (var i = 0; i < 16; i++) {
          expect(
            (finalized.toJson()[key] as List)[i],
            closeTo((expected[key] as List)[i] as num, 1e-15),
          );
        }
      }
      final tissues = TissueState.fromJson(
        (source['tissues'] as Map).cast<String, Object?>(),
      );
      final initial = CalculationState(
        tissues: tissues,
        oxygen: OxygenState(cnsFraction: .6, otu: 100),
        vpm: finalized,
      );
      final pressure = PressureContext(
        surfaceBar: (source['pressure_bar'] as num).toDouble(),
        waterVapourBar: (source['vapour_bar'] as num).toDouble(),
        barPerMetre: .1,
      );
      for (final row in data['surface_intervals'] as List) {
        final entry = row as Map<String, dynamic>;
        final minutes = (entry['minutes'] as num).toDouble();
        final actual = recoverSurface(
          initial,
          minutes,
          pressure: pressure,
          kinetics: BuhlmannCoefficients.b().kinetics,
          parameters: parameters,
        );
        final correct = entry['expected_tissues'] as Map<String, dynamic>;
        for (var i = 0; i < 16; i++) {
          expect(
            actual.tissues.nitrogenBar[i],
            closeTo((correct['nitrogenBar'] as List)[i] as num, 1e-10),
          );
          expect(
            actual.tissues.heliumBar[i],
            closeTo((correct['heliumBar'] as List)[i] as num, 1e-10),
          );
          expect(
            actual.vpm!.adjustedInitialRadiusNitrogenMetres[i],
            closeTo(
              (entry['expected_adjusted_n2_radius_m'] as List)[i] as num,
              1e-15,
            ),
          );
          expect(
            actual.vpm!.adjustedInitialRadiusHeliumMetres[i],
            closeTo(
              (entry['expected_adjusted_he_radius_m'] as List)[i] as num,
              1e-15,
            ),
          );
        }
        expect(
          actual.oxygen.cnsFraction,
          closeTo(
            double.parse(entry['expected_cns_from_point6'] as String),
            1e-14,
          ),
        );
        expect(actual.oxygen.otu, 100);
        if (minutes == 0) expect(identical(actual, initial), isTrue);
      }
    },
  );
  test('barometric units and physical sea calibration remain explicit', () {
    expect(barometricPressureBar(0), Units.barPerAta);
    expect(
      barometricPressureBar(2000, seaLevelBar: 1),
      closeTo(.78461793948306475, 1e-13),
    );
    expect(
      barometricPressureBar(8848, seaLevelBar: 1),
      closeTo(.310892761312327, 1e-13),
    );
    final feet = Units.metresToFeet(2000);
    expect(
      barometricPressureBar(Units.feetToMetres(feet)),
      barometricPressureBar(2000),
    );
    expect(
      () => barometricPressureBar(12000),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => AltitudeSettings(
        enabled: true,
        diveAltitudeMetres: 2000,
        acclimatized: false,
        travelMin: 0,
      ),
      throwsA(isA<CalculationFailure>()),
    );
  });
}
