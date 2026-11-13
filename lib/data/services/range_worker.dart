import 'dart:async';
import 'dart:isolate';
import 'package:deco_core/deco_core.dart';
import 'calculation_worker.dart';

final class RangeSummary {
  const RangeSummary({
    required this.request,
    required this.bailout,
    required this.depthMetres,
    required this.durationMin,
    required this.variant,
    this.runtimeMin,
    this.ascentMin,
    this.decompressionMin,
    this.firstStopMetres,
    this.failure,
  });
  final DiveRequest request;
  final BailoutRequest? bailout;
  final double depthMetres, durationMin;
  final RangeVariant variant;
  final double? runtimeMin, ascentMin, decompressionMin, firstStopMetres;
  final CalculationFailure? failure;
}

final class RangeHandle {
  const RangeHandle(this.cells, this.done, this.cancel);
  final Stream<RangeSummary> cells;
  final Future<void> done;
  final void Function() cancel;
}

/// Cells are acknowledged one at a time; full tissue traces remain in the
/// worker. Opening a cell recalculates its exact captured request separately.
final class RangeWorker {
  RangeWorker({this.entryPoint = rangeWorkerEntry});
  final void Function(Map<String, Object?>) entryPoint;
  void Function()? _cancel;
  int _nextId = 0;
  bool _closed = false;
  RangeHandle calculate({
    required DiveRequest source,
    required RangeAxis depths,
    required RangeAxis durations,
    required List<RangeVariant> variants,
    required int inputRevision,
    required String dependencyVersion,
    BailoutRequest? bailout,
    Duration timeout = const Duration(seconds: 65),
  }) {
    if (_closed) throw StateError('Range worker is disposed.');
    final count = depths.length * durations.length * variants.toSet().length;
    if (count <= 0 ||
        count > 1000 ||
        inputRevision < 0 ||
        dependencyVersion.isEmpty ||
        timeout.isNegative) {
      throw ArgumentError('Invalid range request or limits.');
    }
    _cancel?.call();
    final identity = CalculationIdentity(
      requestId: ++_nextId,
      inputRevision: inputRevision,
      dependencyVersion: dependencyVersion,
    );
    final messages = ReceivePort(),
        errors = ReceivePort(),
        exits = ReceivePort();
    final stream = StreamController<RangeSummary>();
    final completion = Completer<void>();
    Isolate? isolate;
    Timer? timer;
    var finished = false, received = 0;
    void finish([WorkerFailure? failure]) {
      if (finished) return;
      finished = true;
      timer?.cancel();
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
      unawaited(stream.close());
      if (failure == null) {
        completion.complete();
      } else {
        completion.completeError(failure);
      }
    }

    void cancel() => finish(
      const WorkerFailure(WorkerFailureKind.cancelled, 'Range cancelled.'),
    );
    _cancel = cancel;
    timer = Timer(
      timeout,
      () => finish(
        const WorkerFailure(
          WorkerFailureKind.timeout,
          'Range time limit exceeded.',
        ),
      ),
    );
    messages.listen((message) {
      try {
        if (finished) return;
        if (message is! Map ||
            message['identity'] is! Map ||
            !identity.matches(
              Map<String, Object?>.from(message['identity'] as Map),
            )) {
          finish(
            const WorkerFailure(
              WorkerFailureKind.protocol,
              'Range identity mismatch.',
            ),
          );
          return;
        }
        if (message['failure'] case final CalculationFailure failure) {
          finish(
            WorkerFailure(
              WorkerFailureKind.calculation,
              'Range numerical budget/domain failure.',
              calculationFailure: failure,
            ),
          );
          return;
        }
        if (message['done'] == true) {
          if (received != count) {
            finish(
              const WorkerFailure(
                WorkerFailureKind.protocol,
                'Incomplete range response.',
              ),
            );
          } else {
            finish();
          }
          return;
        }
        if (message['cell'] case final RangeSummary cell) {
          final ack = message['ack'];
          final selected = variants.toSet().toList();
          final depthIndex = received ~/ (durations.length * selected.length);
          final timeIndex = (received ~/ selected.length) % durations.length;
          final variantIndex = received % selected.length;
          final metrics = [
            cell.runtimeMin,
            cell.ascentMin,
            cell.decompressionMin,
            cell.firstStopMetres,
          ];
          if (ack is! SendPort ||
              received >= count ||
              cell.variant != selected[variantIndex] ||
              cell.depthMetres != depths.at(depthIndex) ||
              cell.durationMin != durations.at(timeIndex) ||
              cell.request.id != source.id ||
              cell.bailout?.id != bailout?.id ||
              (cell.failure == null
                  ? metrics.any(
                      (value) => value == null || !value.isFinite || value < 0,
                    )
                  : metrics.any((value) => value != null))) {
            finish(
              const WorkerFailure(
                WorkerFailureKind.protocol,
                'Invalid range cell.',
              ),
            );
            return;
          }
          received++;
          stream.add(cell);
          ack.send(true);
        } else {
          finish(
            const WorkerFailure(
              WorkerFailureKind.protocol,
              'Malformed range response.',
            ),
          );
        }
      } catch (_) {
        finish(
          const WorkerFailure(
            WorkerFailureKind.protocol,
            'Malformed range payload.',
          ),
        );
      }
    });
    errors.listen(
      (_) => finish(
        const WorkerFailure(
          WorkerFailureKind.unexpected,
          'Range isolate error.',
        ),
      ),
    );
    exits.listen((_) {
      // Terminal message is sent before exit; allow the receive queue to drain.
      Timer.run(
        () => finish(
          const WorkerFailure(
            WorkerFailureKind.exited,
            'Range worker exited before completion.',
          ),
        ),
      );
    });
    unawaited(
      Isolate.spawn(
        entryPoint,
        {
          'send': messages.sendPort,
          'identity': identity.toJson(),
          'source': source,
          'bailout': bailout,
          'depths': depths,
          'durations': durations,
          'variants': List<RangeVariant>.unmodifiable(variants),
        },
        onError: errors.sendPort,
        onExit: exits.sendPort,
        errorsAreFatal: true,
        debugName: 'range-planner',
      ).then(
        (value) {
          isolate = value;
          if (finished) value.kill(priority: Isolate.immediate);
        },
        onError: (Object _, StackTrace _) => finish(
          const WorkerFailure(
            WorkerFailureKind.unexpected,
            'Cannot start range isolate.',
          ),
        ),
      ),
    );
    return RangeHandle(stream.stream, completion.future, cancel);
  }

  void dispose() {
    _closed = true;
    _cancel?.call();
  }
}

void rangeWorkerEntry(Map<String, Object?> message) async {
  final send = message['send'] as SendPort, identity = message['identity'];
  final ack = ReceivePort();
  final iterator = StreamIterator<Object?>(ack);
  try {
    for (final cell in calculateRange(
      source: message['source'] as DiveRequest,
      bailout: message['bailout'] as BailoutRequest?,
      depths: message['depths'] as RangeAxis,
      durations: message['durations'] as RangeAxis,
      variants: message['variants'] as List<RangeVariant>,
      budget: CalculationBudget(
        maxIterations: 5000000,
        maxElapsed: const Duration(seconds: 60),
      ),
    )) {
      final result = cell.result;
      send.send({
        'identity': identity,
        'ack': ack.sendPort,
        'cell': RangeSummary(
          request: cell.request,
          bailout: cell.bailout,
          depthMetres: cell.depthMetres,
          durationMin: cell.durationMin,
          variant: cell.variant,
          runtimeMin: result?.runtimeMin,
          ascentMin: result?.ascentMin,
          decompressionMin: result?.decompressionMin,
          firstStopMetres: result?.firstStopMetres,
          failure: cell.failure,
        ),
      });
      if (!await iterator.moveNext()) return;
    }
    send.send({'identity': identity, 'done': true});
  } on CalculationFailure catch (error) {
    send.send({'identity': identity, 'failure': error});
  } finally {
    await iterator.cancel();
    ack.close();
  }
}
