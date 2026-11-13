import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/vpm_matchers.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-ccr-altitude-repetitive.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test('independent full VPM ${row['id']}', () {
      final input = row['request'] as Map;
      final nativeSettings = input['settings'] as Map;
      final nativeAltitude = input['altitude'] as Map;
      final altitude = nativeSettings['Altitude_Dive_Algorithm'] == 'ON';
      final nativeDives = input['input'] as List;
      final expectedDives = row['dives'] as List;
      CalculationState? previous;
      for (var i = 0; i < nativeDives.length; i++) {
        final dive = nativeDives[i] as Map;
        final expected = expectedDives[i] as Map<String, dynamic>;
        final mode = (row['modes'] as List)[i];
        final setpoints = (row['setpoints_by_dive'] as List)[i] as List;
        final nativeGases = dive['gasmix_summary'] as List;
        final gases = [
          for (var g = 0; g < nativeGases.length; g++)
            Gas(
              oxygen: ((nativeGases[g] as Map)['fraction_O2'] as num)
                  .toDouble(),
              helium: ((nativeGases[g] as Map)['fraction_He'] as num)
                  .toDouble(),
            ),
        ];
        BreathingGas breathing(int index) => setpoints[index] == null
            ? BreathingGas.oc(gases[index])
            : BreathingGas.ccr(
                gases[index],
                (setpoints[index] as num).toDouble(),
              );
        final profile = dive['profile_codes'] as List;
        final summary = ((profile.last as Map)['ascent_summary'] as List)
            .cast<Map>();
        final switches = [
          for (final s in summary.skip(1))
            GasSwitch(
              depthMetres: (s['starting_depth'] as num).toDouble(),
              breathing: breathing((s['gasmix'] as int) - 1),
            ),
        ];
        final settings = CalculationSettings(
          model: DecompressionModel.vpmB,
          pressure: PressureContext(
            surfaceBar: 1.01325,
            waterVapourBar: .0493,
            barPerMetre: .1,
          ),
          stopGrid: StopGrid.metric(),
          gradientFactors: GradientFactors(low: .3, high: .85),
          vpmConservatism: 2,
          lowSetpointBar: (setpoints.first as num?)?.toDouble() ?? .7,
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
        final request = DiveRequest(
          id: 'source-$i',
          settings: settings,
          initialState: previous,
          surfaceIntervalMin: i == 0
              ? 0
              : (row['surface_interval_min'] as num).toDouble(),
          levels: [
            Level(depthMetres: 45, durationMin: 25, breathing: breathing(1)),
          ],
          switches: mode == 'bailout' ? const [] : switches,
        );
        final saved = previous == null ? null : jsonEncode(previous.toJson());
        final result = mode == 'bailout'
            ? calculateVpmBailout(
                request,
                BailoutRequest(
                  id: 'escape-$i',
                  sourceDiveId: request.id,
                  runtimeMin: 25,
                  initialOcGas: gases[2],
                  switches: switches,
                ),
              )
            : calculateVpm(request);
        final initial = expected['initial'] as Map;
        expect(
          result.pressure.surfaceBar,
          closeTo(initial['pressure_bar'] as num, 1e-12),
        );
        expectTissues(
          result.initialState.tissues.toJson(),
          initial['tissues'] as Map,
          'initial dive$i',
        );
        expectReferenceOxygen(
          result.initialState.oxygen,
          initial['oxygen'] as Map,
        );
        for (var j = 0; j < 16; j++) {
          expect(
            result.initialState.vpm!.adjustedInitialRadiusNitrogenMetres[j],
            closeTo((initial['radius_n2_m'] as List)[j] as num, 1e-15),
          );
          expect(
            result.initialState.vpm!.adjustedInitialRadiusHeliumMetres[j],
            closeTo((initial['radius_he_m'] as List)[j] as num, 1e-15),
          );
        }
        expectVpmProfile(result, {
          ...expected,
          'request': {
            'input': [dive],
          },
          'setpoints_bar': setpoints,
        });
        if (previous != null) expect(jsonEncode(previous.toJson()), saved);
        previous = CalculationState.fromJson(result.finalState.toJson());
        if (row['surface_interval_min'] == 0) {
          expect(
            identical(
              recoverSurface(
                previous,
                0,
                pressure: result.pressure,
                kinetics: BuhlmannCoefficients.b().kinetics,
                parameters: settings.vpm,
              ),
              previous,
            ),
            isTrue,
          );
        }
      }
    });
  }
}
