import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/vpm_matchers.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-multilevel-descending-units.json',
            ).readAsStringSync(),
          )
          as Map;
  test(
    'independent descending multilevel matrix covers all declared modes, units and conservatisms',
    () {
      final expected = {
        for (var c = 0; c < 5; c++)
          for (final units in ['metric', 'imperial'])
            for (final mode in ['oc', 'ccr', 'bailout'])
              'vpm-multilevel-descending-$mode-$units-c$c',
      };
      final cases = (fixture['cases'] as List).cast<Map>();
      expect(cases.length, 30);
      expect(cases.map((c) => c['id']).toSet(), expected);
    },
  );
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(
      'independent full ${row['id']} descending levels and deco gas changes',
      () {
        final sourceInput = (row['request']['input'] as List).single as Map;
        final gases = (sourceInput['gasmix_summary'] as List).cast<Map>();
        final setpoints = row['setpoints_bar'] as List;
        BreathingGas breathing(int index) {
          final gas = Gas(
            oxygen: (gases[index]['fraction_O2'] as num).toDouble(),
            helium: (gases[index]['fraction_He'] as num).toDouble(),
          );
          return setpoints[index] == null
              ? BreathingGas.oc(gas)
              : BreathingGas.ccr(gas, (setpoints[index] as num).toDouble());
        }

        final summary =
            ((sourceInput['profile_codes'] as List).last
                    as Map)['ascent_summary']
                as List;
        final switches = summary
            .skip(1)
            .cast<Map>()
            .map(
              (s) => GasSwitch(
                depthMetres: (s['starting_depth'] as num).toDouble(),
                breathing: breathing((s['gasmix'] as int) - 1),
              ),
            )
            .toList();
        final source = DiveRequest(
          id: 'source',
          levels: [
            for (final l in (row['levels'] as List).cast<Map>())
              Level(
                depthMetres: (l['depth_metres'] as num).toDouble(),
                durationMin: (l['duration_min'] as num).toDouble(),
                breathing: breathing(row['mode'] == 'oc' ? 0 : 1),
              ),
          ],
          switches: row['mode'] == 'bailout' ? const [] : switches,
          settings: CalculationSettings(
            model: DecompressionModel.vpmB,
            pressure: PressureContext(
              surfaceBar: 1.01325,
              waterVapourBar: .0493,
              barPerMetre: .1,
            ),
            stopGrid: StopGrid(
              stepMetres: (row['step_metres'] as num).toDouble(),
              lastStopMetres: (row['step_metres'] as num).toDouble(),
            ),
            gradientFactors: GradientFactors(low: .3, high: .85),
            vpmConservatism: row['conservatism'] as int,
          ),
        );
        final before = jsonEncode(source.toJson());
        final result = row['mode'] == 'bailout'
            ? calculateVpmBailout(
                source,
                BailoutRequest(
                  id: row['id'],
                  sourceDiveId: source.id,
                  runtimeMin: (row['bailout_runtime_min'] as num).toDouble(),
                  initialOcGas: breathing(2).gas,
                  switches: switches,
                ),
              )
            : calculateVpm(source);
        expectVpmProfile(result, row);
        final initial = row['initial'] as Map;
        expectTissues(
          result.initialState.tissues.toJson(),
          initial['tissues'] as Map,
          'initial',
        );
        expect(
          result.pressure.surfaceBar,
          closeTo(initial['pressure_bar'] as num, 1e-12),
        );
        for (var i = 0; i < 16; i++) {
          expect(
            result.initialState.vpm!.adjustedInitialRadiusNitrogenMetres[i],
            closeTo(initial['radius_n2_m'][i] as num, 1e-15),
          );
          expect(
            result.initialState.vpm!.adjustedInitialRadiusHeliumMetres[i],
            closeTo(initial['radius_he_m'][i] as num, 1e-15),
          );
        }
        final expectedPrefix = (row['expected_profile_segments'] as List)
            .cast<Map>();
        for (var i = 0; i < expectedPrefix.length; i++) {
          final segment = result.segments[i], expected = expectedPrefix[i];
          final b = breathing(expected['gas_index'] as int);
          expect(
            segment.physical.endDepthMetres,
            closeTo(expected['end_depth_m'] as num, 1e-10),
          );
          expect(segment.physical.breathing.toJson(), b.toJson());
        }
        expect(
          result.runtimeMin,
          closeTo(
            (row['expected_segments'] as List).last['end_min'] as num,
            1e-7,
          ),
        );
        expect(jsonEncode(source.toJson()), before);
        if (row['units'] == 'imperial') {
          expect(source.levels.first.depthMetres, Units.feetToMetres(100));
          expect(source.settings.stopGrid.stepMetres, Units.feetToMetres(10));
        }
      },
    );
  }
}
