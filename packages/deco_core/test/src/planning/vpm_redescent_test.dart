import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/vpm_matchers.dart';

void main() {
  final data =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-redescent-normalized.json',
            ).readAsStringSync(),
          )
          as Map;
  test(
    'independent redescent matrix contains all 60 variant/mode/unit/conservatism combinations',
    () {
      final expected = {
        for (var c = 0; c < 5; c++)
          for (final units in ['metric', 'imperial'])
            for (final mode in ['oc', 'ccr', 'bailout'])
              for (final suffix in ['', '-stops'])
                'vpm-redescent$suffix-$mode-$units-c$c',
      };
      final cases = (data['cases'] as List).cast<Map>();
      expect(cases.length, 60);
      expect(cases.map((r) => r['id']).toSet(), expected);
    },
  );
  for (final row in (data['cases'] as List).cast<Map<String, dynamic>>()) {
    test('independent partial-ascent and redescent ${row['id']}', () {
      final input = (row['request']['input'] as List).single as Map;
      final gases = (input['gasmix_summary'] as List).cast<Map>();
      final sp = row['setpoints_bar'] as List;
      BreathingGas breathing(int index) {
        final gas = Gas(
          oxygen: (gases[index]['fraction_O2'] as num).toDouble(),
          helium: (gases[index]['fraction_He'] as num).toDouble(),
        );
        return sp[index] == null
            ? BreathingGas.oc(gas)
            : BreathingGas.ccr(gas, (sp[index] as num).toDouble());
      }

      List<GasSwitch> switches(List summary) => summary
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
          for (final l in row['levels'] as List)
            Level(
              depthMetres: (l[0] as num).toDouble(),
              durationMin: (l[1] as num).toDouble(),
              breathing: breathing((l[3] as int) - 1),
            ),
        ],
        switches: switches(row['intermediate_summary'] as List),
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
      final expected = (row['expected_timeline'] as List).cast<Map>();
      final before = jsonEncode(source.toJson());
      final result = row['mode'] == 'bailout'
          ? calculateVpmBailout(
              source,
              BailoutRequest(
                id: row['id'],
                sourceDiveId: source.id,
                runtimeMin:
                    (expected.lastWhere(
                              (s) => s['kind'] == 'levelHold',
                            )['end_min']
                            as num)
                        .toDouble(),
                initialOcGas: breathing(4).gas,
                switches: switches(
                  (input['profile_codes'] as List).last['ascent_summary']
                      as List,
                ),
              ),
            )
          : calculateVpm(source);
      expect(result.segments.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        final a = result.segments[i], e = expected[i];
        expect(a.phase.name, e['kind'], reason: 'segment$i phase');
        expect(
          a.physical.startDepthMetres,
          closeTo(e['start_depth_m'] as num, 1e-10),
        );
        expect(
          a.physical.endDepthMetres,
          closeTo(e['end_depth_m'] as num, 1e-10),
        );
        expect(a.physical.durationMin, closeTo(e['duration_min'] as num, 1e-7));
        expect(a.endMin, closeTo(e['end_min'] as num, 1e-7));
        expect(
          a.physical.breathing.toJson(),
          breathing(e['gas_index'] as int).toJson(),
        );
        expectTissues(
          a.endState.tissues.toJson(),
          e['tissues'] as Map,
          'segment$i',
        );
        expectReferenceOxygen(a.endState.oxygen, e['oxygen'] as Map);
        final bubble = a.endState.vpm!.toJson(),
            expectedBubble = e['bubble'] as Map;
        for (final key in [
          'maxCrushingPressureNitrogenBar',
          'maxCrushingPressureHeliumBar',
          'adjustedInitialRadiusNitrogenMetres',
          'adjustedInitialRadiusHeliumMetres',
          'ambientOnsetBar',
          'tensionOnsetBar',
        ]) {
          final tolerance = key.endsWith('Metres') ? 1e-15 : 1e-8;
          for (var tissue = 0; tissue < 16; tissue++) {
            expect(
              (bubble[key] as List)[tissue],
              closeTo((expectedBubble[key] as List)[tissue] as num, tolerance),
              reason: 'segment$i $key tissue$tissue',
            );
          }
        }
      }
      expectVpmBubble(
        result.finalState.vpm!,
        row['expected_bubble'] as Map<String, dynamic>,
      );
      final metrics = row['metrics'] as Map;
      expect(result.runtimeMin, closeTo(metrics['runtime_min'] as num, 1e-7));
      expect(result.ascentMin, closeTo(metrics['ascent_min'] as num, 1e-7));
      expect(
        result.decompressionMin,
        closeTo(metrics['decompression_min'] as num, 1e-7),
      );
      expect(
        result.firstStopMetres,
        closeTo(row['maximum_first_stop_metres'] as num, 1e-10),
      );
      expect(
        CalculationResult.fromJson(result.toJson()).toJson(),
        result.toJson(),
      );
      expect(jsonEncode(source.toJson()), before);
    });
  }
}
