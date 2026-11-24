import 'dart:async';
import 'dart:isolate';
import 'package:deco_core/deco_core.dart';
import 'browser_worker.dart';

const _protocolVersion = 2;

enum CalculationStage { starting, calculating, completed }

enum WorkerFailureKind {
  cancelled,
  superseded,
  timeout,
  calculation,
  protocol,
  exited,
  unexpected,
}

final class WorkerFailure implements Exception {
  const WorkerFailure(this.kind, this.message, {this.calculationFailure});
  final WorkerFailureKind kind;
  final String message;
  final CalculationFailure? calculationFailure;
  @override
  String toString() => 'WorkerFailure(${kind.name}): $message';
}

final class CalculationIdentity {
  const CalculationIdentity({
    required this.requestId,
    required this.inputRevision,
    required this.dependencyVersion,
    this.modelVersion = calculationModelVersion,
  });
  final int requestId, inputRevision;
  final String dependencyVersion, modelVersion;
  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'inputRevision': inputRevision,
    'dependencyVersion': dependencyVersion,
    'modelVersion': modelVersion,
    'protocolVersion': _protocolVersion,
  };
  bool matches(Map<String, Object?> json) =>
      toJson().entries.every((e) => json[e.key] == e.value);
}

final class CalculationHandle {
  CalculationHandle._(this.identity, this.result, this.progress, this.cancel);
  final CalculationIdentity identity;
  final Future<CalculationResult> result;
  final Stream<CalculationStage> progress;
  final void Function() cancel;
}

typedef CalculationWorkerEntry = void Function(Map<String, Object?> envelope);

/// One active calculation per consumer. Replacing a job kills its isolate;
/// identity checks independently prevent stale or incompatible replies.
final class CalculationWorker {
  CalculationWorker({
    CalculationWorkerEntry entryPoint = calculationWorkerEntry,
  }) : _entryPoint = entryPoint;
  final CalculationWorkerEntry _entryPoint;
  final Set<Future<void>> _spawning = {};
  _WorkerJob? _current;
  int _nextId = 0;
  bool _disposed = false;

  CalculationHandle calculate(
    DiveRequest request, {
    BailoutRequest? bailout,
    required int inputRevision,
    required String dependencyVersion,
    Duration timeout = const Duration(seconds: 20),
    int maxIterations = 100000,
    Duration numericalTimeLimit = const Duration(seconds: 10),
  }) {
    if (_disposed) throw StateError('CalculationWorker is disposed.');
    if (inputRevision < 0 ||
        dependencyVersion.isEmpty ||
        timeout.isNegative ||
        maxIterations <= 0 ||
        numericalTimeLimit.isNegative) {
      throw ArgumentError('Invalid calculation identity or limits.');
    }
    _current?.fail(
      const WorkerFailure(
        WorkerFailureKind.superseded,
        'Calculation replaced by newer inputs.',
      ),
    );
    final identity = CalculationIdentity(
      requestId: ++_nextId,
      inputRevision: inputRevision,
      dependencyVersion: dependencyVersion,
    );
    final job = _WorkerJob(identity, bailout?.id ?? request.id);
    _current = job;
    job.timer = Timer(
      timeout,
      () => job.fail(
        const WorkerFailure(
          WorkerFailureKind.timeout,
          'Calculation timed out.',
        ),
      ),
    );
    final envelope = <String, Object?>{
      ...identity.toJson(),
      'request': request.toJson(),
      'bailout': bailout?.toJson(),
      'maxIterations': maxIterations,
      'numericalTimeLimitMicros': numericalTimeLimit.inMicroseconds,
    };
    if (usesBrowserWorkers) {
      try {
        job.browserWorker = BrowserWorker(
          onMessage: job._receive,
          onError: (message) =>
              job.fail(WorkerFailure(WorkerFailureKind.unexpected, message)),
        );
        job.browserWorker!.send({...envelope, 'operation': 'calculation'});
      } catch (error) {
        job.fail(
          WorkerFailure(
            WorkerFailureKind.unexpected,
            'Could not start calculation worker: $error',
          ),
        );
      }
    } else {
      final pending = _spawn(job, {
        ...envelope,
        'replyTo': job.receive!.sendPort,
      });
      _spawning.add(pending);
      unawaited(pending.whenComplete(() => _spawning.remove(pending)));
    }
    return CalculationHandle._(
      identity,
      job.completion.future,
      job.progress.stream,
      () => job.fail(
        const WorkerFailure(
          WorkerFailureKind.cancelled,
          'Calculation cancelled.',
        ),
      ),
    );
  }

  Future<void> _spawn(_WorkerJob job, Map<String, Object?> envelope) async {
    try {
      final isolate = await Isolate.spawn(
        _entryPoint,
        envelope,
        onExit: job.receive!.sendPort,
        onError: job.receive!.sendPort,
        errorsAreFatal: true,
        debugName: 'planner-${job.identity.requestId}',
      );
      if (job.done) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        job.isolate = isolate;
      }
    } catch (error) {
      job.fail(
        WorkerFailure(
          WorkerFailureKind.unexpected,
          'Could not start calculation isolate: $error',
        ),
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _current?.fail(
      const WorkerFailure(
        WorkerFailureKind.cancelled,
        'Calculation service disposed.',
      ),
    );
    await Future.wait(List<Future<void>>.of(_spawning));
    _current = null;
  }
}

final class _WorkerJob {
  _WorkerJob(this.identity, this.diveId) {
    receive?.listen(_receive);
  }
  final CalculationIdentity identity;
  final String diveId;
  final receive = usesBrowserWorkers ? null : ReceivePort();
  final completion = Completer<CalculationResult>();
  final progress = StreamController<CalculationStage>.broadcast();
  Timer? timer;
  Isolate? isolate;
  BrowserWorker? browserWorker;
  bool get done => completion.isCompleted;

  void _receive(Object? message) {
    if (done) return;
    if (message == null) {
      fail(
        const WorkerFailure(
          WorkerFailureKind.exited,
          'Calculation isolate exited without a result.',
        ),
      );
      return;
    }
    if (message is List) {
      fail(
        WorkerFailure(
          WorkerFailureKind.unexpected,
          'Calculation isolate failed: ${message.firstOrNull}',
        ),
      );
      return;
    }
    try {
      final json = (message as Map).cast<String, Object?>();
      if (!identity.matches(json)) {
        throw const WorkerFailure(
          WorkerFailureKind.protocol,
          'Calculation response identity or version does not match.',
        );
      }
      switch (json['event']) {
        case 'progress':
          final stage = CalculationStage.values.byName(json['stage'] as String);
          if (stage == CalculationStage.completed) {
            throw const WorkerFailure(
              WorkerFailureKind.protocol,
              'Completion requires a validated calculation result.',
            );
          }
          progress.add(stage);
        case 'result':
          final result = CalculationResult.fromJson(
            (json['result'] as Map).cast<String, Object?>(),
          );
          if (result.diveId != diveId ||
              result.modelVersion != identity.modelVersion) {
            throw const WorkerFailure(
              WorkerFailureKind.protocol,
              'Calculation result model or dive identity does not match.',
            );
          }
          progress.add(CalculationStage.completed);
          completion.complete(result);
          _close();
        case 'failure':
          final core = json['calculationFailure'];
          fail(
            WorkerFailure(
              WorkerFailureKind.values.byName(json['kind'] as String),
              json['message'] as String,
              calculationFailure: core == null
                  ? null
                  : CalculationFailure.fromJson(
                      (core as Map).cast<String, Object?>(),
                    ),
            ),
          );
        default:
          throw const WorkerFailure(
            WorkerFailureKind.protocol,
            'Unknown calculation response event.',
          );
      }
    } catch (error) {
      fail(
        error is WorkerFailure
            ? error
            : const WorkerFailure(
                WorkerFailureKind.protocol,
                'Malformed calculation response.',
              ),
      );
    }
  }

  void fail(WorkerFailure error) {
    if (done) return;
    completion.completeError(error);
    _close();
  }

  void _close() {
    timer?.cancel();
    isolate?.kill(priority: Isolate.immediate);
    browserWorker?.close();
    receive?.close();
    unawaited(progress.close());
  }
}

/// Static isolate boundary. Only explicit JSON inputs cross into the core.
void calculationWorkerEntry(Map<String, Object?> envelope) {
  runCalculationWorker(envelope, (envelope['replyTo'] as SendPort).send);
}

void runCalculationWorker(
  Map<String, Object?> envelope,
  void Function(Map<String, Object?>) reply,
) {
  final identity = <String, Object?>{
    for (final key in [
      'requestId',
      'inputRevision',
      'dependencyVersion',
      'modelVersion',
      'protocolVersion',
    ])
      key: envelope[key],
  };
  void send(Map<String, Object?> event) => reply({...identity, ...event});
  try {
    if (envelope['protocolVersion'] != _protocolVersion ||
        envelope['modelVersion'] != calculationModelVersion) {
      throw const WorkerFailure(
        WorkerFailureKind.protocol,
        'Calculation worker version is incompatible.',
      );
    }
    send({'event': 'progress', 'stage': CalculationStage.starting.name});
    final request = DiveRequest.fromJson(
      (envelope['request'] as Map).cast<String, Object?>(),
    );
    final bailoutJson = envelope['bailout'];
    final bailout = bailoutJson == null
        ? null
        : BailoutRequest.fromJson((bailoutJson as Map).cast<String, Object?>());
    final budget = CalculationBudget(
      maxIterations: envelope['maxIterations'] as int,
      maxElapsed: Duration(
        microseconds: envelope['numericalTimeLimitMicros'] as int,
      ),
    );
    send({'event': 'progress', 'stage': CalculationStage.calculating.name});
    final result = switch ((request.settings.model, bailout)) {
      (DecompressionModel.vpmB, final branch?) => calculateVpmBailout(
        request,
        branch,
        budget: budget,
      ),
      (_, final branch?) => calculateBuhlmannBailout(
        request,
        branch,
        budget: budget,
      ),
      (DecompressionModel.vpmB, null) => calculateVpm(request, budget: budget),
      (_, null) => calculateBuhlmann(request, budget: budget),
    };
    send({'event': 'result', 'result': result.toJson()});
  } on CalculationFailure catch (error) {
    send({
      'event': 'failure',
      'kind': WorkerFailureKind.calculation.name,
      'message': error.message,
      'calculationFailure': error.toJson(),
    });
  } on WorkerFailure catch (error) {
    send({
      'event': 'failure',
      'kind': error.kind.name,
      'message': error.message,
    });
  } catch (error) {
    send({
      'event': 'failure',
      'kind': WorkerFailureKind.unexpected.name,
      'message': 'Calculation failed: $error',
    });
  }
}
