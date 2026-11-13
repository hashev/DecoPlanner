import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final low = BreathingGas.ccr(Gas(oxygen: .21, helium: .35), .7);
  final high = BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3);
  List<PropagationSegment> prepare(
    double start,
    double end,
    double duration, {
    bool included = true,
  }) => prepareLevel(
    startDepthMetres: start,
    targetDepthMetres: end,
    levelDurationMin: duration,
    descentMetresPerMin: 10,
    ascentMetresPerMin: 9,
    includeDescentInLevelTime: included,
    movementGas: low,
    levelGas: high,
  );
  test(
    'descent uses low setpoint, hold uses high, include travel subtracts once',
    () {
      final segments = prepare(0, 30, 20);
      expect(segments.map((s) => s.durationMin), [3, 17]);
      expect(segments.first.breathing.setpointBar, .7);
      expect(segments.last.breathing.setpointBar, 1.3);
      expect(prepare(0, 30, 20, included: false).map((s) => s.durationMin), [
        3,
        20,
      ]);
    },
  );
  test('movement-only level creates no zero-duration hold', () {
    final segments = prepare(0, 30, 3);
    expect(segments, hasLength(1));
    expect(segments.single.isMovement, isTrue);
    expect(prepare(0, 0, 0), isEmpty);
    expect(() => segments.clear(), throwsUnsupportedError);
  });
  test('insufficient and negative duration rejected', () {
    expect(() => prepare(0, 30, 2.99), throwsA(isA<CalculationFailure>()));
    expect(() => prepare(0, 30, -1), throwsA(isA<CalculationFailure>()));
  });
  test('multilevel ascent travel is separate from the specified hold time', () {
    final segments = prepare(30, 21, 5);
    expect(segments.map((s) => s.durationMin), [1, 5]);
    expect(segments.map((s) => s.endDepthMetres), [21, 21]);
  });
  test(
    'bailout propagation selects OC without changing CCR source segments',
    () {
      final source = prepare(0, 30, 20);
      final bailout = PropagationSegment(
        startDepthMetres: 30,
        endDepthMetres: 21,
        durationMin: 1,
        breathing: BreathingGas.oc(Gas(oxygen: .5)),
      );
      expect(bailout.breathing.mode, BreathingMode.oc);
      expect(source.last.breathing.mode, BreathingMode.ccr);
      expect(source.last.breathing.setpointBar, 1.3);
    },
  );
}
