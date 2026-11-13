import 'dart:async';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/services/calculation_worker.dart';
import '../../../data/models/planner_document.dart';

enum PlanStatus { draft, calculating, ready, stale, error }

final class DiveSnapshot {
  const DiveSnapshot({
    this.status = PlanStatus.draft,
    this.result,
    this.failure,
    this.inputRevision = 0,
  });
  final PlanStatus status;
  final CalculationResult? result;
  final WorkerFailure? failure;
  final int inputRevision;
}

final class PlannerViewModel extends ChangeNotifier {
  PlannerViewModel({CalculationWorker? worker})
    : _worker = worker ?? CalculationWorker() {
    _dives.add(_newDive());
  }
  final CalculationWorker _worker;
  final _dives = <DiveRequest>[];
  final _snapshots = <String, DiveSnapshot>{};
  final _dependencies = <String, String>{};
  final _bailouts = <BailoutRequest>[];
  String? _selectedBailoutId;
  int _nextBailoutId = 0;
  int _selected = 0, _nextId = 0, _revision = 0, _generation = 0;
  CalculationHandle? _active;
  bool _closed = false;
  DisplayUnits _units = DisplayUnits.metric;
  ThemeMode _theme = ThemeMode.system;
  List<DiveRequest> get dives => List.unmodifiable(_dives);
  int get selectedIndex => _selected;
  DiveRequest get selected => _dives[_selected];
  DisplayUnits get units => _units;
  ThemeMode get theme => _theme;
  DiveSnapshot get snapshot => snapshotFor(selected.id);
  List<BailoutRequest> get bailouts => List.unmodifiable(_bailouts);
  List<BailoutRequest> get selectedDiveBailouts =>
      List.unmodifiable(_bailouts.where((b) => b.sourceDiveId == selected.id));
  BailoutRequest? get selectedBailout =>
      _bailouts.where((b) => b.id == _selectedBailoutId).firstOrNull;
  DiveSnapshot get displaySnapshot =>
      snapshotFor(_selectedBailoutId ?? selected.id);
  DiveSnapshot snapshotFor(String id) => _snapshots[id] ?? const DiveSnapshot();
  bool get calculating => _active != null;
  final Map<String, String> toolDraft = {
    'oxygen': '21',
    'helium': '0',
    'po2': '1.4',
  };

  int get ratioStops {
    final value = int.tryParse(toolDraft['ratio:stops'] ?? '5');
    return value != null && value > 0 && value <= 10000 ? value : 5;
  }

  void setToolDraft(String key, String value) {
    toolDraft[key] = value;
    notifyListeners();
  }

  PlanRequest get planRequest =>
      PlanRequest(revision: _revision, dives: _dives, bailouts: _bailouts);

  Map<String, StoredCalculation> get storedResults => {
    for (final entry in _snapshots.entries)
      if (entry.value.result != null)
        entry.key: StoredCalculation(
          inputRevision: entry.value.inputRevision,
          dependencyVersion: _dependencies[entry.key] ?? 'initial',
          result: entry.value.result!,
        ),
  };

  void restoreDocument(PlannerDocument document) {
    _cancel();
    _dives
      ..clear()
      ..addAll(document.plan.dives);
    _bailouts
      ..clear()
      ..addAll(document.plan.bailouts);
    _snapshots.clear();
    _dependencies
      ..clear()
      ..addAll(
        document.results.map(
          (id, value) => MapEntry(id, value.dependencyVersion),
        ),
      );
    for (final entry in document.results.entries) {
      _snapshots[entry.key] = DiveSnapshot(
        status: PlanStatus.stale,
        result: entry.value.result,
        inputRevision: entry.value.inputRevision,
      );
    }
    _revision = document.plan.revision;
    _selected = 0;
    _selectedBailoutId = null;
    _units = document.preferences.units;
    _theme = switch (document.preferences.theme) {
      DocumentTheme.system => ThemeMode.system,
      DocumentTheme.light => ThemeMode.light,
      DocumentTheme.dark => ThemeMode.dark,
    };
    toolDraft
      ..clear()
      ..addAll(
        document.toolDrafts['mod'] ??
            {'oxygen': '21', 'helium': '0', 'po2': '1.4'},
      );
    notifyListeners();
  }

  String _nextIdentity(String prefix) {
    final used = {..._dives.map((d) => d.id), ..._bailouts.map((b) => b.id)};
    String id;
    do {
      id = prefix == 'dive'
          ? 'dive-${++_nextId}'
          : 'bailout-${++_nextBailoutId}';
    } while (used.contains(id));
    return id;
  }

  DiveRequest _newDive() => DiveRequest(
    id: _nextIdentity('dive'),
    levels: [
      Level(
        depthMetres: 30,
        durationMin: 20,
        breathing: BreathingGas.oc(Gas(oxygen: .21)),
      ),
    ],
    surfaceIntervalMin: _dives.isEmpty ? 0 : 60,
    settings: _dives.isEmpty
        ? CalculationSettings(
            model: DecompressionModel.buhlmannB,
            pressure: PressureContext(
              surfaceBar: 1.01325,
              waterVapourBar: .0627,
              barPerMetre: .1,
            ),
            stopGrid: StopGrid.metric(),
            gradientFactors: GradientFactors(low: .3, high: .85),
          )
        : selected.settings,
  );

  void select(int index) {
    RangeError.checkValidIndex(index, _dives);
    _selected = index;
    _selectedBailoutId = null;
    notifyListeners();
  }

  void setTheme(ThemeMode theme) {
    _theme = theme;
    notifyListeners();
  }

  void setUnits(DisplayUnits units) {
    _units = units;
    notifyListeners();
  }

  void selectBailout(String? id) {
    if (id != null && !selectedDiveBailouts.any((b) => b.id == id)) {
      throw ArgumentError('Bailout must belong to the selected dive.');
    }
    _selectedBailoutId = id;
    notifyListeners();
  }

  void saveBailout({
    String? id,
    required double runtimeMin,
    required Gas initialOcGas,
    required List<GasSwitch> switches,
  }) {
    if (id == null &&
        !selected.levels.any((l) => l.breathing.mode == BreathingMode.ccr)) {
      throw ArgumentError('Bailout requires a CCR source dive.');
    }
    final existing = id == null ? -1 : _bailouts.indexWhere((b) => b.id == id);
    if (id != null &&
        (existing < 0 || _bailouts[existing].sourceDiveId != selected.id)) {
      throw ArgumentError('Bailout must belong to the selected dive.');
    }
    final branch = BailoutRequest(
      id: id ?? _nextIdentity('bailout'),
      sourceDiveId: selected.id,
      runtimeMin: runtimeMin,
      initialOcGas: initialOcGas,
      switches: switches,
    );
    _cancel();
    if (existing < 0) {
      _bailouts.add(branch);
    } else {
      _bailouts[existing] = branch;
    }
    _revision++;
    _invalidateBailout(branch.id);
    _selectedBailoutId = branch.id;
    notifyListeners();
  }

  void removeSelectedBailout() {
    final id = _selectedBailoutId;
    if (id == null) return;
    _cancel();
    _bailouts.removeWhere((b) => b.id == id);
    _snapshots.remove(id);
    _selectedBailoutId = null;
    _revision++;
    notifyListeners();
  }

  void _invalidateBailout(String id) {
    final old = snapshotFor(id);
    _snapshots[id] = DiveSnapshot(
      status: old.result == null ? PlanStatus.draft : PlanStatus.stale,
      result: old.result,
      inputRevision: old.inputRevision,
    );
  }

  Future<void> calculateSelection() async {
    final branch = selectedBailout;
    if (branch == null) return calculate();
    _cancel();
    final generation = _generation, sourceIndex = _selected;
    final old = snapshotFor(branch.id);
    _snapshots[branch.id] = DiveSnapshot(
      status: PlanStatus.calculating,
      result: old.result,
      inputRevision: _revision,
    );
    notifyListeners();
    await _calculateDives(sourceIndex, generation);
    if (_closed || generation != _generation) return;
    final source = _dives[sourceIndex],
        sourceSnapshot = snapshotFor(branch.sourceDiveId);
    if (sourceSnapshot.status != PlanStatus.ready) {
      _snapshots[branch.id] = DiveSnapshot(
        status: PlanStatus.error,
        result: old.result,
        failure: sourceSnapshot.failure,
        inputRevision: _revision,
      );
      notifyListeners();
      return;
    }
    final request = DiveRequest(
      id: source.id,
      levels: source.levels,
      settings: source.settings,
      switches: source.switches,
      surfaceIntervalMin: source.surfaceIntervalMin,
      initialState: sourceIndex == 0
          ? source.initialState
          : snapshotFor(_dives[sourceIndex - 1].id).result!.finalState,
    );
    final handle = _worker.calculate(
      request,
      bailout: branch,
      inputRevision: _revision,
      dependencyVersion: '${source.id}:${sourceSnapshot.inputRevision}',
    );
    _active = handle;
    notifyListeners();
    try {
      final result = await handle.result;
      if (_closed || generation != _generation) return;
      _dependencies[branch.id] = '${source.id}:${sourceSnapshot.inputRevision}';
      _snapshots[branch.id] = DiveSnapshot(
        status: PlanStatus.ready,
        result: result,
        inputRevision: _revision,
      );
    } on WorkerFailure catch (error) {
      if (_closed || generation != _generation) return;
      _snapshots[branch.id] = DiveSnapshot(
        status: PlanStatus.error,
        result: old.result,
        failure: error,
        inputRevision: _revision,
      );
    }
    if (!_closed && generation == _generation) {
      _active = null;
      notifyListeners();
    }
  }

  void addDive() {
    _cancel();
    _dives.add(_newDive());
    _selected = _dives.length - 1;
    _selectedBailoutId = null;
    _revision++;
    notifyListeners();
  }

  void removeDive() {
    if (_dives.length == 1) return;
    final index = _selected;
    _cancel();
    final removed = _dives.removeAt(index).id;
    _snapshots.remove(removed);
    for (final branch in _bailouts.where((b) => b.sourceDiveId == removed)) {
      _snapshots.remove(branch.id);
    }
    _bailouts.removeWhere((b) => b.sourceDiveId == removed);
    _selectedBailoutId = null;
    if (_selected >= _dives.length) _selected = _dives.length - 1;
    _invalidate(index);
    notifyListeners();
  }

  void moveDive(int delta) {
    final target = _selected + delta;
    if (target < 0 || target >= _dives.length) return;
    final index = _selected;
    _cancel();
    final item = _dives.removeAt(index);
    _dives.insert(target, item);
    _selected = target;
    _invalidate(index < target ? index : target);
    notifyListeners();
  }

  void replaceLevels(List<Level> levels) {
    if (levels.isEmpty) throw ArgumentError('At least one level is required.');
    _replace(
      DiveRequest(
        id: selected.id,
        levels: levels,
        settings: selected.settings,
        switches: selected.switches,
        surfaceIntervalMin: selected.surfaceIntervalMin,
        initialState: selected.initialState,
      ),
    );
  }

  void replaceSettings(CalculationSettings settings) => _replace(
    DiveRequest(
      id: selected.id,
      levels: selected.levels,
      settings: settings,
      switches: selected.switches,
      surfaceIntervalMin: selected.surfaceIntervalMin,
      initialState: selected.initialState,
    ),
  );
  void setSurfaceInterval(double minutes) => _replace(
    DiveRequest(
      id: selected.id,
      levels: selected.levels,
      settings: selected.settings,
      switches: selected.switches,
      surfaceIntervalMin: minutes,
      initialState: selected.initialState,
    ),
  );
  void replaceSwitches(List<GasSwitch> switches) => _replace(
    DiveRequest(
      id: selected.id,
      levels: selected.levels,
      settings: selected.settings,
      switches: switches,
      surfaceIntervalMin: selected.surfaceIntervalMin,
      initialState: selected.initialState,
    ),
  );
  void resetSelected() {
    final original = selected;
    _replace(
      DiveRequest(
        id: original.id,
        levels: [
          Level(
            depthMetres: 30,
            durationMin: 20,
            breathing: BreathingGas.oc(Gas(oxygen: .21)),
          ),
        ],
        settings: original.settings,
        surfaceIntervalMin: original.surfaceIntervalMin,
      ),
    );
  }

  void _replace(DiveRequest value) {
    _cancel();
    _dives[_selected] = value;
    _invalidate(_selected);
    notifyListeners();
  }

  void _invalidate(int from) {
    _revision++;
    for (var i = from; i < _dives.length; i++) {
      final old = snapshotFor(_dives[i].id);
      _snapshots[_dives[i].id] = DiveSnapshot(
        status: old.result == null ? PlanStatus.draft : PlanStatus.stale,
        result: old.result,
        inputRevision: old.inputRevision,
      );
      for (final branch in _bailouts.where(
        (b) => b.sourceDiveId == _dives[i].id,
      )) {
        _invalidateBailout(branch.id);
      }
    }
  }

  void _cancel() {
    _generation++;
    _active?.cancel();
    _active = null;
    for (final entry in _snapshots.entries.toList()) {
      if (entry.value.status == PlanStatus.calculating) {
        _snapshots[entry.key] = DiveSnapshot(
          status: entry.value.result == null
              ? PlanStatus.draft
              : PlanStatus.stale,
          result: entry.value.result,
          inputRevision: entry.value.inputRevision,
        );
      }
    }
  }

  void cancel() {
    _cancel();
    notifyListeners();
  }

  Future<void> calculate() async {
    _cancel();
    await _calculateDives(_selected, _generation);
  }

  Future<void> _calculateDives(int target, int generation) async {
    for (var index = 0; index <= target; index++) {
      final original = _dives[index], old = snapshotFor(_dives[index].id);
      if (old.status == PlanStatus.ready) continue;
      final previous = index == 0 ? null : snapshotFor(_dives[index - 1].id);
      final request = DiveRequest(
        id: original.id,
        levels: original.levels,
        settings: original.settings,
        switches: original.switches,
        surfaceIntervalMin: original.surfaceIntervalMin,
        initialState: index == 0
            ? original.initialState
            : previous!.result!.finalState,
      );
      final handle = _worker.calculate(
        request,
        inputRevision: _revision,
        dependencyVersion: index == 0
            ? 'initial'
            : '${_dives[index - 1].id}:${previous!.inputRevision}',
      );
      _active = handle;
      _snapshots[original.id] = DiveSnapshot(
        status: PlanStatus.calculating,
        result: old.result,
        inputRevision: _revision,
      );
      notifyListeners();
      try {
        final result = await handle.result;
        if (_closed || generation != _generation) return;
        _dependencies[original.id] = index == 0
            ? 'initial'
            : '${_dives[index - 1].id}:${previous!.inputRevision}';
        _snapshots[original.id] = DiveSnapshot(
          status: PlanStatus.ready,
          result: result,
          inputRevision: _revision,
        );
      } on WorkerFailure catch (error) {
        if (_closed || generation != _generation) return;
        _snapshots[original.id] = DiveSnapshot(
          status: PlanStatus.error,
          result: old.result,
          failure: error,
          inputRevision: _revision,
        );
        _selected = index;
        _selectedBailoutId = null;
        _active = null;
        notifyListeners();
        return;
      }
    }
    if (!_closed && generation == _generation) {
      _active = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _cancel();
    unawaited(_worker.dispose());
    super.dispose();
  }
}
