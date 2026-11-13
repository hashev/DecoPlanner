import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final pressure = PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  );
  test('B/C1b tables and all tissue ceilings match independent execution', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/independent/buhlmann-1b-parameters-and-ceilings.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final raw in fixture['models'] as List) {
      final data = raw as Map<String, dynamic>;
      final model = BuhlmannModel(
        (data['model'] as String).contains('16b')
            ? BuhlmannCoefficients.b()
            : BuhlmannCoefficients.c(),
      );
      final input = data['tissue_case'] as Map<String, dynamic>;
      final state = TissueState(
        nitrogenBar: (input['n2_bar'] as List).cast<num>().map(
          (x) => x.toDouble(),
        ),
        heliumBar: (input['he_bar'] as List).cast<num>().map(
          (x) => x.toDouble(),
        ),
      );
      final tables = data['tables'] as Map<String, dynamic>;
      expect(model.coefficients.n2A, tables['n2_a_bar']);
      expect(model.coefficients.n2B, tables['n2_b']);
      expect(model.coefficients.heA, tables['he_a_bar']);
      expect(model.coefficients.heB, tables['he_b']);
      expect(
        model.coefficients.kinetics.nitrogenHalfTimesMin,
        tables['n2_half'],
      );
      expect(model.coefficients.kinetics.heliumHalfTimesMin, tables['he_half']);
      final cases = data['expected_ceilings_bar'] as Map<String, dynamic>;
      for (final entry in cases.entries) {
        final expected = (entry.value as List)
            .cast<num>()
            .map((x) => x.toDouble())
            .toList();
        final actual = model.ceiling(state, double.parse(entry.key), pressure);
        for (var i = 0; i < 16; i++) {
          expect(
            actual.tissueCeilingsBar[i],
            closeTo(math.max(0, expected[i]), 1e-12),
          );
        }
        final maximum = expected.reduce(math.max);
        expect(actual.leadingTissue, expected.indexOf(maximum));
        expect(actual.absoluteBar, closeTo(maximum, 1e-12));
      }
    }
  });
  test('no inert gas yields finite zero ceiling and no leading tissue', () {
    final state = TissueState.equilibrium(inspiredNitrogenBar: 0);
    final actual = BuhlmannModel(
      BuhlmannCoefficients.b(),
    ).ceiling(state, .3, pressure);
    expect(actual.absoluteBar, 0);
    expect(actual.depthMetres, 0);
    expect(actual.leadingTissue, isNull);
    expect(actual.tissueCeilingsBar, everyElement(0));
  });
  test(
    'GF is linear in depth from first stop to surface with bounded ends',
    () {
      final gf = GradientFactors(low: .3, high: .85);
      expect(gf.atDepth(depthMetres: 12, firstStopMetres: 12), .3);
      expect(
        gf.atDepth(depthMetres: 6, firstStopMetres: 12),
        closeTo(.575, 1e-15),
      );
      expect(gf.atDepth(depthMetres: 0, firstStopMetres: 12), .85);
      expect(gf.atDepth(depthMetres: 30, firstStopMetres: 12), .3);
      expect(gf.atDepth(depthMetres: 0, firstStopMetres: 0), .85);
      for (final low in [0.0, -.1, double.nan, 1.1]) {
        expect(
          () => GradientFactors(low: low, high: .85),
          throwsA(isA<CalculationFailure>()),
        );
      }
    },
  );
  test('30m air first-stop search agrees with legacy12m and is budgeted', () {
    final coefficients = BuhlmannCoefficients.b();
    final gas = BreathingGas.oc(Gas(oxygen: .21));
    var state = TissueState.equilibrium(inspiredNitrogenBar: .7509345);
    for (final segment in prepareLevel(
      startDepthMetres: 0,
      targetDepthMetres: 30,
      levelDurationMin: 20,
      descentMetresPerMin: 10,
      ascentMetresPerMin: 9,
      includeDescentInLevelTime: true,
      movementGas: gas,
      levelGas: gas,
    )) {
      state = segment.propagate(state, coefficients.kinetics, pressure);
    }
    final model = BuhlmannModel(coefficients);
    final gf = GradientFactors(low: .3, high: .85);
    double first(CalculationBudget budget) => model.firstStop(
      state: state,
      currentDepthMetres: 30,
      ascentMetresPerMin: 9,
      breathing: gas,
      gf: gf,
      pressure: pressure,
      grid: StopGrid.metric(),
      budget: budget,
    );
    expect(first(CalculationBudget()), 12);
    expect(
      () => first(CalculationBudget(maxElapsed: Duration.zero)),
      throwsA(isA<CalculationFailure>()),
    );
  });
}
