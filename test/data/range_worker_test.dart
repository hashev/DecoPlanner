import 'dart:async';
import 'dart:isolate';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/calculation_worker.dart';
import 'package:deco_planner/data/services/range_worker.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void blockedRange(Map<String, Object?> request) {
  while (true) {}
}

void wrongIdentity(Map<String, Object?> request) {
  (request['send'] as SendPort).send({
    'identity': {'requestId': -1},
  });
}

void exitedRange(Map<String, Object?> request) {}
void main() {
  late PlannerViewModel model;
  setUp(() => model = PlannerViewModel());
  tearDown(() => model.dispose());
  RangeHandle run(
    RangeWorker worker, {
    RangeAxis? depths,
    RangeAxis? durations,
    List<RangeVariant>? variants,
    Duration timeout = const Duration(seconds: 10),
  }) => worker.calculate(
    source: model.selected,
    depths: depths ?? RangeAxis(first: 30, last: 30, step: 3),
    durations: durations ?? RangeAxis(first: 20, last: 20, step: 1),
    variants: variants ?? [RangeVariant.base],
    inputRevision: model.planRequest.revision,
    dependencyVersion: 'initial',
    timeout: timeout,
  );
  test(
    'real range worker streams ordered summaries matching independently requested schedules',
    () async {
      final worker = RangeWorker();
      addTearDown(worker.dispose);
      final handle = run(
        worker,
        depths: RangeAxis(first: 27, last: 33, step: 3),
        durations: RangeAxis(first: 18, last: 22, step: 2),
        variants: [RangeVariant.base, RangeVariant.noAdditionalGases],
      );
      final cells = <RangeSummary>[];
      final subscription = handle.cells.listen(cells.add);
      await handle.done;
      await subscription.cancel();
      expect(cells.length, 18);
      for (final cell in cells) {
        final result = calculateBuhlmann(cell.request);
        expect(cell.runtimeMin, closeTo(result.runtimeMin, 1e-10));
        expect(cell.decompressionMin, closeTo(result.decompressionMin, 1e-10));
        expect(cell.request.levels.last.depthMetres, cell.depthMetres);
        expect(cell.request.levels.last.durationMin, cell.durationMin);
        expect(cell.failure, isNull);
      }
      expect(cells.first.depthMetres, 27);
      expect(cells.last.depthMetres, 33);
      expect(cells.take(2).map((cell) => cell.variant), [
        RangeVariant.base,
        RangeVariant.noAdditionalGases,
      ]);
    },
  );
  test(
    'cell failure is retained and does not erase a successful neighbour',
    () async {
      final worker = RangeWorker();
      addTearDown(worker.dispose);
      final handle = run(
        worker,
        depths: RangeAxis(first: 30, last: 30, step: 3),
        durations: RangeAxis(first: 0, last: 20, step: 20),
      );
      final cells = await handle.cells.toList();
      await handle.done;
      expect(cells.first.failure, isNotNull);
      expect(cells.first.runtimeMin, isNull);
      expect(cells.last.failure, isNull);
      expect(cells.last.runtimeMin, greaterThan(20));
    },
  );
  test('VPM CCR bailout variants preserve physical requests', () async {
    final worker = RangeWorker();
    addTearDown(worker.dispose);
    final settings = CalculationSettings(
      model: DecompressionModel.vpmB,
      pressure: PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: .0493,
        barPerMetre: .1,
      ),
      stopGrid: StopGrid.metric(),
      gradientFactors: GradientFactors(low: .3, high: .85),
    );
    final source = DiveRequest(
      id: 'ccr',
      settings: settings,
      levels: [
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
        ),
      ],
    );
    final bailout = BailoutRequest(
      id: 'escape',
      sourceDiveId: 'ccr',
      runtimeMin: 10,
      initialOcGas: Gas(oxygen: .21),
      switches: [
        GasSwitch(depthMetres: 21, breathing: BreathingGas.oc(Gas(oxygen: .5))),
      ],
    );
    final handle = worker.calculate(
      source: source,
      bailout: bailout,
      depths: RangeAxis(first: 30, last: 30, step: 3),
      durations: RangeAxis(first: 20, last: 20, step: 1),
      variants: RangeVariant.values,
      inputRevision: 0,
      dependencyVersion: 'initial',
    );
    final cells = await handle.cells.toList();
    await handle.done;
    expect(cells.length, 3);
    for (final cell in cells) {
      final expected = calculateVpmBailout(cell.request, cell.bailout!);
      expect(cell.runtimeMin, closeTo(expected.runtimeMin, 1e-9));
      expect(cell.request.levels.single.breathing.mode, BreathingMode.ccr);
      expect(cell.failure, isNull);
    }
    expect(cells.first.bailout!.switches.length, 1);
    expect(cells.last.bailout!.switches, isEmpty);
  });
  test(
    'hard cancellation preserves parent responsiveness even for blocked child',
    () async {
      final worker = RangeWorker(entryPoint: blockedRange);
      addTearDown(worker.dispose);
      final handle = run(worker);
      final failure = expectLater(
        handle.done,
        throwsA(
          isA<WorkerFailure>().having(
            (error) => error.kind,
            'kind',
            WorkerFailureKind.cancelled,
          ),
        ),
      );
      final heartbeat = Completer<void>();
      Timer(const Duration(milliseconds: 20), () => heartbeat.complete());
      await heartbeat.future.timeout(const Duration(seconds: 2));
      handle.cancel();
      await failure;
    },
  );
  test('cancel before spawn completes is safe', () async {
    final worker = RangeWorker();
    addTearDown(worker.dispose);
    final handle = run(worker);
    final failure = expectLater(
      handle.done,
      throwsA(
        isA<WorkerFailure>().having(
          (error) => error.kind,
          'kind',
          WorkerFailureKind.cancelled,
        ),
      ),
    );
    handle.cancel();
    await failure;
  });
  test('timeout kills a blocked child', () async {
    final worker = RangeWorker(entryPoint: blockedRange);
    addTearDown(worker.dispose);
    await expectLater(
      run(worker, timeout: const Duration(milliseconds: 30)).done,
      throwsA(
        isA<WorkerFailure>().having(
          (error) => error.kind,
          'kind',
          WorkerFailureKind.timeout,
        ),
      ),
    );
  });
  test('protocol mismatch cannot publish cells', () async {
    final worker = RangeWorker(entryPoint: wrongIdentity);
    addTearDown(worker.dispose);
    final handle = run(worker);
    final cells = <RangeSummary>[];
    handle.cells.listen(cells.add);
    await expectLater(
      handle.done,
      throwsA(
        isA<WorkerFailure>().having(
          (error) => error.kind,
          'kind',
          WorkerFailureKind.protocol,
        ),
      ),
    );
    expect(cells, isEmpty);
  });
  test('unexpected exit is an explicit failure', () async {
    final worker = RangeWorker(entryPoint: exitedRange);
    addTearDown(worker.dispose);
    await expectLater(
      run(worker).done,
      throwsA(
        isA<WorkerFailure>().having(
          (error) => error.kind,
          'kind',
          WorkerFailureKind.exited,
        ),
      ),
    );
  });
  test(
    'superseding range rejects old job and recovers with a real calculation',
    () async {
      final worker = RangeWorker();
      addTearDown(worker.dispose);
      final first = run(
        worker,
        depths: RangeAxis(first: 1, last: 1000, step: 1),
      );
      final failed = expectLater(
        first.done,
        throwsA(
          isA<WorkerFailure>().having(
            (error) => error.kind,
            'kind',
            WorkerFailureKind.cancelled,
          ),
        ),
      );
      final second = run(worker);
      final cells = second.cells.toList();
      await failed;
      await second.done;
      expect((await cells).single.runtimeMin, greaterThan(20));
    },
  );
}
