import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/continuous-highs.json',
            ).readAsStringSync(),
          )
          as Map;
  final tolerance = (fixture['normalized_amount_tolerance'] as num).toDouble();
  for (final row in fixture['cases'] as List) {
    test('independent HiGHS ${row['id']}', () {
      final req = row['request'] as Map, expected = row['expected'] as Map;
      Gas gas(List values) => Gas(
        oxygen: (values[0] as num).toDouble(),
        helium: (values[1] as num).toDouble(),
      );
      final eos = GasEquationOfState(realGas: req['real'] as bool);
      final initial = gas(req['initial'] as List),
          target = gas(req['target'] as List);
      final caps = req['limits'] as List;
      ContinuousRecipe calculate() => continuousMix(
        initialGas: initial,
        initialBar: (req['initial_bar'] as num).toDouble(),
        targetGas: target,
        targetBar: (req['target_bar'] as num).toDouble(),
        eos: eos,
        variant: ContinuousVariant.values.byName(req['variant'] as String),
        path: ContinuousPath.values.byName(req['path'] as String),
        maximumOxygenFraction: (caps[0] as num).toDouble(),
        maximumHeliumFraction: (caps[1] as num).toDouble(),
      );
      if (expected['failure'] != null) {
        expect(
          calculate,
          throwsA(
            isA<CalculationFailure>().having(
              (e) => e.code,
              'code',
              CalculationFailureCode.impossibleMixture,
            ),
          ),
        );
        return;
      }
      final result = calculate(), total = result.targetMolesPerLitre;
      expect(
        total,
        closeTo((expected['target_moles_per_litre'] as num).toDouble(), 1e-8),
      );
      expect(
        result.retainedMolesPerLitre / total,
        closeTo((expected['retained'] as num).toDouble(), tolerance),
      );
      double prefill(ContinuousStepKind kind) =>
          result.steps
              .where((s) => s.kind == kind)
              .fold(0.0, (sum, s) => sum + s.addedMolesPerLitre) /
          total;
      expect(
        prefill(ContinuousStepKind.oxygen),
        closeTo((expected['prefill_oxygen'] as num).toDouble(), tolerance),
      );
      expect(
        prefill(ContinuousStepKind.helium),
        closeTo((expected['prefill_helium'] as num).toDouble(), tolerance),
      );
      final blends = result.steps
          .where(
            (s) =>
                s.kind == ContinuousStepKind.blend &&
                s.addedMolesPerLitre / total > 1e-9,
          )
          .toList();
      final streams = expected['streams'] as List;
      expect(blends.length, streams.length);
      for (var i = 0; i < blends.length; i++) {
        final actual = blends[i], ref = streams[i] as Map;
        expect(
          actual.addedMolesPerLitre / total,
          closeTo((ref['amount'] as num).toDouble(), tolerance),
        );
        expect(
          actual.feedGas.oxygen,
          closeTo((ref['oxygen'] as num).toDouble(), tolerance),
        );
        expect(
          actual.feedGas.helium,
          closeTo((ref['helium'] as num).toDouble(), tolerance),
        );
        expect(
          actual.feedGas.oxygen,
          lessThanOrEqualTo((caps[0] as num).toDouble() + 2e-11),
        );
        expect(
          actual.feedGas.helium,
          lessThanOrEqualTo((caps[1] as num).toDouble() + 2e-11),
        );
        final sources = ref['source_fractions'] as Map;
        expect(
          actual.airFraction,
          closeTo((sources['air'] as num).toDouble(), tolerance),
        );
        expect(
          actual.oxygenFraction,
          closeTo((sources['oxygen'] as num).toDouble(), tolerance),
        );
        expect(
          actual.heliumFraction,
          closeTo((sources['helium'] as num).toDouble(), tolerance),
        );
      }
      var retained = result.retainedMolesPerLitre;
      var oxygen = retained * initial.oxygen,
          helium = retained * initial.helium;
      var nitrogen = retained * initial.nitrogen;
      for (final step in result.steps) {
        expect(step.addedMolesPerLitre, greaterThan(0));
        retained += step.addedMolesPerLitre;
        oxygen += step.addedMolesPerLitre * step.feedGas.oxygen;
        helium += step.addedMolesPerLitre * step.feedGas.helium;
        nitrogen += step.addedMolesPerLitre * step.feedGas.nitrogen;
        expect(step.resultingGas.oxygen, closeTo(oxygen / retained, 2e-11));
        expect(step.resultingGas.helium, closeTo(helium / retained, 2e-11));
      }
      expect(retained, closeTo(total, 2e-10));
      expect(oxygen / total, closeTo(target.oxygen, 2e-11));
      expect(helium / total, closeTo(target.helium, 2e-11));
      expect(nitrogen / total, closeTo(target.nitrogen, 2e-11));
      if (result.steps.isNotEmpty) {
        expect(
          result.steps.last.pressureAfterBar,
          closeTo((req['target_bar'] as num).toDouble(), 1e-7),
        );
      }
      expect(
        result.retainedPressureBar,
        lessThanOrEqualTo((req['initial_bar'] as num).toDouble() + 1e-7),
      );
      expect(result.drainedPressureBar, greaterThanOrEqualTo(0));
    });
  }

  test(
    'normal original variant1 remains a separately labelled float control',
    () {
      final raw =
          jsonDecode(
                File(
                  'test/fixtures/legacy_baseline/continuous-control.json',
                ).readAsStringSync(),
              )
              as Map;
      final expected = raw['expected'] as Map;
      final eos = GasEquationOfState();
      final result = continuousMix(
        initialGas: Gas(oxygen: .21),
        initialBar: 0,
        targetGas: Gas(oxygen: .21, helium: .35),
        targetBar: 232,
        eos: eos,
        variant: ContinuousVariant.twoStreams,
      );
      expect(result.steps.length, 2);
      for (var i = 0; i < 2; i++) {
        final prefix = i == 0 ? 'first' : 'second';
        expect(
          result.steps[i].addedMolesPerLitre * eos.rt,
          closeTo(
            (expected['${prefix}_stream_pressure_bar'] as num).toDouble(),
            (raw['pressure_tolerance_bar'] as num).toDouble(),
          ),
        );
        expect(
          result.steps[i].feedGas.oxygen,
          closeTo(
            (expected['${prefix}_stream_oxygen'] as num).toDouble(),
            (raw['fraction_tolerance'] as num).toDouble(),
          ),
        );
      }
    },
  );

  test(
    'zero/one boundaries and request order do not leak state; cancellation is typed',
    () {
      final eos = GasEquationOfState();
      ContinuousRecipe calculate(double cap) => continuousMix(
        initialGas: Gas(oxygen: 0, helium: 1),
        initialBar: 120,
        targetGas: Gas(oxygen: .21, helium: .35),
        targetBar: 200,
        eos: eos,
        maximumOxygenFraction: cap,
        maximumHeliumFraction: .9,
      );
      final below = calculate(.21 - 1e-9),
          exact = calculate(.21),
          above = calculate(.21 + 1e-9);
      expect(
        below.retainedPressureBar,
        closeTo(exact.retainedPressureBar, 1e-5),
      );
      expect(
        above.retainedPressureBar,
        closeTo(exact.retainedPressureBar, 1e-5),
      );
      expect(calculate(.21).retainedPressureBar, exact.retainedPressureBar);
      expect(
        () => continuousMix(
          initialGas: Gas(oxygen: .21),
          initialBar: 0,
          targetGas: Gas(oxygen: .32),
          targetBar: 200,
          eos: eos,
          budget: CalculationBudget(isCancelled: () => true),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (e) => e.code,
            'code',
            CalculationFailureCode.cancelled,
          ),
        ),
      );
    },
  );

  test('invalid limits, pressures and budgets return typed failures', () {
    final gas = Gas(oxygen: .21), eos = GasEquationOfState();
    for (final limit in [-1.0, 1.1, double.nan, double.infinity]) {
      expect(
        () => continuousMix(
          initialGas: gas,
          initialBar: 0,
          targetGas: gas,
          targetBar: 200,
          eos: eos,
          maximumOxygenFraction: limit,
        ),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => continuousMix(
          initialGas: gas,
          initialBar: 0,
          targetGas: gas,
          targetBar: 200,
          eos: eos,
          maximumHeliumFraction: limit,
        ),
        throwsA(isA<CalculationFailure>()),
      );
    }
    expect(
      () => continuousMix(
        initialGas: gas,
        initialBar: 0,
        targetGas: gas,
        targetBar: 0,
        eos: eos,
      ),
      throwsA(isA<CalculationFailure>()),
    );
    expect(
      () => continuousMix(
        initialGas: gas,
        initialBar: 0,
        targetGas: gas,
        targetBar: 200,
        eos: eos,
        budget: CalculationBudget(maxIterations: 1),
      ),
      throwsA(
        isA<CalculationFailure>().having(
          (e) => e.code,
          'code',
          CalculationFailureCode.budgetExceeded,
        ),
      ),
    );
  });
}
