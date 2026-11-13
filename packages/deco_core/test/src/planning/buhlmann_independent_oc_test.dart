import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/buhlmann-oc-normalized-schedules.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final row in (fixture['cases'] as List).cast<Map>()) {
    test('independent full OC stop search ${row['id']}', () {
      final source = row['request'] as Map,
          context = row['normalization'] as Map;
      double value(String key) => (context[key] as num).toDouble();
      BreathingGas gas(num o, num h) =>
          BreathingGas.oc(Gas(oxygen: o / 100, helium: h / 100));
      final switches = (source['deco'] as List?) ?? [];
      final lost = (source['lost_deco_indices'] as List?) ?? [];
      final request = DiveRequest(
        id: row['id'] as String,
        levels: [
          for (final level in (source['levels'] as List).cast<List>())
            Level(
              depthMetres: (level[0] as num) * value('depth_factor'),
              durationMin: (level[1] as num).toDouble(),
              breathing: gas(level[2] as num, level[3] as num),
            ),
        ],
        switches: [
          for (var i = 0; i < switches.length; i++)
            GasSwitch(
              depthMetres:
                  ((switches[i] as List)[0] as num) * value('depth_factor'),
              breathing: gas(
                (switches[i] as List)[1] as num,
                (switches[i] as List)[2] as num,
              ),
              lost: lost.contains(i),
              minimumStopMin: (switches[i] as List).length > 4
                  ? ((switches[i] as List)[4] as num).toDouble()
                  : null,
            ),
        ],
        initialState: CalculationState(
          tissues: TissueState.equilibrium(
            inspiredNitrogenBar: value('initial_n2_bar'),
          ),
          oxygen: OxygenState(),
        ),
        settings: CalculationSettings(
          model: source['model'] == 'b'
              ? DecompressionModel.buhlmannB
              : DecompressionModel.buhlmannC,
          pressure: PressureContext(
            surfaceBar: value('surface_bar'),
            waterVapourBar: value('vapour_bar'),
            barPerMetre: value('bar_per_metre'),
          ),
          stopGrid: StopGrid(
            stepMetres: value('step_m'),
            lastStopMetres: value('last_stop_m'),
          ),
          gradientFactors: GradientFactors(
            low: value('gf_low'),
            high: value('gf_high'),
          ),
          ascentMetresPerMin: value('ascent_m_min'),
          descentMetresPerMin: value('descent_m_min'),
          minimumStopMin: value('minimum_stop_min'),
          includeDescentInLevelTime: context['include_descent'] as bool,
        ),
      );
      final result = calculateBuhlmann(request);
      final expected = row['expected'] as Map;
      final segments = (expected['segments'] as List).cast<Map>();
      expect(result.segments.length, segments.length);
      for (var i = 0; i < segments.length; i++) {
        final actual = result.segments[i], e = segments[i];
        expect(actual.phase.name, e['phase']);
        expect(actual.physical.breathing.mode, BreathingMode.oc);
        expect(actual.physical.breathing.gas.oxygen, e['oxygen']);
        expect(actual.physical.breathing.gas.helium, e['helium']);
        expect(
          actual.physical.startDepthMetres,
          closeTo(e['start_depth_m'] as num, 1e-10),
        );
        expect(
          actual.physical.endDepthMetres,
          closeTo(e['end_depth_m'] as num, 1e-10),
        );
        expect(actual.startMin, closeTo(e['start_min'] as num, 1e-10));
        expect(
          actual.physical.durationMin,
          closeTo(e['duration_min'] as num, 1e-10),
        );
        for (var tissue = 0; tissue < 16; tissue++) {
          expect(
            actual.endState.tissues.nitrogenBar[tissue],
            closeTo((e['n2_bar'] as List)[tissue] as num, 1e-10),
            reason: 'segment$i N2 tissue$tissue',
          );
          expect(
            actual.endState.tissues.heliumBar[tissue],
            closeTo((e['he_bar'] as List)[tissue] as num, 1e-10),
            reason: 'segment$i He tissue$tissue',
          );
        }
      }
      expect(result.runtimeMin, closeTo(expected['runtime_min'] as num, 1e-10));
      expect(result.ascentMin, closeTo(expected['ascent_min'] as num, 1e-10));
      expect(
        result.decompressionMin,
        closeTo(expected['decompression_min'] as num, 1e-10),
      );
      expect(
        result.firstStopMetres,
        closeTo(expected['first_stop_m'] as num, 1e-10),
      );
      expect(result.runtimeDisplayMin, result.runtimeMin.ceil());
    });
  }
}
