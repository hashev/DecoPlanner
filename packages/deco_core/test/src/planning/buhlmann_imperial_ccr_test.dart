import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void checkState(Segment segment, Map expected, {bool prefix = false}) {
  final tissues = segment.endState.tissues;
  for (var i = 0; i < 16; i++) {
    expect(
      tissues.nitrogenBar[i],
      closeTo(expected[prefix ? 'n2' : 'n2_bar'][i] as num, 1e-10),
    );
    expect(
      tissues.heliumBar[i],
      closeTo(expected[prefix ? 'he' : 'he_bar'][i] as num, 1e-10),
    );
  }
  expect(
    segment.endState.oxygen.cnsFraction,
    closeTo(expected['cns_fraction'] as num, 1e-10),
  );
  expect(segment.endState.oxygen.otu, closeTo(expected['otu'] as num, 1e-9));
  expect(
    segment.physical.startDepthMetres,
    closeTo(expected['start_depth_m'] as num, 1e-10),
  );
  expect(
    segment.physical.endDepthMetres,
    closeTo(expected['end_depth_m'] as num, 1e-10),
  );
  expect(
    segment.physical.durationMin,
    closeTo(expected['duration_min'] as num, 1e-10),
  );
}

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/buhlmann-imperial-ccr-bailout.json',
            ).readAsStringSync(),
          )
          as Map;
  test(
    'independent imperial B/C matrix covers CCR switches and two bailout points',
    () {
      final expected = {
        for (final letter in ['b', 'c'])
          for (final variant in [
            'ccr-no-switch',
            'ccr-switches',
            'bailout-hold',
            'bailout-end',
          ])
            'buhlmann-$letter-imperial-$variant',
      };
      final rows = (fixture['cases'] as List).cast<Map>();
      expect(rows.length, 8);
      expect(rows.map((r) => r['id']).toSet(), expected);
    },
  );
  for (final row in (fixture['cases'] as List).cast<Map>()) {
    test('independent ${row['id']} all physical segments/tissues/oxygen', () {
      final ccr = row['mode'] == 'ccr';
      final switches = [
        for (final s in row['switches'] as List)
          GasSwitch(
            depthMetres: (s[0] as num).toDouble(),
            breathing: ccr
                ? BreathingGas.ccr(
                    Gas(
                      oxygen: (s[1] as num).toDouble(),
                      helium: (s[2] as num).toDouble(),
                    ),
                    (s[3] as num).toDouble(),
                  )
                : BreathingGas.oc(
                    Gas(
                      oxygen: (s[1] as num).toDouble(),
                      helium: (s[2] as num).toDouble(),
                    ),
                  ),
          ),
      ];
      final source = DiveRequest(
        id: 'ccr-source',
        levels: [
          Level(
            depthMetres: 45,
            durationMin: 25,
            breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
          ),
        ],
        switches: ccr ? switches : const [],
        settings: CalculationSettings(
          model: row['model'] == 'B'
              ? DecompressionModel.buhlmannB
              : DecompressionModel.buhlmannC,
          pressure: PressureContext(
            surfaceBar: 1.01325,
            waterVapourBar: .0627,
            barPerMetre: .1,
          ),
          stopGrid: StopGrid.imperial(),
          gradientFactors: GradientFactors(low: .3, high: .85),
        ),
      );
      final saved = jsonEncode(source.toJson());
      final point = (row['runtime_point_min'] as num).toDouble();
      final result = ccr
          ? calculateBuhlmann(source)
          : calculateBuhlmannBailout(
              source,
              BailoutRequest(
                id: row['id'],
                sourceDiveId: source.id,
                runtimeMin: point,
                initialOcGas: Gas(oxygen: .21, helium: .35),
                switches: switches,
              ),
            );
      final prefix = result.segments.where((s) => s.endMin <= point).toList();
      final expectedPrefix = (row['prefix'] as List).cast<Map>();
      expect(prefix.length, expectedPrefix.length);
      for (var i = 0; i < prefix.length; i++) {
        checkState(prefix[i], expectedPrefix[i], prefix: true);
        expect(prefix[i].physical.breathing.mode, BreathingMode.ccr);
      }
      final suffix = result.segments.where((s) => s.startMin >= point).toList();
      final expected = row['expected'] as Map;
      final segments = (expected['segments'] as List).cast<Map>();
      expect(suffix.length, segments.length);
      for (var i = 0; i < suffix.length; i++) {
        final s = suffix[i], e = segments[i];
        checkState(s, e);
        expect(s.phase.name, e['phase']);
        expect(s.startMin, closeTo(e['start_min'] as num, 1e-10));
        expect(s.physical.breathing.gas.oxygen, e['o2']);
        expect(s.physical.breathing.gas.helium, e['he']);
        expect(s.physical.breathing.setpointBar, e['setpoint_bar']);
        expect(
          s.physical.breathing.mode,
          ccr ? BreathingMode.ccr : BreathingMode.oc,
        );
      }
      expect(
        result.firstStopMetres,
        closeTo(expected['first_stop_m'] as num, 1e-10),
      );
      expect(result.runtimeMin, closeTo(expected['runtime_min'] as num, 1e-10));
      expect(
        CalculationResult.fromJson(result.toJson()).toJson(),
        result.toJson(),
      );
      expect(jsonEncode(source.toJson()), saved);
    });
  }
}
