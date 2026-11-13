import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

final n2Half = <double>[
  5.0,
  8,
  12.5,
  18.5,
  27,
  38.3,
  54.3,
  77,
  109,
  146,
  187,
  239,
  305,
  390,
  498,
  635,
];
final heHalf = <double>[
  1.88,
  3.02,
  4.72,
  6.99,
  10.21,
  14.48,
  20.53,
  29.11,
  41.2,
  55.19,
  70.69,
  90.34,
  115.29,
  147.42,
  188.24,
  240.03,
];
void main() {
  final kinetics = TissueKinetics(
    nitrogenHalfTimesMin: n2Half,
    heliumHalfTimesMin: heHalf,
  );
  final context = PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  );
  final air = BreathingGas.oc(Gas(oxygen: .21));
  final initial = TissueState.equilibrium(inspiredNitrogenBar: .7509345);
  test('Haldane reaches midpoint at one half time in all16 tissues', () {
    for (var i = 0; i < 16; i++) {
      expect(
        haldane(
          initial: 1,
          inspired: 3,
          durationMin: n2Half[i],
          rateConstant: math.ln2 / n2Half[i],
        ),
        closeTo(2, 1e-14),
      );
    }
  });
  test('surface equilibrium and zero time preserve all tissues', () {
    final state = kinetics.propagate(
      initial: initial,
      pressure: context,
      breathing: air,
      startDepthMetres: 0,
      endDepthMetres: 0,
      durationMin: 1000,
    );
    expect(state.nitrogenBar, everyElement(closeTo(.7509345, 1e-14)));
    expect(state.heliumBar, everyElement(0));
    expect(
      identical(
        kinetics.propagate(
          initial: initial,
          pressure: context,
          breathing: air,
          startDepthMetres: 0,
          endDepthMetres: 0,
          durationMin: 0,
        ),
        initial,
      ),
      isTrue,
    );
  });
  test(
    'linear pressure matches analytical Schreiner across16 compartments',
    () {
      final state = kinetics.propagate(
        initial: initial,
        pressure: context,
        breathing: air,
        startDepthMetres: 0,
        endDepthMetres: 30,
        durationMin: 3,
      );
      for (var i = 0; i < 16; i++) {
        final k = math.ln2 / n2Half[i];
        final pi0 = .7509345;
        final r = .79;
        final expected =
            pi0 +
            r * (3 - 1 / k) -
            (pi0 - initial.nitrogenBar[i] - r / k) * math.exp(-k * 3);
        expect(state.nitrogenBar[i], closeTo(expected, 1e-13));
      }
    },
  );
  test('CCR hold agrees with untouched independent Subsurface calculation', () {
    for (final model in ['buhlmann', 'vpmb']) {
      final data =
          jsonDecode(
                File(
                  'test/fixtures/independent/subsurface-$model-ccr-hold.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final request = data['request'] as Map<String, dynamic>;
      final vapour = (request['water_vapour_bar'] as num).toDouble();
      final pressure = PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: vapour,
        barPerMetre: .1,
      );
      final state = kinetics.propagate(
        initial: TissueState.equilibrium(
          inspiredNitrogenBar: (1.01325 - vapour) * .781,
        ),
        pressure: pressure,
        breathing: BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.3),
        startDepthMetres: 50,
        endDepthMetres: 50,
        durationMin: 20,
      );
      final expected = data['expected'] as Map<String, dynamic>;
      // Upstream factor() uses rounded ln(2)/60 = .01155245301.
      // Bound its pressure error analytically: |deltaP|*t*|deltaK|.
      // The bound depends on source constants and inputs, never actual output.
      final deltaLn2 = (60 * .01155245301 - math.ln2).abs();
      final inert = 6.01325 - vapour - 1.3;
      final n2Inspired = inert * .37 / .82;
      final heInspired = inert * .45 / .82;
      for (var i = 0; i < 16; i++) {
        final n2Bound =
            (n2Inspired - (1.01325 - vapour) * .781).abs() *
                20 *
                deltaLn2 /
                n2Half[i] +
            1e-14;
        final heBound = heInspired * 20 * deltaLn2 / heHalf[i] + 1e-14;
        expect(
          state.nitrogenBar[i],
          closeTo((expected['n2'] as List)[i] as num, n2Bound),
        );
        expect(
          state.heliumBar[i],
          closeTo((expected['he'] as List)[i] as num, heBound),
        );
      }
    }
  });
  test('movement composition and bailout do not mutate source state', () {
    final ccr = BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.3);
    final direct = kinetics.propagate(
      initial: initial,
      pressure: context,
      breathing: ccr,
      startDepthMetres: 0,
      endDepthMetres: 30,
      durationMin: 3,
    );
    final first = kinetics.propagate(
      initial: initial,
      pressure: context,
      breathing: ccr,
      startDepthMetres: 0,
      endDepthMetres: 10,
      durationMin: 1,
    );
    final split = kinetics.propagate(
      initial: first,
      pressure: context,
      breathing: ccr,
      startDepthMetres: 10,
      endDepthMetres: 30,
      durationMin: 2,
    );
    for (var i = 0; i < 16; i++) {
      expect(split.nitrogenBar[i], closeTo(direct.nitrogenBar[i], 1e-13));
      expect(split.heliumBar[i], closeTo(direct.heliumBar[i], 1e-13));
    }
    final snapshot = jsonEncode(direct.toJson());
    kinetics.propagate(
      initial: direct,
      pressure: context,
      breathing: air,
      startDepthMetres: 30,
      endDepthMetres: 20,
      durationMin: 1,
    );
    expect(jsonEncode(direct.toJson()), snapshot);
    expect(() => direct.nitrogenBar[0] = 0, throwsUnsupportedError);
  });
  test('very short segments stay finite, positive and approach identity', () {
    final value = schreiner(
      initial: 1,
      inspiredStart: 2,
      inspiredRate: 1,
      durationMin: 1e-12,
      rateConstant: .1,
    );
    expect(value, closeTo(1, 1e-12));
    expect(value, greaterThanOrEqualTo(1));
  });
  test('invalid state and instantaneous movement fail', () {
    expect(
      () => TissueState(nitrogenBar: [1], heliumBar: List.filled(16, 0)),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => kinetics.propagate(
        initial: initial,
        pressure: context,
        breathing: air,
        startDepthMetres: 0,
        endDepthMetres: 30,
        durationMin: 0,
      ),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => Gas(oxygen: .6, helium: .5),
      throwsA(isA<CalculationFailure>()),
    );
  });
  test(
    'Haldane preserves tiny positive washout without subtractive cancellation',
    () {
      final value = haldane(
        initial: 1,
        inspired: 0,
        durationMin: 100,
        rateConstant: math.ln2,
      );
      expect(value, greaterThan(0));
      expect(value, closeTo(7.888609052210118e-31, 1e-43));
    },
  );
}
