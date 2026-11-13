import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/buhlmann-altitude-repetitive.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final row in (fixture['cases'] as List).cast<Map>()) {
    test('independent full Bühlmann ${row['id']}', () {
      CalculationState? previous;
      final expectedDives = (row['dives'] as List).cast<Map>();
      final nativeAltitude = row['altitude'] as Map?;
      final settings = CalculationSettings(
        model: row['model'] == 'B'
            ? DecompressionModel.buhlmannB
            : DecompressionModel.buhlmannC,
        pressure: PressureContext(
          surfaceBar: 1.01325,
          waterVapourBar: .0627,
          barPerMetre: .1,
        ),
        stopGrid: StopGrid.metric(),
        gradientFactors: GradientFactors(low: .3, high: .85),
        altitude: nativeAltitude == null
            ? AltitudeSettings()
            : AltitudeSettings(
                enabled: true,
                seaLevelBar: 1.01325,
                diveAltitudeMetres: (nativeAltitude['height_m'] as num)
                    .toDouble(),
                initialAltitudeMetres: 0,
                acclimatized: nativeAltitude['acclimatized'] as bool,
                travelMin: (nativeAltitude['travel_min'] as num).toDouble(),
                waitMin: (nativeAltitude['wait_min'] as num).toDouble(),
              ),
      );
      for (var i = 0; i < expectedDives.length; i++) {
        final e = expectedDives[i];
        final mode = (row['modes'] as List)[i];
        final request = DiveRequest(
          id: 'source-$i',
          settings: settings,
          initialState: previous,
          surfaceIntervalMin: i == 0
              ? 0
              : (row['surface_interval_min'] as num).toDouble(),
          levels: [
            Level(
              depthMetres: 45,
              durationMin: 25,
              breathing: mode == 'oc'
                  ? BreathingGas.oc(Gas(oxygen: .21, helium: .35))
                  : BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
          ],
          switches: mode == 'bailout'
              ? []
              : [
                  GasSwitch(
                    depthMetres: 21,
                    breathing: mode == 'oc'
                        ? BreathingGas.oc(Gas(oxygen: .5))
                        : BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.4),
                  ),
                  GasSwitch(
                    depthMetres: 6,
                    breathing: mode == 'oc'
                        ? BreathingGas.oc(Gas(oxygen: 1))
                        : BreathingGas.ccr(Gas(oxygen: .21, helium: .35), .7),
                  ),
                ],
        );
        final original = previous == null
            ? null
            : jsonEncode(previous.toJson());
        final result = mode == 'bailout'
            ? calculateBuhlmannBailout(
                request,
                BailoutRequest(
                  id: 'escape-$i',
                  sourceDiveId: request.id,
                  runtimeMin: 25,
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
              )
            : calculateBuhlmann(request);
        expect(
          result.pressure.surfaceBar,
          closeTo(row['surface_bar'] as num, 1e-12),
        );
        final initial = e['initial_tissues'] as List;
        for (var tissue = 0; tissue < 16; tissue++) {
          expect(
            result.initialState.tissues.nitrogenBar[tissue],
            closeTo((initial[tissue] as List)[0] as num, 1e-10),
          );
          expect(
            result.initialState.tissues.heliumBar[tissue],
            closeTo((initial[tissue] as List)[1] as num, 1e-10),
          );
        }
        final oxygen = e['initial_oxygen'] as List;
        expect(
          result.initialState.oxygen.cnsFraction,
          closeTo(oxygen[0] as num, 1e-10),
        );
        expect(result.initialState.oxygen.otu, closeTo(oxygen[1] as num, 1e-9));
        final expected = e['expected'] as Map;
        final segments = (expected['segments'] as List).cast<Map>();
        expect(result.segments.length, segments.length);
        for (var n = 0; n < segments.length; n++) {
          final actual = result.segments[n], correct = segments[n];
          expect(actual.phase.name, correct['phase']);
          expect(actual.startMin, closeTo(correct['start_min'] as num, 1e-10));
          expect(
            actual.physical.durationMin,
            closeTo(correct['duration_min'] as num, 1e-10),
          );
          expect(
            actual.physical.startDepthMetres,
            closeTo(correct['start_depth_m'] as num, 1e-10),
          );
          expect(
            actual.physical.endDepthMetres,
            closeTo(correct['end_depth_m'] as num, 1e-10),
          );
          expect(actual.physical.breathing.gas.oxygen, correct['oxygen']);
          expect(actual.physical.breathing.gas.helium, correct['helium']);
          expect(
            actual.physical.breathing.setpointBar,
            correct['setpoint_bar'],
          );
          for (var tissue = 0; tissue < 16; tissue++) {
            expect(
              actual.endState.tissues.nitrogenBar[tissue],
              closeTo((correct['n2_bar'] as List)[tissue] as num, 1e-10),
              reason: 'segment$n N2 tissue$tissue',
            );
            expect(
              actual.endState.tissues.heliumBar[tissue],
              closeTo((correct['he_bar'] as List)[tissue] as num, 1e-10),
              reason: 'segment$n He tissue$tissue',
            );
          }
          expect(
            actual.endState.oxygen.cnsFraction,
            closeTo(correct['cns_fraction'] as num, 1e-10),
          );
          expect(
            actual.endState.oxygen.otu,
            closeTo(correct['otu'] as num, 1e-9),
          );
        }
        expect(
          result.runtimeMin,
          closeTo(expected['runtime_min'] as num, 1e-10),
        );
        if (previous != null) {
          expect(jsonEncode(previous.toJson()), original);
          if (row['surface_interval_min'] == 0) {
            expect(identical(result.initialState, previous), isTrue);
          }
        }
        previous = CalculationState.fromJson(result.finalState.toJson());
      }
    });
  }
}
