import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

CalculationSettings settings({
  DecompressionModel model = DecompressionModel.buhlmannB,
  double rmv = 20,
  double decoRmv = 15,
  double ocr = .7,
  double decoOcr = .5,
}) => CalculationSettings(
  model: model,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
  bottomRmvLitresPerMin: rmv,
  decoRmvLitresPerMin: decoRmv,
  bottomOxygenLitresPerMin: ocr,
  decoOxygenLitresPerMin: decoOcr,
);

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/gas-usage-quadrature.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final row in fixture['cases'] as List) {
    test('independent schedule quadrature ${row['id']}', () {
      final context = row['context'] as Map, expected = row['expected'] as Map;
      double c(String name) => (context[name] as num).toDouble();
      final state = CalculationState(
        tissues: TissueState.equilibrium(inspiredNitrogenBar: .79),
        oxygen: OxygenState(),
      );
      var clock = 0.0, ascent = 0.0, decompression = 0.0;
      final segments = <Segment>[];
      for (final raw in row['segments'] as List) {
        final gas = Gas(
          oxygen: (raw['oxygen'] as num).toDouble(),
          helium: (raw['helium'] as num).toDouble(),
        );
        final phase = SegmentPhase.values.byName(raw['phase'] as String);
        final duration = (raw['duration_min'] as num).toDouble();
        segments.add(
          Segment(
            physical: PropagationSegment(
              startDepthMetres: (raw['start_depth_m'] as num).toDouble(),
              endDepthMetres: (raw['end_depth_m'] as num).toDouble(),
              durationMin: duration,
              breathing: raw['mode'] == 'oc'
                  ? BreathingGas.oc(gas)
                  : BreathingGas.ccr(gas, 1.3),
            ),
            phase: phase,
            startMin: clock,
            endState: state,
          ),
        );
        clock += duration;
        if (phase == SegmentPhase.ascent ||
            phase == SegmentPhase.decompression) {
          ascent += duration;
        }
        if (phase == SegmentPhase.decompression) {
          decompression += duration;
        }
      }
      final result = CalculationResult(
        diveId: row['id'] as String,
        modelVersion: calculationModelVersion,
        initialState: state,
        pressure: PressureContext(
          surfaceBar: c('surface_bar'),
          waterVapourBar: .0627,
          barPerMetre: c('bar_per_metre'),
        ),
        segments: segments,
        firstStopMetres: 0,
        ascentMin: ascent,
        decompressionMin: decompression,
      );
      final input = CalculationSettings(
        model: DecompressionModel.buhlmannB,
        pressure: result.pressure,
        stopGrid: StopGrid(
          stepMetres: c('step_m'),
          lastStopMetres: c('last_stop_m'),
        ),
        gradientFactors: GradientFactors(low: .3, high: .85),
      );
      final report = calculateGasUsage(result, input);
      final expectedAmounts = expected['segment_litres'] as List;
      expect(report.segments.length, expectedAmounts.length);
      for (var i = 0; i < report.segments.length; i++) {
        expect(
          report.segments[i].litres,
          closeTo((expectedAmounts[i] as num).toDouble(), 1e-8),
        );
      }
      expect(
        report.totalLitres,
        closeTo((expected['total_litres'] as num).toDouble(), 1e-8),
      );
      expect(
        report.bottomMin,
        closeTo((expected['bottom_min'] as num).toDouble(), 1e-8),
      );
      final groups = expected['stop_groups'] as List;
      expect(report.stopGroups.length, groups.length);
      for (var i = 0; i < groups.length; i++) {
        final actual = report.stopGroups[i], reference = groups[i] as Map;
        expect(
          actual.durationMin,
          closeTo((reference['duration_min'] as num).toDouble(), 1e-8),
        );
        expect(actual.stopCount, reference['stop_count']);
        expect(
          actual.shallowestMetres,
          closeTo((reference['shallowest_m'] as num).toDouble(), 1e-10),
        );
        expect(
          actual.deepestMetres,
          closeTo((reference['deepest_m'] as num).toDouble(), 1e-10),
        );
      }
      expect(
        report.stopGroups.fold(0.0, (sum, g) => sum + g.durationMin),
        closeTo(decompression, 1e-8),
      );
      expect(
        report.gases.fold(0.0, (sum, g) => sum + g.litres),
        closeTo(report.totalLitres, 1e-8),
      );
      expect(
        report.segments.fold(0.0, (sum, g) => sum + g.litres),
        closeTo(report.totalLitres, 1e-8),
      );
      final zero = calculateGasUsage(
        result,
        CalculationSettings(
          model: input.model,
          pressure: input.pressure,
          stopGrid: input.stopGrid,
          gradientFactors: input.gradientFactors,
          bottomRmvLitresPerMin: 0,
          decoRmvLitresPerMin: 0,
          bottomOxygenLitresPerMin: 0,
          decoOxygenLitresPerMin: 0,
        ),
      );
      expect(zero.totalLitres, 0);
      expect(zero.gases.every((g) => g.litres == 0), isTrue);
    });
  }

  for (final model in DecompressionModel.values) {
    test(
      'real $model OC, CCR and bailout report with separate roles and exact totals',
      () {
        final input = settings(model: model);
        DiveRequest request(BreathingMode mode) => DiveRequest(
          id: 'source',
          settings: input,
          levels: [
            Level(
              depthMetres: 45,
              durationMin: 25,
              breathing: mode == BreathingMode.oc
                  ? BreathingGas.oc(Gas(oxygen: .21, helium: .35))
                  : BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
          ],
        );
        CalculationResult calculate(DiveRequest request) =>
            model == DecompressionModel.vpmB
            ? calculateVpm(request)
            : calculateBuhlmann(request);
        final oc = calculate(request(BreathingMode.oc));
        final ocUse = calculateGasUsage(oc, input);
        expect(ocUse.hasCcr, isFalse);
        expect(ocUse.gases.single.kind, GasUseKind.openCircuit);
        final ccrRequest = request(BreathingMode.ccr),
            ccr = calculate(ccrRequest);
        final ccrUse = calculateGasUsage(ccr, input);
        expect(ccrUse.gases.single.kind, GasUseKind.ccrOxygen);
        expect(
          ccrUse.totalLitres,
          closeTo(25 * .7 + (ccr.runtimeMin - 25) * .5, 1e-10),
        );
        final branch = BailoutRequest(
          id: 'escape',
          sourceDiveId: 'source',
          runtimeMin: 25,
          initialOcGas: Gas(oxygen: 1),
        );
        final escape = model == DecompressionModel.vpmB
            ? calculateVpmBailout(ccrRequest, branch)
            : calculateBuhlmannBailout(ccrRequest, branch);
        final usage = calculateGasUsage(escape, input);
        expect(usage.gases.length, 2);
        expect(usage.gases.map((g) => g.kind).toSet(), {
          GasUseKind.ccrOxygen,
          GasUseKind.openCircuit,
        });
        expect(usage.gases.first.litres, closeTo(25 * .7, 1e-10));
        expect(usage.gases.last.litres, greaterThan(0));
      },
    );
  }

  test(
    'CCR entered ascent is counted once, zero ratios and rounded underestimation are explicit',
    () {
      final input = settings();
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'multilevel',
          settings: input,
          levels: [
            Level(
              depthMetres: 45,
              durationMin: 25,
              breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
            Level(
              depthMetres: 30,
              durationMin: 10,
              breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
          ],
        ),
      );
      final usage = calculateGasUsage(result, input);
      // The entered 30m hold is padded to the next runtime minute after
      // the 15m ascent at 9m/min. Travel itself uses the ascent OCR.
      const enteredMin = 35 + 1 / 3;
      expect(usage.bottomMin, closeTo(enteredMin, 1e-12));
      expect(
        usage.totalLitres,
        closeTo(enteredMin * .7 + (result.runtimeMin - enteredMin) * .5, 1e-10),
      );
      expect(TimeRatio(bottomMin: 0, comparedMin: 0).exact, isNull);
      expect(
        TimeRatio(bottomMin: 0, comparedMin: 1).roundedComparedUnits,
        isNull,
      );
      expect(TimeRatio(bottomMin: 20, comparedMin: 0).roundedComparedUnits, 0);
      expect(
        TimeRatio(bottomMin: 20, comparedMin: 20.8).roundedUnderestimates,
        isTrue,
      );
      expect(
        TimeRatio(bottomMin: 20, comparedMin: 8).roundedUnderestimates,
        isTrue,
      );
      expect(
        TimeRatio(bottomMin: 20, comparedMin: 20).roundedUnderestimates,
        isFalse,
      );
      expect(
        () => calculateGasUsage(result, input, stopsPerGroup: 0),
        throwsA(isA<CalculationFailure>()),
      );
    },
  );

  test('tank estimate preserves raw pressure and rejects invalid capacity', () {
    final tank = TankRequirement(
      freeLitres: 1719,
      waterLitres: 12,
      cylinderCount: 2,
      workingBar: 232,
    );
    expect(tank.requiredBar, 71.625);
    expect(tank.requiredBar.round(), 72);
    expect(tank.exceedsWorkingPressure, isFalse);
    expect(
      TankRequirement(
        freeLitres: 0,
        waterLitres: 12,
        cylinderCount: 1,
        workingBar: 232,
      ).requiredBar,
      0,
    );
    expect(
      TankRequirement(
        freeLitres: 3000,
        waterLitres: 12,
        cylinderCount: 1,
        workingBar: 232,
      ).exceedsWorkingPressure,
      isTrue,
    );
    for (final size in [0.0, -1.0, double.infinity, double.nan]) {
      expect(
        () => TankRequirement(
          freeLitres: 0,
          waterLitres: size,
          cylinderCount: 1,
          workingBar: 232,
        ),
        throwsA(isA<CalculationFailure>()),
      );
    }
    expect(
      () => TankRequirement(
        freeLitres: 1,
        waterLitres: 1e308,
        cylinderCount: 2,
        workingBar: 232,
      ),
      throwsA(isA<CalculationFailure>()),
    );
    expect(() => settings(rmv: -1), throwsA(isA<CalculationFailure>()));
  });
}
