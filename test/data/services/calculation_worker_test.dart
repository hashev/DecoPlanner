import 'dart:isolate';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/calculation_worker.dart';
import 'package:flutter_test/flutter_test.dart';

DiveRequest request({
  String id = 'air',
  double depth = 30,
  DecompressionModel model = DecompressionModel.buhlmannB,
}) => DiveRequest(
  id: id,
  levels: [
    Level(
      depthMetres: depth,
      durationMin: 20,
      breathing: BreathingGas.oc(Gas(oxygen: .21)),
    ),
  ],
  settings: CalculationSettings(
    model: model,
    pressure: PressureContext(
      surfaceBar: 1.01325,
      waterVapourBar: .0493,
      barPerMetre: .1,
    ),
    stopGrid: StopGrid.metric(),
    gradientFactors: GradientFactors(low: .3, high: .85),
  ),
);

TypeMatcher<WorkerFailure> failure(WorkerFailureKind kind) =>
    isA<WorkerFailure>().having((f) => f.kind, 'kind', kind);

void main() {
  test(
    'real worker computes separate B/C/VPM bailout results with full prefix state',
    () async {
      final worker = CalculationWorker();
      addTearDown(worker.dispose);
      for (final model in DecompressionModel.values) {
        final base = request(model: model);
        final source = DiveRequest(
          id: base.id,
          settings: base.settings,
          levels: [
            Level(
              depthMetres: 45,
              durationMin: 25,
              breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
          ],
        );
        final branch = BailoutRequest(
          id: 'escape-${model.name}',
          sourceDiveId: source.id,
          runtimeMin: 12.5,
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
        );
        final result = await worker
            .calculate(
              source,
              bailout: branch,
              inputRevision: 8,
              dependencyVersion: 'ccr-source-v7',
            )
            .result;
        final direct = model == DecompressionModel.vpmB
            ? calculateVpmBailout(source, branch)
            : calculateBuhlmannBailout(source, branch);
        expect(result.toJson(), direct.toJson());
        expect(result.diveId, branch.id);
        expect(
          result.segments.first.physical.breathing.mode,
          BreathingMode.ccr,
        );
        expect(result.segments.last.physical.breathing.mode, BreathingMode.oc);
        expect(result.finalState.vpm != null, model == DecompressionModel.vpmB);
      }
    },
  );

  test(
    'invalid bailout crosses worker boundary as typed failure and next job recovers',
    () async {
      final worker = CalculationWorker();
      addTearDown(worker.dispose);
      final bad = worker.calculate(
        request(),
        bailout: BailoutRequest(
          id: 'escape',
          sourceDiveId: 'missing',
          runtimeMin: 10,
          initialOcGas: Gas(oxygen: .21),
        ),
        inputRevision: 1,
        dependencyVersion: 'none',
      );
      await expectLater(
        bad.result,
        throwsA(
          failure(WorkerFailureKind.calculation).having(
            (e) => e.calculationFailure?.code,
            'core code',
            CalculationFailureCode.invalidInput,
          ),
        ),
      );
      final next = await worker
          .calculate(request(), inputRevision: 2, dependencyVersion: 'none')
          .result;
      expect(next.diveId, 'air');
    },
  );

  test(
    'real isolate runs both engines, returns all state and reports progress',
    () async {
      final worker = CalculationWorker();
      addTearDown(worker.dispose);
      for (final model in [
        DecompressionModel.buhlmannB,
        DecompressionModel.vpmB,
      ]) {
        final input = request(model: model);
        final handle = worker.calculate(
          input,
          inputRevision: 7,
          dependencyVersion: 'prior-dive-v3',
        );
        final stages = <CalculationStage>[];
        final subscription = handle.progress.listen(stages.add);
        final result = await handle.result;
        await subscription.asFuture<void>();
        final direct = model == DecompressionModel.vpmB
            ? calculateVpm(input)
            : calculateBuhlmann(input);
        expect(result.toJson(), direct.toJson());
        expect(stages, [
          CalculationStage.starting,
          CalculationStage.calculating,
          CalculationStage.completed,
        ]);
        expect(handle.identity.inputRevision, 7);
        expect(handle.identity.dependencyVersion, 'prior-dive-v3');
      }
    },
  );
  test(
    'new numeric inputs change the computed result in the real worker',
    () async {
      final worker = CalculationWorker();
      addTearDown(worker.dispose);
      final a = await worker
          .calculate(request(), inputRevision: 1, dependencyVersion: 'none')
          .result;
      final b = await worker
          .calculate(
            request(depth: 45),
            inputRevision: 2,
            dependencyVersion: 'none',
          )
          .result;
      expect(b.runtimeMin, greaterThan(a.runtimeMin));
    },
  );
  test('solver failure crosses isolate as typed calculation failure', () async {
    final worker = CalculationWorker();
    addTearDown(worker.dispose);
    final handle = worker.calculate(
      request(),
      inputRevision: 1,
      dependencyVersion: 'none',
      maxIterations: 1,
    );
    await expectLater(
      handle.result,
      throwsA(
        failure(WorkerFailureKind.calculation).having(
          (e) => e.calculationFailure?.code,
          'core code',
          CalculationFailureCode.budgetExceeded,
        ),
      ),
    );
  });
  test(
    'cancel before spawn completes and repeated cancellation dispose safely',
    () async {
      final worker = CalculationWorker(entryPoint: routeOrBlock);
      final handle = worker.calculate(
        request(id: 'block'),
        inputRevision: 1,
        dependencyVersion: 'none',
      );
      final failed = expectLater(
        handle.result,
        throwsA(failure(WorkerFailureKind.cancelled)),
      );
      handle.cancel();
      handle.cancel();
      await failed;
      await worker.dispose();
      await worker.dispose();
      expect(
        () => worker.calculate(
          request(),
          inputRevision: 1,
          dependencyVersion: 'none',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'cancel kills a synchronously blocked isolate while parent remains responsive',
    () async {
      final worker = CalculationWorker(entryPoint: routeOrBlock);
      addTearDown(worker.dispose);
      final handle = worker.calculate(
        request(id: 'block'),
        inputRevision: 1,
        dependencyVersion: 'none',
      );
      final failed = expectLater(
        handle.result,
        throwsA(failure(WorkerFailureKind.cancelled)),
      );
      await handle.progress.firstWhere(
        (stage) => stage == CalculationStage.calculating,
      );
      var heartbeat = false;
      await Future<void>.delayed(const Duration(milliseconds: 5), () {
        heartbeat = true;
      });
      expect(heartbeat, isTrue);
      handle.cancel();
      await failed;
    },
  );
  test(
    'external timeout terminates a blocked worker, including zero timeout',
    () async {
      for (final timeout in [Duration.zero, const Duration(milliseconds: 50)]) {
        final worker = CalculationWorker(entryPoint: routeOrBlock);
        final handle = worker.calculate(
          request(id: 'block'),
          inputRevision: 1,
          dependencyVersion: 'none',
          timeout: timeout,
        );
        await expectLater(
          handle.result,
          throwsA(failure(WorkerFailureKind.timeout)),
        );
        await worker.dispose();
      }
    },
  );
  test('service accepts a fresh real calculation after timeout', () async {
    final worker = CalculationWorker(entryPoint: routeOrBlock);
    addTearDown(worker.dispose);
    final blocked = worker.calculate(
      request(id: 'block'),
      inputRevision: 1,
      dependencyVersion: 'none',
      timeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      blocked.result,
      throwsA(failure(WorkerFailureKind.timeout)),
    );
    final recovered = await worker
        .calculate(request(), inputRevision: 2, dependencyVersion: 'none')
        .result;
    expect(recovered.runtimeMin, greaterThan(20));
  });
  test(
    'newer revision supersedes the old job and returns only the new computed result',
    () async {
      final worker = CalculationWorker(entryPoint: routeOrBlock);
      addTearDown(worker.dispose);
      final old = worker.calculate(
        request(id: 'block'),
        inputRevision: 1,
        dependencyVersion: 'a',
      );
      final failed = expectLater(
        old.result,
        throwsA(failure(WorkerFailureKind.superseded)),
      );
      await old.progress.firstWhere(
        (stage) => stage == CalculationStage.calculating,
      );
      final next = worker.calculate(
        request(id: 'new'),
        inputRevision: 2,
        dependencyVersion: 'b',
      );
      final result = await next.result;
      await failed;
      expect(result.diveId, 'new');
      expect(next.identity.requestId, isNot(old.identity.requestId));
      expect(next.identity.dependencyVersion, 'b');
    },
  );
  for (final entry in <String, CalculationWorkerEntry>{
    'stale dependency': staleDependency,
    'stale revision': staleRevision,
    'model version': staleModelVersion,
    'protocol version': staleProtocol,
    'malformed': malformed,
  }.entries) {
    test('rejects ${entry.key} response without returning a plan', () async {
      final worker = CalculationWorker(entryPoint: entry.value);
      addTearDown(worker.dispose);
      final handle = worker.calculate(
        request(),
        inputRevision: 2,
        dependencyVersion: 'current',
      );
      await expectLater(
        handle.result,
        throwsA(failure(WorkerFailureKind.protocol)),
      );
    });
  }
  test(
    'unexpected isolate exit is a failure, not a successful empty plan',
    () async {
      final worker = CalculationWorker(entryPoint: exitWithoutResult);
      addTearDown(worker.dispose);
      await expectLater(
        worker
            .calculate(
              request(),
              inputRevision: 2,
              dependencyVersion: 'current',
            )
            .result,
        throwsA(failure(WorkerFailureKind.exited)),
      );
    },
  );
}

Map<String, Object?> reply(Map<String, Object?> envelope) => {
  ...envelope,
  'event': 'progress',
  'stage': CalculationStage.calculating.name,
};
void routeOrBlock(Map<String, Object?> envelope) {
  if ((envelope['request'] as Map)['id'] != 'block') {
    calculationWorkerEntry(envelope);
    return;
  }
  (envelope['replyTo'] as SendPort).send(reply(envelope));
  while (true) {
    /* Only a parent-side kill can interrupt this test worker. */
  }
}

void staleDependency(Map<String, Object?> envelope) =>
    (envelope['replyTo'] as SendPort).send({
      ...reply(envelope),
      'dependencyVersion': 'old',
    });
void staleRevision(Map<String, Object?> envelope) =>
    (envelope['replyTo'] as SendPort).send({
      ...reply(envelope),
      'inputRevision': 1,
    });
void staleModelVersion(Map<String, Object?> envelope) =>
    (envelope['replyTo'] as SendPort).send({
      ...reply(envelope),
      'modelVersion': 'old',
    });
void staleProtocol(Map<String, Object?> envelope) =>
    (envelope['replyTo'] as SendPort).send({
      ...reply(envelope),
      'protocolVersion': 0,
    });
void malformed(Map<String, Object?> envelope) =>
    (envelope['replyTo'] as SendPort).send({'event': 'result'});
void exitWithoutResult(Map<String, Object?> envelope) {}
