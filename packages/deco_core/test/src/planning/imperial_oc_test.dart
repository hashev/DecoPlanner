import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  for (final model in ['b', 'c']) {
    test('imperial$model original native physics normalized explicitly', () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/legacy_baseline/imperial-$model-oc.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source = fixture['request'] as Map<String, dynamic>;
      final context = fixture['normalization'] as Map<String, dynamic>;
      double value(String key) => (context[key] as num).toDouble();
      final request = DiveRequest(
        id: 'imperial$model',
        levels: (source['levels'] as List).cast<List>().map(
          (l) => Level(
            depthMetres: Units.feetToMetres((l[0] as num).toDouble()),
            durationMin: (l[1] as num).toDouble(),
            breathing: BreathingGas.oc(
              Gas(oxygen: (l[2] as num) / 100, helium: (l[3] as num) / 100),
            ),
          ),
        ),
        switches: (source['deco'] as List).cast<List>().map(
          (l) => GasSwitch(
            depthMetres: Units.feetToMetres((l[0] as num).toDouble()),
            breathing: BreathingGas.oc(
              Gas(oxygen: (l[1] as num) / 100, helium: (l[2] as num) / 100),
            ),
          ),
        ),
        initialState: CalculationState(
          oxygen: OxygenState(),
          tissues: TissueState.equilibrium(
            inspiredNitrogenBar: value('initial_n2_bar'),
          ),
        ),
        settings: CalculationSettings(
          model: model == 'b'
              ? DecompressionModel.buhlmannB
              : DecompressionModel.buhlmannC,
          pressure: PressureContext(
            surfaceBar: value('surface_bar'),
            waterVapourBar: value('water_vapour_bar'),
            barPerMetre: value('bar_per_metre'),
          ),
          stopGrid: StopGrid(
            stepMetres: value('step_m'),
            lastStopMetres: value('step_m'),
          ),
          gradientFactors: GradientFactors(
            low: value('gf_low'),
            high: value('gf_high'),
          ),
          descentMetresPerMin: value('descent_m_min'),
          ascentMetresPerMin: value('ascent_m_min'),
        ),
      );
      final result = calculateBuhlmann(request);
      expect(result.finalState.oxygen.cnsFraction, isNull);
      expect(
        result.finalState.oxygen.cnsUnavailableReason?.code,
        CalculationFailureCode.outsideModelDomain,
      );
      expect(result.finalState.oxygen.otu, greaterThan(0));
      final expected =
          (fixture['observed'] as List).first as Map<String, dynamic>;
      final rows = expected['segments'] as List;
      expect(result.segments.length, rows.length);
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index] as Map<String, dynamic>;
        final actual = result.segments[index];
        expect(
          actual.physical.startDepthMetres,
          closeTo(row['start_depth_m'] as num, 1e-10),
        );
        expect(
          actual.physical.endDepthMetres,
          closeTo(row['end_depth_m'] as num, 1e-10),
        );
        expect(
          actual.physical.durationMin,
          closeTo(row['duration_min'] as num, 1e-10),
        );
        expect(
          actual.physical.breathing.gas.oxygen,
          closeTo(row['o2_fraction'] as num, 1e-14),
        );
      }
      final tissues = expected['final_tissues_bar'] as Map<String, dynamic>;
      for (var index = 0; index < 16; index++) {
        expect(
          result.finalTissues.nitrogenBar[index],
          closeTo((tissues['n2'] as List)[index] as num, 1e-10),
        );
        expect(
          result.finalTissues.heliumBar[index],
          closeTo((tissues['he'] as List)[index] as num, 1e-10),
        );
      }
    });
  }
}
