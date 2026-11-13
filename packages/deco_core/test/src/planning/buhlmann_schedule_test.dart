import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

CalculationSettings settings({
  DecompressionModel model = DecompressionModel.buhlmannB,
}) => CalculationSettings(
  model: model,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
);
void main() {
  final gas = BreathingGas.oc(Gas(oxygen: .21));
  test(
    '30m20min air reproduces every legacy raw segment and all final tissues',
    () {
      final request = DiveRequest(
        id: 'air',
        levels: [Level(depthMetres: 30, durationMin: 20, breathing: gas)],
        settings: settings(),
      );
      final result = calculateBuhlmann(request);
      final data =
          jsonDecode(
                File(
                  'test/fixtures/legacy_baseline/oc-air-30m-20min.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final observed = (data['observed'] as List).first as Map<String, dynamic>;
      final expectedSegments = observed['segments'] as List;
      expect(result.segments.length, expectedSegments.length);
      for (var i = 0; i < expectedSegments.length; i++) {
        final expected = expectedSegments[i] as Map<String, dynamic>;
        final actual = result.segments[i];
        expect(actual.physical.startDepthMetres, expected['start_depth_m']);
        expect(actual.physical.endDepthMetres, expected['end_depth_m']);
        expect(
          actual.physical.durationMin,
          closeTo(expected['duration_min'] as num, 1e-12),
        );
        expect(actual.startMin, closeTo(expected['start_min'] as num, 1e-12));
        expect(actual.endMin, closeTo(expected['end_min'] as num, 1e-12));
      }
      final expectedTissues =
          observed['final_tissues_bar'] as Map<String, dynamic>;
      for (var i = 0; i < 16; i++) {
        expect(
          result.finalTissues.nitrogenBar[i],
          closeTo((expectedTissues['n2'] as List)[i] as num, 1e-12),
        );
        expect(
          result.finalTissues.heliumBar[i],
          closeTo((expectedTissues['he'] as List)[i] as num, 1e-12),
        );
      }
      expect(result.runtimeMin, closeTo(27.333333333333332, 1e-12));
      expect(result.runtimeDisplayMin, 28);
      final oxygenFixture =
          jsonDecode(
                File(
                  'test/fixtures/independent/oc-oxygen-replay.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final oxygen = (oxygenFixture['cases'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'oc-air-30m-20min');
      expect(
        result.finalState.oxygen.cnsFraction,
        closeTo(double.parse(oxygen['cns_fraction'] as String), 1e-12),
      );
      expect(
        result.finalState.oxygen.otu,
        closeTo(double.parse(oxygen['otu'] as String), 1e-10),
      );
      // The original value remains history of its movement band equality defect.
      expect(observed['cns_fraction'], 0.050839995582775674);
      expect(result.ascentMin, closeTo(observed['ascent_min'] as num, 1e-12));
      expect(
        result.decompressionMin,
        closeTo(observed['deco_min'] as num, 1e-12),
      );
    },
  );
  test(
    'shallow no-decompression dive has a direct ascent and no dummy stop',
    () {
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'shallow',
          levels: [Level(depthMetres: 6, durationMin: 10, breathing: gas)],
          settings: settings(),
        ),
      );
      expect(
        result.segments.where((s) => s.phase == SegmentPhase.decompression),
        isEmpty,
      );
      expect(result.runtimeMin, closeTo(10 + 6 / 9, 1e-12));
      expect(result.finalTissues.heliumBar, everyElement(0));
    },
  );
  test('request survives JSON and numeric input actually changes schedule', () {
    final request = DiveRequest(
      id: 'roundtrip',
      levels: [Level(depthMetres: 30, durationMin: 20, breathing: gas)],
      switches: [
        GasSwitch(
          depthMetres: 6,
          breathing: BreathingGas.oc(Gas(oxygen: 1)),
          lost: true,
        ),
      ],
      settings: settings(),
    );
    final copy = DiveRequest.fromJson(
      (jsonDecode(jsonEncode(request.toJson())) as Map).cast<String, Object?>(),
    );
    expect(copy.toJson(), request.toJson());
    final base = calculateBuhlmann(request);
    final deeper = calculateBuhlmann(
      DiveRequest(
        id: 'deeper',
        levels: [Level(depthMetres: 40, durationMin: 30, breathing: gas)],
        settings: settings(),
      ),
    );
    expect(deeper.runtimeMin, greaterThan(base.runtimeMin));
    expect(
      base.segments.every((s) => s.physical.breathing.gas.oxygen == .21),
      isTrue,
    );
  });
  test(
    'altitude pressure is used throughout schedule and retained in JSON',
    () {
      final base = settings();
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'altitude',
          levels: [Level(depthMetres: 30, durationMin: 20, breathing: gas)],
          settings: CalculationSettings(
            model: base.model,
            pressure: base.pressure,
            stopGrid: base.stopGrid,
            gradientFactors: base.gradientFactors,
            altitude: AltitudeSettings(enabled: true, diveAltitudeMetres: 2000),
          ),
        ),
      );
      final surface = barometricPressureBar(2000);
      expect(result.pressure.surfaceBar, surface);
      expect(
        result.initialState.tissues.nitrogenBar,
        everyElement(
          closeTo((surface - base.pressure.waterVapourBar) * .79, 1e-14),
        ),
      );
      final copy = CalculationResult.fromJson(
        (jsonDecode(jsonEncode(result.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copy.toJson(), result.toJson());
      expect(result.runtimeMin, greaterThan(0));
    },
  );
  test(
    'short fractional stop increments never propagate negative duration',
    () {
      final base = settings();
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'short-stop',
          levels: [Level(depthMetres: 30, durationMin: 20, breathing: gas)],
          settings: CalculationSettings(
            model: base.model,
            pressure: base.pressure,
            stopGrid: base.stopGrid,
            gradientFactors: base.gradientFactors,
            minimumStopMin: .1,
          ),
        ),
      );
      expect(result.stops, isNotEmpty);
      expect(
        result.segments.map((s) => s.physical.durationMin),
        everyElement(greaterThan(0)),
      );
    },
  );
  test(
    'unknown CNS survives repetitive schedule without losing decompression or OTU',
    () {
      const reason = CalculationFailure(
        CalculationFailureCode.outsideModelDomain,
        'Prior exposure exceeded CNS model limit1.6ATA.',
      );
      final initial = CalculationState(
        tissues: TissueState.equilibrium(inspiredNitrogenBar: .75),
        oxygen: OxygenState.unavailable(reason: reason, otu: 100),
      );
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'repeat-unknown-cns',
          levels: [Level(depthMetres: 30, durationMin: 20, breathing: gas)],
          settings: settings(),
          initialState: initial,
          surfaceIntervalMin: 60,
        ),
      );
      expect(result.runtimeMin, greaterThan(20));
      expect(result.finalState.oxygen.cnsFraction, isNull);
      expect(result.finalState.oxygen.cnsUnavailableReason, same(reason));
      expect(result.finalState.oxygen.otu, greaterThan(100));
    },
  );
}
