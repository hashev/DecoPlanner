import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/domain/profile_data.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test(
    'profile contains exact surface and physical endpoints without interpolation or duplicate dummy state',
    () {
      final input = settings();
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'profile',
          settings: input,
          levels: [
            Level(
              depthMetres: 30,
              durationMin: 20,
              breathing: BreathingGas.oc(Gas(oxygen: .21)),
            ),
          ],
        ),
      );
      final data = ProfileData(result: result, settings: input);
      expect(data.points.length, result.segments.length + 1);
      expect(data.points.first.depthMetres, 0);
      expect(data.points.first.runtimeMin, 0);
      expect(data.points.first.state, same(result.initialState));
      expect(data.points.last.depthMetres, 0);
      expect(data.points.last.runtimeMin, result.runtimeMin);
      for (var i = 0; i < result.segments.length; i++) {
        expect(data.points[i + 1].state, same(result.segments[i].endState));
        expect(data.points[i + 1].runtimeMin, result.segments[i].endMin);
        expect(
          data.points[i + 1].depthMetres,
          result.segments[i].physical.endDepthMetres,
        );
      }
      final first = data.tissues(data.points.first).first;
      expect(first.mValueBar, closeTo(1.1696 + 1.01325 / .5578, 1e-12));
      expect(first.nitrogenBar, result.initialState.tissues.nitrogenBar.first);
      expect(first.heliumBar, 0);
    },
  );
  test(
    'ascent view omits entered holds and breaks the trace across omitted intervals',
    () {
      final input = settings();
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'multilevel',
          settings: input,
          levels: [
            for (final (depth, duration) in [
              (30.0, 20.0),
              (21.0, 10.0),
              (36.0, 10.0),
            ])
              Level(
                depthMetres: depth,
                durationMin: duration,
                breathing: BreathingGas.oc(Gas(oxygen: .21)),
              ),
          ],
        ),
      );
      final data = ProfileData(result: result, settings: input);
      final points = data.visiblePoints(ascentOnly: true);
      expect(points.first.depthMetres, 30);
      expect(points.last.runtimeMin, result.runtimeMin);
      expect(
        points.any((p) => p.depthMetres == 36 && !p.continuesTrace),
        isTrue,
      );
      for (final point in points.where((p) => p.continuesTrace)) {
        final phase = result.segments[point.segmentIndex].phase;
        expect(phase, isIn([SegmentPhase.ascent, SegmentPhase.decompression]));
      }
      expect(data.points.length, greaterThan(points.length));
    },
  );
  test('VPM tissue snapshots never receive invented Buhlmann M-values', () {
    final input = settings(model: DecompressionModel.vpmB);
    final result = calculateVpm(
      DiveRequest(
        id: 'vpm',
        settings: input,
        levels: [
          Level(
            depthMetres: 30,
            durationMin: 20,
            breathing: BreathingGas.oc(Gas(oxygen: .21)),
          ),
        ],
      ),
    );
    final data = ProfileData(result: result, settings: input);
    expect(data.tissues(data.points.last), hasLength(16));
    for (final value in data.tissues(data.points.last)) {
      expect(value.mValueBar, isNull);
      expect(value.gradientFraction, isNull);
    }
  });
}
