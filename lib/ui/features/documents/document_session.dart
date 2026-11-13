import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/models/planner_document.dart';
import '../../../data/repositories/document_repository.dart';
import '../plan/planner_view_model.dart';

/// Owns document transitions; calculation state remains in the planner model.
final class DocumentSession extends ChangeNotifier {
  DocumentSession({
    required this.model,
    required this.repository,
    this.autosaveDelay = const Duration(milliseconds: 600),
  }) {
    _document = _newDocument();
    _saved = '';
    model.addListener(_changed);
  }
  final PlannerViewModel model;
  final DocumentRepository repository;
  final Duration autosaveDelay;
  late PlannerDocument _document;
  late String _saved;
  Timer? _timer;
  final _knownProfiles = <String, ComparisonSnapshot>{};
  bool _restoring = false, _closed = false, _busy = false;
  Future<void> _tail = Future.value();
  DocumentFailure? failure;
  bool recoveredFromBackup = false;
  PlannerDocument get document => _document;
  bool get busy => _busy;
  bool get dirty => jsonEncode(_capture().toJson()) != _saved;

  static String _id() =>
      'plan-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  PlannerPreferences get _preferences => PlannerPreferences(
    units: model.units,
    theme: switch (model.theme) {
      ThemeMode.system => DocumentTheme.system,
      ThemeMode.light => DocumentTheme.light,
      ThemeMode.dark => DocumentTheme.dark,
    },
    textScale: _document.preferences.textScale,
  );

  PlannerDocument _newDocument() {
    final now = DateTime.now().toUtc();
    return PlannerDocument(
      id: _id(),
      name: 'Новый план',
      createdAt: now,
      modifiedAt: now,
      plan: model.planRequest,
    );
  }

  PlannerDocument _capture() {
    final results = model.storedResults;
    final upgrading =
        !_document.usesCurrentModel &&
        results.values.any(
          (r) => r.result.modelVersion == calculationModelVersion,
        );
    final version = upgrading
        ? calculationModelVersion
        : _document.modelVersion;
    final comparisons = [..._document.comparisons];
    if (upgrading && _document.results.isNotEmpty) {
      comparisons.add(
        ComparisonSnapshot(
          id: _id(),
          name: '${_document.name} — предыдущая модель',
          capturedAt: DateTime.now().toUtc(),
          plan: _document.plan,
          results: _document.results,
          modelVersion: _document.modelVersion,
        ),
      );
    }
    return PlannerDocument(
      id: _document.id,
      name: _document.name,
      createdAt: _document.createdAt,
      modifiedAt: _document.modifiedAt,
      plan: model.planRequest,
      modelVersion: version,
      preferences: _preferences,
      gases: _document.gases,
      gasSets: _document.gasSets,
      tanks: _document.tanks,
      settingsPresets: _document.settingsPresets,
      comparisons: comparisons,
      results: Map.fromEntries(
        results.entries.where((e) => e.value.result.modelVersion == version),
      ),
      toolDrafts: {
        ..._document.toolDrafts,
        'mod': {...model.toolDraft},
      },
    );
  }

  void _changed() {
    if (_restoring || _closed) return;
    final previous = <ComparisonSnapshot>[];
    final results = model.storedResults;
    _knownProfiles.removeWhere((id, _) => !results.containsKey(id));
    for (final entry in results.entries) {
      if (model.snapshotFor(entry.key).status != PlanStatus.ready) continue;
      final known = _knownProfiles[entry.key];
      if (identical(known?.results[entry.key]?.result, entry.value.result)) {
        continue;
      }
      if (known != null && model.toolDraft['profile:keepPrevious'] == 'true') {
        previous.add(known);
      }
      _knownProfiles[entry.key] = ComparisonSnapshot(
        id: _id(),
        name: '${entry.key} — предыдущий профиль',
        capturedAt: DateTime.now().toUtc(),
        plan: model.planRequest,
        results: {entry.key: entry.value},
      );
    }
    if (previous.isNotEmpty) {
      _document = _document.copyWith(
        comparisons: [
          ..._document.comparisons.where(
            (saved) => !previous.any((value) => value.id == saved.id),
          ),
          ...previous,
        ],
      );
    }
    _timer?.cancel();
    if (dirty) {
      _timer = Timer(autosaveDelay, () => unawaited(save()));
    }
    notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final completion = Completer<T>();
    _tail = _tail.then((_) async {
      _busy = true;
      if (!_closed) notifyListeners();
      try {
        completion.complete(await operation());
      } catch (error, stack) {
        completion.completeError(error, stack);
      } finally {
        _busy = false;
        if (!_closed) notifyListeners();
      }
    });
    return completion.future;
  }

  Future<bool> _save() async {
    _timer?.cancel();
    final sourceDocument = _document;
    final snapshot = _capture();
    final signature = jsonEncode(snapshot.toJson());
    if (signature == _saved) return true;
    final now = DateTime.now().toUtc();
    final stamped = snapshot.copyWith(
      modifiedAt: now.isBefore(snapshot.createdAt) ? snapshot.createdAt : now,
    );
    try {
      await repository.save(stamped);
      // Edits during disk I/O remain in the model and are saved by the next job.
      // Catalog/comparison edits may arrive while the disk write is awaiting.
      // Keep those edits in memory; the queued save will publish them next.
      _document = identical(_document, sourceDocument)
          ? stamped
          : _document.copyWith(modifiedAt: stamped.modifiedAt);
      _saved = jsonEncode(stamped.toJson());
      failure = null;
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  }

  Future<void> initialize() => _serial(() async {
    try {
      final entries = await repository.list();
      if (_closed) return;
      final available = entries.where((e) => e.loaded != null).toList()
        ..sort(
          (a, b) => b.loaded!.document.modifiedAt.compareTo(
            a.loaded!.document.modifiedAt,
          ),
        );
      if (available.isNotEmpty) _restore(available.first.loaded!);
      final damaged = entries.where((e) => e.failure != null).firstOrNull;
      if (damaged != null) failure = damaged.failure;
    } on DocumentFailure catch (error) {
      failure = error;
    }
  });

  void saveComparison(ComparisonSnapshot snapshot) {
    final captured = _capture();
    _document = captured.copyWith(
      comparisons: [
        ...captured.comparisons.where((value) => value.id != snapshot.id),
        snapshot,
      ],
    );
    _changed();
  }

  void clearComparisons() {
    _document = _capture().copyWith(comparisons: []);
    _changed();
  }

  ComparisonSnapshot? knownProfile(String id) => _knownProfiles[id];

  void prepareProfileReset() {
    if (model.toolDraft['profile:keepComparisonsOnReset'] == 'false') {
      clearComparisons();
      _knownProfiles.clear();
    } else {
      final known = _knownProfiles[model.selected.id];
      if (known != null) saveComparison(known);
    }
  }

  void saveGasSet(GasSetPreset value) {
    _document = _document.copyWith(
      gasSets: [
        ..._document.gasSets.where((preset) => preset.id != value.id),
        value,
      ],
    );
    _changed();
  }

  void deleteGasSet(String id) {
    _document = _document.copyWith(
      gasSets: _document.gasSets.where((preset) => preset.id != id),
    );
    _changed();
  }

  void saveTank(TankPreset value) {
    _document = _document.copyWith(
      tanks: [
        ..._document.tanks.where((preset) => preset.id != value.id),
        value,
      ],
    );
    _changed();
  }

  void deleteTank(String id) {
    _document = _document.copyWith(
      tanks: _document.tanks.where((preset) => preset.id != id),
    );
    _changed();
  }

  CalculationSettings? get defaultSettings => _document.settingsPresets
      .where((preset) => preset.id == 'default-settings')
      .firstOrNull
      ?.settings;

  void saveDefaultSettings(CalculationSettings settings, {int ratioStops = 5}) {
    _document = _document.copyWith(
      settingsPresets: [
        ..._document.settingsPresets.where(
          (preset) => preset.id != 'default-settings',
        ),
        SettingsPreset(
          id: 'default-settings',
          name: 'Настройки новых планов',
          ratioStops: ratioStops,
          settings: settings,
        ),
      ],
    );
    _changed();
  }

  PlannerViewModel _defaultModel() {
    final value = PlannerViewModel();
    final settings = defaultSettings;
    if (settings != null) {
      value.replaceSettings(settings);
      final preset = _document.settingsPresets.firstWhere(
        (p) => p.id == 'default-settings',
      );
      value.setToolDraft('ratio:stops', preset.ratioStops.toString());
    }
    return value;
  }

  Future<bool> save() => _serial(_save);
  Future<List<DocumentEntry>> list() => repository.list();

  void _restore(LoadedDocument loaded) {
    _restoring = true;
    try {
      _knownProfiles.clear();
      _document = loaded.document;
      model.restoreDocument(_document);
      _saved = jsonEncode(_capture().toJson());
      recoveredFromBackup = loaded.recoveredFromBackup;
      failure = null;
    } finally {
      _restoring = false;
    }
  }

  Future<bool> open(String id) => _serial(() async {
    try {
      if (id == _document.id) return _save();
      final loaded = await repository.load(id);
      if (!await _save()) return false;
      _timer?.cancel();
      _restore(loaded);
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  });

  Future<bool> create() => _serial(() async {
    if (!await _save()) return false;
    final defaults = _defaultModel();
    final next = _newDocument().copyWith(
      plan: defaults.planRequest,
      gases: _document.gases,
      gasSets: _document.gasSets,
      tanks: _document.tanks,
      settingsPresets: _document.settingsPresets,
      preferences: _preferences,
      results: {},
      toolDrafts: {
        'mod': {...defaults.toolDraft},
      },
    );
    defaults.dispose();
    try {
      await repository.save(next);
      _restore(LoadedDocument(next));
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  });

  Future<bool> rename(String id, String name) => _serial(() async {
    try {
      if (id == _document.id) {
        final renamed = _document.copyWith(name: name);
        _document = renamed;
        return _save();
      }
      await repository.rename(id, name);
      failure = null;
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  });

  Future<bool> delete(String id) => _serial(() async {
    try {
      await repository.delete(id);
      if (id == _document.id) {
        _timer?.cancel();
        final defaults = _defaultModel();
        final next = _newDocument().copyWith(
          plan: defaults.planRequest,
          gases: _document.gases,
          gasSets: _document.gasSets,
          tanks: _document.tanks,
          settingsPresets: _document.settingsPresets,
          preferences: _preferences,
          results: {},
          toolDrafts: {
            'mod': {...defaults.toolDraft},
          },
        );
        defaults.dispose();
        _restore(LoadedDocument(next));
        _saved = '';
      }
      failure = null;
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  });

  /// Import creates a new identity; a shared file never overwrites a local plan.
  Future<bool> importBytes(Uint8List bytes) => _serial(() async {
    try {
      final decoded = await _decodeImported(bytes);
      final imported = decoded.copyWith(id: _id());
      if (!await _save()) return false;
      await repository.save(imported);
      _timer?.cancel();
      _restore(LoadedDocument(imported));
      return true;
    } on DocumentFailure catch (error) {
      failure = error;
      return false;
    }
  });

  Future<Uint8List> exportBytes() => _encodeExport(_capture());

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    model.removeListener(_changed);
    super.dispose();
  }
}

Future<PlannerDocument> _decodeImported(Uint8List bytes) =>
    Isolate.run(() => decodePlannerDocument(bytes));

Future<Uint8List> _encodeExport(PlannerDocument document) =>
    Isolate.run(() => encodePlannerDocument(document));
