import 'dart:convert';
import 'dart:io';

import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/vpm_matchers.dart';

DiveRequest sourceFor(Map<String, dynamic> row) => DiveRequest(
  id: 'ccr-source',
  levels: [
    Level(
      depthMetres: 45,
      durationMin: 25,
      breathing: BreathingGas.ccr(
        Gas(oxygen: .21, helium: .35),
        row['no_switches'] == true ? .7 : 1.3,
      ),
    ),
  ],
  switches: row['mode'] == 'ccr' && row['no_switches'] != true
      ? [
          GasSwitch(
            depthMetres: 21,
            breathing: BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.4),
          ),
          GasSwitch(
            depthMetres: 6,
            breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), .7),
          ),
        ]
      : const [],
  settings: CalculationSettings(
    model: DecompressionModel.vpmB,
    pressure: PressureContext(
      surfaceBar: 1.01325,
      waterVapourBar: .0493,
      barPerMetre: .1,
    ),
    stopGrid: StopGrid.metric(),
    gradientFactors: GradientFactors(low: .3, high: .85),
    vpmConservatism: row['conservatism'] as int,
  ),
);

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-ccr-bailout-normalized.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(
      'independent full ${row['id']} with diluent and setpoint switches',
      () {
        final source = sourceFor(row);
        final original = calculateVpm(source);
        final before = jsonEncode(original.toJson());
        final result = row['mode'] == 'ccr'
            ? original
            : calculateVpmBailout(
                source,
                BailoutRequest(
                  id: row['id'] as String,
                  sourceDiveId: source.id,
                  runtimeMin: (row['runtime_point_min'] as num).toDouble(),
                  initialOcGas: Gas(oxygen: .21, helium: .35),
                  switches: [
                    GasSwitch(
                      depthMetres: 21,
                      breathing: BreathingGas.oc(Gas(oxygen: .5)),
                    ),
                    GasSwitch(
                      depthMetres: 6,
                      breathing: BreathingGas.oc(Gas(oxygen: 1)),
                    ),
                  ],
                ),
              );
        expectVpmProfile(result, row);
        expect(jsonEncode(original.toJson()), before);
        expect(jsonEncode(calculateVpm(source).toJson()), before);
      },
    );
  }
  test('VPM CCR and escape are independent of request order', () {
    final rows = (fixture['cases'] as List).cast<Map<String, dynamic>>();
    final request = sourceFor(rows.first);
    final branch = BailoutRequest(
      id: 'escape',
      sourceDiveId: request.id,
      runtimeMin: 12.5,
      initialOcGas: Gas(oxygen: .21, helium: .35),
    );
    final expected = calculateVpmBailout(request, branch).toJson();
    for (final row in rows.reversed.take(6)) {
      calculateVpm(sourceFor(row));
    }
    expect(calculateVpmBailout(request, branch).toJson(), expected);
  });
  test('VPM escape inside ascent and stop carries prefix bubble history', () {
    final row = (fixture['cases'] as List).cast<Map<String, dynamic>>().first;
    final request = sourceFor(row);
    final original = calculateVpm(request);
    for (final phase in [SegmentPhase.ascent, SegmentPhase.decompression]) {
      final segment = original.segments.firstWhere((s) => s.phase == phase);
      final point = segment.startMin + segment.physical.durationMin / 2;
      final result = calculateVpmBailout(
        request,
        BailoutRequest(
          id: 'escape',
          sourceDiveId: request.id,
          runtimeMin: point,
          initialOcGas: Gas(oxygen: .21, helium: .35),
        ),
      );
      final prefix = result.segments.lastWhere((s) => s.endMin <= point);
      expect(prefix.endMin, point);
      expect(prefix.physical.breathing.mode, BreathingMode.ccr);
      expect(
        result.segments
            .firstWhere((s) => s.startMin == point)
            .physical
            .breathing
            .mode,
        BreathingMode.oc,
      );
      expect(
        prefix.endState.vpm!.maxCrushingPressureNitrogenBar,
        segment.endState.vpm!.maxCrushingPressureNitrogenBar,
      );
      expect(
        prefix.endState.vpm!.adjustedInitialRadiusNitrogenMetres,
        original.initialState.vpm!.adjustedInitialRadiusNitrogenMetres,
      );
      expect(result.segments.last.physical.endDepthMetres, 0);
      expect(result.finalState.vpm!.criticalVolumeIterations, greaterThan(0));
    }
  });
  test('VPM escape rejects invalid source and shares cancellation budget', () {
    final row = (fixture['cases'] as List).cast<Map<String, dynamic>>().first;
    final request = sourceFor(row);
    BailoutRequest branch(String sourceId, double point) => BailoutRequest(
      id: 'escape',
      sourceDiveId: sourceId,
      runtimeMin: point,
      initialOcGas: Gas(oxygen: .21, helium: .35),
    );
    for (final b in [
      branch('missing', 10),
      branch(request.id, 0),
      branch(request.id, 10000),
    ]) {
      expect(
        () => calculateVpmBailout(request, b),
        throwsA(isA<CalculationFailure>()),
      );
    }
    expect(
      () => calculateVpmBailout(
        request,
        branch(request.id, 10),
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
  });
}
