import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-gradient-kernels.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final pressure = PressureContext(
    surfaceBar: 1,
    waterVapourBar: .0493,
    barPerMetre: .1,
  );
  for (final raw in fixture['cases'] as List) {
    final source = raw as Map<String, dynamic>;
    for (final item in source['stages'] as List) {
      final stage = item as Map<String, dynamic>;
      test('independent VPM c${source['conservatism']} ${stage['method']}', () {
        final bubble = VpmState.fromJson(
          (stage['input_bubble'] as Map).cast<String, Object?>(),
        );
        final expected = stage['expected_bubble'] as Map<String, dynamic>;
        final tissues = TissueState.fromJson(
          (stage['input_tissues'] as Map).cast<String, Object?>(),
        );
        final args = (stage['args'] as List).cast<num>();
        final model = VpmGradients(
          parameters: VpmParameters(),
          kinetics: BuhlmannCoefficients.b().kinetics,
          budget: CalculationBudget(),
        );
        VpmState actual;
        List<String> fields;
        double tolerance;
        switch (stage['method']) {
          case 'boyles_law_compensation':
            actual = model.boyleCompensation(
              bubble.copyWith(maximumFirstStopMetres: args[0].toDouble()),
              nextDepthMetres: (args[1] - args[2]).toDouble(),
              pressure: pressure,
            );
            fields = ['boyleGradientNitrogenBar', 'boyleGradientHeliumBar'];
            tolerance = 1e-8;
          case 'critical_volume':
            final normalized = bubble.copyWith(
              totalPhaseVolumeMin: bubble.surfacePhaseVolumeMin.map(
                (v) => v + args[0],
              ),
            );
            actual = model.relaxGradients(normalized);
            fields = [
              'allowableGradientNitrogenBar',
              'allowableGradientHeliumBar',
            ];
            tolerance = 1e-8;
          case 'calc_surface_phase_volume_time':
            actual = model.phaseVolume(
              bubble,
              surfaceTissues: tissues,
              pressure: pressure,
              decoDurationMin: 0,
            );
            fields = ['surfacePhaseVolumeMin'];
            tolerance = 1e-9;
          default:
            throw StateError('Unexpected kernel');
        }
        final json = actual.toJson();
        for (final field in fields) {
          final values = (json[field] as List).cast<num>();
          final correct = (expected[field] as List).cast<num>();
          for (var i = 0; i < 16; i++) {
            expect(
              values[i],
              closeTo(correct[i], tolerance),
              reason: '$field compartment$i',
            );
          }
        }
      });
    }
  }
  test('ANY convergence is intentional and inclusive at one minute', () {
    final initial = TissueState.equilibrium(
      inspiredNitrogenBar:
          (pressure.surfaceBar - pressure.waterVapourBar) * .79,
    );
    final bubble = VpmState.initial(
      parameters: VpmParameters(),
      conservatism: 0,
      tissues: initial,
      pressure: pressure,
    );
    final model = VpmGradients(
      parameters: VpmParameters(),
      kinetics: BuhlmannCoefficients.b().kinetics,
      budget: CalculationBudget(),
    );
    final values = List<double>.filled(16, 10);
    values[15] = 1;
    expect(
      model.isConverged(bubble.copyWith(totalPhaseVolumeMin: values)),
      isTrue,
    );
    values[15] = 1.000001;
    expect(
      model.isConverged(bubble.copyWith(totalPhaseVolumeMin: values)),
      isFalse,
    );
  });
  test(
    'surface phase limits are finite for equilibrium, pure N2 excess and He-only excess',
    () {
      final initial = TissueState.equilibrium(
        inspiredNitrogenBar:
            (pressure.surfaceBar - pressure.waterVapourBar) * .79,
      );
      final bubble = VpmState.initial(
        parameters: VpmParameters(),
        conservatism: 0,
        tissues: initial,
        pressure: pressure,
      );
      final kinetics = BuhlmannCoefficients.b().kinetics;
      final model = VpmGradients(
        parameters: VpmParameters(),
        kinetics: kinetics,
        budget: CalculationBudget(),
      );
      final equilibrium = model.phaseVolume(
        bubble,
        surfaceTissues: initial,
        pressure: pressure,
        decoDurationMin: 0,
      );
      expect(equilibrium.surfacePhaseVolumeMin, everyElement(0));
      final n2 = TissueState(
        nitrogenBar: List.filled(16, .751053 + 1),
        heliumBar: List.filled(16, 0),
      );
      final he = TissueState(
        nitrogenBar: initial.nitrogenBar,
        heliumBar: List.filled(16, 1),
      );
      final nResult = model.phaseVolume(
        bubble,
        surfaceTissues: n2,
        pressure: pressure,
        decoDurationMin: 5,
      );
      final heResult = model.phaseVolume(
        bubble,
        surfaceTissues: he,
        pressure: pressure,
        decoDurationMin: 5,
      );
      for (var i = 0; i < 16; i++) {
        expect(
          nResult.surfacePhaseVolumeMin[i],
          closeTo(kinetics.nitrogenHalfTimesMin[i] / math.ln2, 1e-10),
        );
        expect(
          heResult.surfacePhaseVolumeMin[i],
          closeTo(kinetics.heliumHalfTimesMin[i] / math.ln2, 1e-10),
        );
        expect(
          nResult.totalPhaseVolumeMin[i],
          nResult.surfacePhaseVolumeMin[i] + 5,
        );
      }
    },
  );
  test(
    'projected ascent respects independent safeguard for a deliberately shallow candidate',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/independent/vpmb-projected-ascent-contract.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final input = fixture['input'] as Map<String, dynamic>;
      final tissues = TissueState.fromJson(
        (input['tissues'] as Map).cast<String, Object?>(),
      );
      final context = PressureContext(
        surfaceBar: (input['surface_bar'] as num).toDouble(),
        waterVapourBar: (input['vapour_bar'] as num).toDouble(),
        barPerMetre: .1,
      );
      final initial = VpmState.initial(
        parameters: VpmParameters(),
        conservatism: 0,
        tissues: tissues,
        pressure: context,
      );
      final bubble = initial.copyWith(
        allowableGradientNitrogenBar: (input['nitrogen_gradients_bar'] as List)
            .cast<num>()
            .map((v) => v.toDouble()),
        allowableGradientHeliumBar: (input['helium_gradients_bar'] as List)
            .cast<num>()
            .map((v) => v.toDouble()),
      );
      final model = VpmGradients(
        parameters: VpmParameters(),
        kinetics: BuhlmannCoefficients.b().kinetics,
        budget: CalculationBudget(),
      );
      final candidate = model.projectedAscent(
        bubble: bubble,
        initial: tissues,
        fromMetres: (input['from_m'] as num).toDouble(),
        candidateMetres: 0,
        breathing: BreathingGas.oc(Gas(oxygen: .15, helium: .45)),
        ascentMetresPerMin: (input['ascent_m_min'] as num).toDouble(),
        pressure: context,
        grid: StopGrid(
          stepMetres: (input['step_m'] as num).toDouble(),
          lastStopMetres: (input['step_m'] as num).toDouble(),
        ),
      );
      expect(candidate, (fixture['expected'] as Map)['candidate_m']);
      expect(candidate, greaterThan(0));
    },
  );
}
