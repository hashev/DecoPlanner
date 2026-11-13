import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-normalized-schedules.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    if (row['diagnostic_swapped_gradients'] == true) continue;
    test('independent full VPM ${row['id']}', () {
      final input = row['request'] as Map<String, dynamic>;
      final source = (input['input'] as List).first as Map<String, dynamic>;
      final profile = (source['profile_codes'] as List)
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
      final settings = input['settings'] as Map<String, dynamic>;
      final summary = profile.last;
      final request = DiveRequest(
        id: row['id'] as String,
        levels: [
          Level(
            depthMetres: (profile[1]['depth'] as num).toDouble(),
            durationMin: (profile[1]['run_time_at_end_of_segment'] as num)
                .toDouble(),
            breathing: gases.first,
          ),
        ],
        switches: (summary['ascent_summary'] as List)
            .skip(1)
            .where((g) => (g as Map)['step_size'] == 3)
            .cast<Map<String, dynamic>>()
            .map(
              (g) => GasSwitch(
                depthMetres: (g['starting_depth'] as num).toDouble(),
                breathing: gases[(g['gasmix'] as int) - 1],
              ),
            ),
        settings: CalculationSettings(
          model: DecompressionModel.vpmB,
          pressure: PressureContext(
            surfaceBar: ((row['normalization'] as Map)['surface_bar'] as num)
                .toDouble(),
            waterVapourBar: .0493,
            barPerMetre: .1,
          ),
          stopGrid: row['id'] == 'last-stop-double-vpm'
              ? StopGrid(stepMetres: 3, lastStopMetres: 6)
              : StopGrid.metric(),
          gradientFactors: GradientFactors(low: .3, high: .85),
          descentMetresPerMin: (profile[0]['rate'] as num).toDouble(),
          ascentMetresPerMin:
              -(((summary['ascent_summary'] as List).first as Map)['rate']
                      as num)
                  .toDouble(),
          includeDescentInLevelTime: true,
          vpmConservatism: row['conservatism'] as int,
          vpm: VpmParameters(
            criticalVolumeEnabled:
                settings['Critical_Volume_Algorithm'] == 'ON',
          ),
        ),
      );
      final result = calculateVpm(request);
      final actual = result.segments
          .where(
            (s) =>
                s.phase == SegmentPhase.ascent ||
                s.phase == SegmentPhase.decompression,
          )
          .toList();
      final expected = (row['expected_segments'] as List)
          .cast<Map<String, dynamic>>();
      expect(actual.length, expected.length);
      for (var n = 0; n < actual.length; n++) {
        final a = actual[n], e = expected[n];
        expect(a.phase.name, e['kind']);
        expect(
          a.physical.endDepthMetres,
          closeTo(e['end_depth_m'] as num, 1e-10),
          reason: 'segment$n depth',
        );
        expect(
          a.physical.durationMin,
          closeTo(e['duration_min'] as num, 1e-7),
          reason: 'segment$n time',
        );
        expect(
          a.endMin,
          closeTo(e['end_min'] as num, 1e-7),
          reason: 'segment$n runtime',
        );
        final gas = gases[e['gas_index'] as int];
        expect(a.physical.breathing.gas.oxygen, gas.gas.oxygen);
        expect(a.physical.breathing.gas.helium, gas.gas.helium);
        final tissues = e['tissues'] as Map<String, dynamic>;
        for (var i = 0; i < 16; i++) {
          expect(
            a.endState.tissues.nitrogenBar[i],
            closeTo((tissues['nitrogenBar'] as List)[i] as num, 1e-8),
            reason: 'segment$n N2 tissue$i',
          );
          expect(
            a.endState.tissues.heliumBar[i],
            closeTo((tissues['heliumBar'] as List)[i] as num, 1e-8),
            reason: 'segment$n He tissue$i',
          );
        }
      }
      final bubble = result.finalState.vpm!.toJson();
      final expectedBubble = row['expected_bubble'] as Map<String, dynamic>;
      expect(
        bubble['criticalVolumeIterations'],
        expectedBubble['criticalVolumeIterations'],
      );
      expect(
        bubble['maximumFirstStopMetres'],
        expectedBubble['maximumFirstStopMetres'],
      );
      for (final entry in bubble.entries) {
        final name = entry.key;
        final expectedValue = expectedBubble[name];
        if (entry.value is List) {
          final tolerance = name.endsWith('Metres')
              ? 1e-15
              : name.endsWith('Min')
              ? 1e-7
              : 1e-8;
          for (var i = 0; i < 16; i++) {
            expect(
              (entry.value as List)[i],
              closeTo((expectedValue as List)[i] as num, tolerance),
              reason: '$name tissue$i',
            );
          }
        } else if (name.endsWith('Tissues')) {
          final actualTissues = entry.value as Map;
          final correctTissues = expectedValue as Map;
          for (final gas in ['nitrogenBar', 'heliumBar']) {
            for (var i = 0; i < 16; i++) {
              expect(
                (actualTissues[gas] as List)[i],
                closeTo((correctTissues[gas] as List)[i] as num, 1e-8),
                reason: '$name $gas tissue$i',
              );
            }
          }
        } else if (entry.value is double) {
          expect(
            entry.value,
            closeTo(expectedValue as num, 1e-7),
            reason: name,
          );
        } else {
          expect(entry.value, expectedValue, reason: name);
        }
      }
      expect(result.finalState.oxygen.otu, greaterThanOrEqualTo(0));
      final copy = CalculationResult.fromJson(
        (jsonDecode(jsonEncode(result.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copy.toJson(), result.toJson());
    });
  }
  for (final row
      in (fixture['cases'] as List).cast<Map<String, dynamic>>().where(
        (r) => r['diagnostic_swapped_gradients'] == true,
      )) {
    test(
      'independent swapped-gradient diagnostic reproduces original ${row['baseline_id']}',
      () {
        final baseline =
            jsonDecode(
                  File(
                    'test/fixtures/legacy_baseline/${row['baseline_id']}.json',
                  ).readAsStringSync(),
                )
                as Map;
        final observed = (baseline['observed'] as List).first as Map;
        final originalRows = (observed['segments'] as List)
            .skip(2)
            .cast<Map>()
            .toList();
        final independentRows = (row['expected_segments'] as List)
            .cast<Map>()
            .toList();
        expect(originalRows.length, independentRows.length);
        for (var n = 0; n < originalRows.length; n++) {
          expect(
            independentRows[n]['duration_min'],
            closeTo(originalRows[n]['duration_min'] as num, 1e-7),
          );
          expect(
            independentRows[n]['end_depth_m'],
            originalRows[n]['end_depth_m'],
          );
        }
        final originalTissues = observed['final_tissues_bar'] as Map;
        final correct = independentRows.last['tissues'] as Map;
        for (var i = 0; i < 16; i++) {
          expect(
            (correct['nitrogenBar'] as List)[i],
            closeTo((originalTissues['n2'] as List)[i] as num, 1e-8),
          );
          expect(
            (correct['heliumBar'] as List)[i],
            closeTo((originalTissues['he'] as List)[i] as num, 1e-8),
          );
        }
      },
    );
  }
  DiveRequest request({StopGrid? grid}) => DiveRequest(
    id: 'bounded-vpm',
    levels: [
      Level(
        depthMetres: 45,
        durationMin: 25,
        breathing: BreathingGas.oc(Gas(oxygen: .21, helium: .35)),
      ),
    ],
    settings: CalculationSettings(
      model: DecompressionModel.vpmB,
      pressure: PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: .0493,
        barPerMetre: .1,
      ),
      stopGrid: grid ?? StopGrid.metric(),
      gradientFactors: GradientFactors(low: .3, high: .85),
    ),
  );
  test(
    'VPM cancellation and iteration/time limits are typed and never return a plan',
    () {
      for (final budget in [
        CalculationBudget(maxIterations: 1),
        CalculationBudget(maxElapsed: Duration.zero),
      ]) {
        expect(
          () => calculateVpm(request(), budget: budget),
          throwsA(
            isA<CalculationFailure>().having(
              (f) => f.code,
              'code',
              CalculationFailureCode.budgetExceeded,
            ),
          ),
        );
      }
      expect(
        () => calculateVpm(
          request(),
          budget: CalculationBudget(isCancelled: () => true),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.cancelled,
          ),
        ),
      );
      expect(
        () => calculateVpm(
          request(grid: StopGrid(stepMetres: 3, lastStopMetres: 100)),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.nonConvergence,
          ),
        ),
      );
    },
  );
  test(
    'mid-search cancellation and impossible off-gassing are explicit failures',
    () {
      var checks = 0;
      expect(
        () => calculateVpm(
          request(),
          budget: CalculationBudget(isCancelled: () => ++checks > 2000),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.cancelled,
          ),
        ),
      );
      expect(checks, greaterThan(2000));
      expect(
        () => calculateVpm(
          request(grid: StopGrid(stepMetres: 30, lastStopMetres: 30)),
        ),
        throwsA(
          isA<CalculationFailure>()
              .having(
                (f) => f.code,
                'code',
                CalculationFailureCode.nonConvergence,
              )
              .having((f) => f.message, 'diagnostic', contains('Off-gassing')),
        ),
      );
    },
  );
  test(
    'VPM result is independent of request order and does not change input state',
    () {
      final input = request();
      final saved = jsonEncode(input.toJson());
      final first = calculateVpm(input).toJson();
      calculateBuhlmann(
        DiveRequest(
          id: 'other-model',
          levels: input.levels,
          settings: CalculationSettings(
            model: DecompressionModel.buhlmannC,
            pressure: input.settings.pressure,
            stopGrid: StopGrid.imperial(),
            gradientFactors: GradientFactors(low: .5, high: .8),
          ),
        ),
      );
      expect(calculateVpm(input).toJson(), first);
      expect(jsonEncode(input.toJson()), saved);
    },
  );
}
