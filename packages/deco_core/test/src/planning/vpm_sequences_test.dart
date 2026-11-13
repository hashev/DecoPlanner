import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/vpm_matchers.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-full-altitude-repetitive.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test('independent full VPM sequence ${row['id']}', () {
      final input = row['request'] as Map<String, dynamic>;
      final nativeSettings = input['settings'] as Map<String, dynamic>;
      final nativeAltitude = input['altitude'] as Map<String, dynamic>;
      final altitude = nativeSettings['Altitude_Dive_Algorithm'] == 'ON';
      final settings = CalculationSettings(
        model: DecompressionModel.vpmB,
        pressure: PressureContext(
          surfaceBar: 1.01325,
          waterVapourBar: .0493,
          barPerMetre: .1,
        ),
        stopGrid: StopGrid.metric(),
        gradientFactors: GradientFactors(low: .3, high: .85),
        vpmConservatism: row['conservatism'] as int,
        altitude: AltitudeSettings(
          enabled: altitude,
          seaLevelBar: 1,
          diveAltitudeMetres: (nativeAltitude['Altitude_of_Dive'] as num)
              .toDouble(),
          initialAltitudeMetres: 0,
          acclimatized:
              nativeAltitude['Diver_Acclimatized_at_Altitude'] == 'yes',
          travelMin: (nativeAltitude['Ascent_to_Altitude_Hours'] as num) * 60,
          waitMin:
              (nativeAltitude['Hours_at_Altitude_Before_Dive'] as num) * 60,
        ),
      );
      CalculationState? previous;
      final nativeDives = (input['input'] as List).cast<Map<String, dynamic>>();
      final expectedDives = (row['dives'] as List).cast<Map<String, dynamic>>();
      for (var dive = 0; dive < nativeDives.length; dive++) {
        final source = nativeDives[dive], expected = expectedDives[dive];
        final sourceLevels = (source['profile_codes'] as List)
            .cast<Map<String, dynamic>>();
        final gases = (source['gasmix_summary'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (g) => BreathingGas.oc(
                Gas(
                  oxygen: (g['fraction_O2'] as num).toDouble(),
                  helium: (g['fraction_He'] as num).toDouble(),
                ),
              ),
            )
            .toList();
        final savedPrevious = previous == null
            ? null
            : jsonEncode(previous.toJson());
        final result = calculateVpm(
          DiveRequest(
            id: '${row['id']}-$dive',
            settings: settings,
            initialState: previous,
            surfaceIntervalMin: dive == 0
                ? 0
                : (row['surface_interval_min'] as num).toDouble(),
            levels: [
              Level(
                depthMetres: (sourceLevels[1]['depth'] as num).toDouble(),
                durationMin:
                    (sourceLevels[1]['run_time_at_end_of_segment'] as num)
                        .toDouble(),
                breathing: gases.first,
              ),
            ],
            switches: ((sourceLevels.last['ascent_summary'] as List).skip(1))
                .cast<Map<String, dynamic>>()
                .map(
                  (g) => GasSwitch(
                    depthMetres: (g['starting_depth'] as num).toDouble(),
                    breathing: gases[(g['gasmix'] as int) - 1],
                  ),
                ),
          ),
        );
        if (previous != null) {
          expect(jsonEncode(previous.toJson()), savedPrevious);
        }
        final initial = expected['initial'] as Map<String, dynamic>;
        expect(
          result.pressure.surfaceBar,
          closeTo(initial['pressure_bar'] as num, 1e-12),
        );
        expectTissues(
          result.initialState.tissues.toJson(),
          initial['tissues'] as Map,
          'initial dive$dive',
        );
        expectOxygen(result.initialState.oxygen, initial['oxygen'] as Map);
        for (var i = 0; i < 16; i++) {
          expect(
            result.initialState.vpm!.adjustedInitialRadiusNitrogenMetres[i],
            closeTo((initial['radius_n2_m'] as List)[i] as num, 1e-15),
          );
          expect(
            result.initialState.vpm!.adjustedInitialRadiusHeliumMetres[i],
            closeTo((initial['radius_he_m'] as List)[i] as num, 1e-15),
          );
        }
        final segments = result.segments
            .where(
              (s) =>
                  s.phase == SegmentPhase.ascent ||
                  s.phase == SegmentPhase.decompression,
            )
            .toList();
        final nativeSegments = (expected['expected_segments'] as List)
            .cast<Map<String, dynamic>>();
        expect(segments.length, nativeSegments.length);
        for (var n = 0; n < segments.length; n++) {
          final a = segments[n], e = nativeSegments[n];
          expect(a.phase.name, e['kind']);
          expect(
            a.physical.endDepthMetres,
            closeTo(e['end_depth_m'] as num, 1e-10),
          );
          expect(
            a.physical.durationMin,
            closeTo(e['duration_min'] as num, 1e-7),
          );
          expect(a.endMin, closeTo(e['end_min'] as num, 1e-7));
          expect(
            a.physical.breathing.toJson(),
            gases[e['gas_index'] as int].toJson(),
          );
          expectTissues(
            a.endState.tissues.toJson(),
            e['tissues'] as Map,
            'dive$dive segment$n',
          );
          expectOxygen(a.endState.oxygen, e['expected_oxygen'] as Map);
        }
        expectVpmBubble(
          result.finalState.vpm!,
          expected['expected_bubble'] as Map<String, dynamic>,
        );
        expectOxygen(
          result.finalState.oxygen,
          expected['expected_oxygen'] as Map,
        );
        previous = CalculationState.fromJson(
          (jsonDecode(jsonEncode(result.finalState.toJson())) as Map)
              .cast<String, Object?>(),
        );
      }
    });
  }
}

void expectOxygen(OxygenState actual, Map expected) {
  expect(
    actual.cnsFraction,
    closeTo(double.parse(expected['cns_fraction'] as String), 1e-12),
  );
  expect(actual.otu, closeTo(double.parse(expected['otu'] as String), 1e-10));
}
