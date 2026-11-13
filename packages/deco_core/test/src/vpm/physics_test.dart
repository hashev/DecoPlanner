import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final inputs =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-physical-states.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final refined =
      jsonDecode(
            File(
              'test/fixtures/independent/vpmb-physical-high-precision.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = inputs['cases'] as List;
  for (var index = 0; index < cases.length; index++) {
    final source = cases[index] as Map<String, dynamic>;
    final oracle = (refined['cases'] as List)[index] as Map<String, dynamic>;
    test(
      'VPM c${source['conservatism']} ${source['depth_m']}m independent crushing/radii/gradients',
      () {
        final context = PressureContext(
          surfaceBar: 1,
          waterVapourBar: .0493,
          barPerMetre: .1,
        );
        final initial = TissueState.equilibrium(
          inspiredNitrogenBar: (1 - .0493) * .79,
        );
        final conservatism = source['conservatism'] as int;
        final request = source['request'] as Map<String, dynamic>;
        final dive = (request['input'] as List).first as Map<String, dynamic>;
        final gas =
            (dive['gasmix_summary'] as List).first as Map<String, dynamic>;
        final mix = Gas(
          oxygen: (gas['fraction_O2'] as num).toDouble(),
          helium: (gas['fraction_He'] as num).toDouble(),
        );
        final depth = (source['depth_m'] as num).toDouble();
        final parameters = VpmParameters();
        final bubble = VpmState.initial(
          parameters: parameters,
          conservatism: conservatism,
          tissues: initial,
          pressure: context,
        );
        final physics = VpmPhysics(
          parameters: parameters,
          kinetics: BuhlmannCoefficients.b().kinetics,
          budget: CalculationBudget(),
        );
        final crushed = physics.crushingAfterDescent(
          bubble: bubble,
          initialTissues: initial,
          segment: PropagationSegment(
            startDepthMetres: 0,
            endDepthMetres: depth,
            durationMin: depth / 23,
            breathing: BreathingGas.oc(mix),
          ),
          pressure: context,
        );
        final regenerated = physics.regenerate(crushed, 30);
        final actual = regenerated.toJson();
        final expected = oracle['expected'] as Map<String, dynamic>;
        for (final entry in expected.entries) {
          final vector = (actual[entry.key] as List).cast<num>();
          final correct = (entry.value as List).cast<String>();
          final tolerance = entry.key.endsWith('Metres') ? 1e-15 : 1e-8;
          for (var i = 0; i < 16; i++) {
            expect(
              vector[i],
              closeTo(double.parse(correct[i]), tolerance),
              reason: '${entry.key} compartment$i',
            );
          }
        }
        if (depth == 80) {
          final stages = source['expected_stages'] as List;
          final sourceFinal = stages.last as Map<String, dynamic>;
          final unchanged = {
            ...(sourceFinal['pressure_state'] as Map<String, dynamic>),
            ...(sourceFinal['radius_state'] as Map<String, dynamic>),
          };
          for (final entry in unchanged.entries) {
            final vector = (actual[entry.key] as List).cast<num>();
            final expected = (entry.value as List).cast<num>();
            for (var i = 0; i < 16; i++) {
              expect(
                vector[i],
                closeTo(
                  expected[i],
                  entry.key.endsWith('Metres') ? 1e-15 : 1e-10,
                ),
                reason: 'untouched oracle ${entry.key} tissue$i',
              );
            }
          }
        } else {
          expect(crushed.ambientOnsetBar.any((v) => v > 0), isTrue);
          expect(
            crushed.maxCrushingPressureHeliumBar.any(
              (v) => v > parameters.onsetImpermeabilityBar,
            ),
            isTrue,
          );
        }
        expect(bubble.maxCrushingPressureNitrogenBar, everyElement(0));
      },
    );
  }
  test('zero crushing has a finite analytical regeneration limit, no0/0', () {
    final parameters = VpmParameters();
    final pressure = PressureContext(
      surfaceBar: 1,
      waterVapourBar: .0493,
      barPerMetre: .1,
    );
    final initial = TissueState.equilibrium(inspiredNitrogenBar: .751053);
    final state = VpmState.initial(
      parameters: parameters,
      conservatism: 0,
      tissues: initial,
      pressure: pressure,
    );
    final physics = VpmPhysics(
      parameters: parameters,
      kinetics: BuhlmannCoefficients.b().kinetics,
      budget: CalculationBudget(),
    );
    final after = physics.regenerate(state, 100);
    expect(
      after.regeneratedRadiusNitrogenMetres,
      everyElement(parameters.nitrogenRadiusMetres),
    );
    expect(after.adjustedCrushingPressureNitrogenBar, everyElement(0));
    expect(after.adjustedCrushingPressureHeliumBar, everyElement(0));
    expect(
      after.initialAllowableGradientNitrogenBar.every(
        (v) => v.isFinite && v > 0,
      ),
      isTrue,
    );
  });
}
