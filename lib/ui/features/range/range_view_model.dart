import 'dart:async';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/calculation_worker.dart';
import '../../../data/services/range_worker.dart';

enum RangeStatus { draft, calculating, complete, cancelled, stale, error }

final class RangeViewModel extends ChangeNotifier {
  RangeViewModel({RangeWorker? worker}) : _worker = worker ?? RangeWorker();
  final RangeWorker _worker;
  final _cells = <RangeSummary>[];
  List<RangeSummary> get cells => List.unmodifiable(_cells);
  RangeStatus status = RangeStatus.draft;
  WorkerFailure? failure;
  int total = 0, inputRevision = 0, _generation = 0;
  bool inputsCurrent = false, _closed = false;
  RangeHandle? _active;
  StreamSubscription<RangeSummary>? _subscription;
  RangeAxis? depths, durations;
  List<RangeVariant> variants = const [];
  void invalidate() {
    _generation++;
    _active?.cancel();
    _active = null;
    inputsCurrent = false;
    status = _cells.isEmpty ? RangeStatus.draft : RangeStatus.stale;
    failure = null;
    if (!_closed) notifyListeners();
  }

  void cancel() {
    if (_active == null) return;
    _generation++;
    _active!.cancel();
    _active = null;
    status = RangeStatus.cancelled;
    if (!_closed) notifyListeners();
  }

  Future<void> calculate({
    required DiveRequest source,
    required RangeAxis depths,
    required RangeAxis durations,
    required List<RangeVariant> variants,
    required int inputRevision,
    required String dependencyVersion,
    BailoutRequest? bailout,
  }) async {
    if (_closed) return;
    invalidate();
    unawaited(_subscription?.cancel());
    final generation = ++_generation;
    this.depths = depths;
    this.durations = durations;
    this.variants = List.unmodifiable(variants.toSet());
    this.inputRevision = inputRevision;
    total = depths.length * durations.length * this.variants.length;
    _cells.clear();
    if (total <= 0 ||
        total > 1000 ||
        inputRevision < 0 ||
        dependencyVersion.isEmpty) {
      failure = const WorkerFailure(
        WorkerFailureKind.calculation,
        'Invalid range request or limits.',
        calculationFailure: CalculationFailure(
          CalculationFailureCode.invalidInput,
          'Choose 1–1000 cells and valid request identity.',
        ),
      );
      status = RangeStatus.error;
      inputsCurrent = false;
      notifyListeners();
      return;
    }
    status = RangeStatus.calculating;
    inputsCurrent = true;
    final handle = _worker.calculate(
      source: source,
      depths: depths,
      durations: durations,
      variants: this.variants,
      inputRevision: inputRevision,
      dependencyVersion: dependencyVersion,
      bailout: bailout,
    );
    _active = handle;
    _subscription = handle.cells.listen((cell) {
      if (!_closed && generation == _generation) {
        _cells.add(cell);
        notifyListeners();
      }
    });
    notifyListeners();
    try {
      await handle.done;
      if (_closed || generation != _generation) return;
      status = RangeStatus.complete;
    } on WorkerFailure catch (error) {
      if (_closed || generation != _generation) return;
      failure = error;
      status = error.kind == WorkerFailureKind.cancelled
          ? RangeStatus.cancelled
          : RangeStatus.error;
    }
    if (!_closed && generation == _generation) {
      _active = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _worker.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
