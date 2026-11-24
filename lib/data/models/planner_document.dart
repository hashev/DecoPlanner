import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:deco_core/deco_core.dart';

const plannerDocumentSchema = 1;
const maximumDocumentBytes = 32 * 1024 * 1024;

enum DocumentFailureKind {
  invalidDocument,
  unsupportedSchema,
  tooLarge,
  integrity,
  notFound,
  io,
}

final class DocumentFailure implements Exception {
  const DocumentFailure(this.kind, this.message);
  final DocumentFailureKind kind;
  final String message;
  @override
  String toString() => 'DocumentFailure(${kind.name}): $message';
}

bool validDocumentId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$').stringMatch(value) == value;

Never _invalid(String field) => throw DocumentFailure(
  DocumentFailureKind.invalidDocument,
  'Invalid document field: $field.',
);
Map<String, Object?> _map(Object? value, String field) =>
    value is Map<String, Object?> ? value : _invalid(field);
List<Object?> _list(Object? value, String field) =>
    value is List<Object?> ? value : _invalid(field);
String _string(Object? value, String field) =>
    value is String && value.isNotEmpty ? value : _invalid(field);
String _id(Object? value) {
  final result = _string(value, 'id');
  if (!validDocumentId(result)) _invalid('id');
  return result;
}

void _label(String value) {
  if (value.trim().isEmpty || value.length > 160) _invalid('name');
}

int _revision(Object? value) =>
    value is int && value >= 0 ? value : _invalid('inputRevision');
double _number(Object? value, String field) =>
    value is num && value.isFinite ? value.toDouble() : _invalid(field);
T _enum<T extends Enum>(Object? value, List<T> options, String field) =>
    options.where((o) => o.name == value).firstOrNull ?? _invalid(field);
DateTime _date(Object? value, String field) {
  final text = _string(value, field);
  if (!RegExp(
    r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$',
  ).hasMatch(text)) {
    _invalid(field);
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      parsed.toIso8601String().substring(0, 19) != text.substring(0, 19)) {
    _invalid(field);
  }
  return parsed;
}

PlanRequest _plan(Object? value, String version) {
  final raw = _map(value, 'plan');
  if (raw['modelVersion'] != version) _invalid('plan.modelVersion');
  // Schema1 physical inputs remain readable after an engine-version change.
  // The original version stays on the document; cached outputs remain stale.
  return PlanRequest.fromJson({
    ...raw,
    'modelVersion': calculationModelVersion,
  });
}

void _unique(Iterable<String> ids, String field) {
  final list = ids.toList();
  if (list.toSet().length != list.length) _invalid(field);
}

enum DocumentTheme { system, light, dark }

final class PlannerPreferences {
  PlannerPreferences({
    this.units = DisplayUnits.metric,
    this.theme = DocumentTheme.system,
    this.textScale = 1,
  }) {
    if (!textScale.isFinite || textScale < .5 || textScale > 3) {
      _invalid('textScale');
    }
  }
  final DisplayUnits units;
  final DocumentTheme theme;
  final double textScale;
  Map<String, Object?> toJson() => {
    'units': units.name,
    'theme': theme.name,
    'textScale': textScale,
  };
  factory PlannerPreferences.fromJson(Map<String, Object?> json) =>
      PlannerPreferences(
        units: _enum(json['units'], DisplayUnits.values, 'units'),
        theme: _enum(json['theme'], DocumentTheme.values, 'theme'),
        textScale: _number(json['textScale'], 'textScale'),
      );
}

final class GasPreset {
  GasPreset({required this.id, required this.name, required this.gas}) {
    _id(id);
    _label(name);
  }
  final String id, name;
  final Gas gas;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'gas': gas.toJson(),
  };
  factory GasPreset.fromJson(Map<String, Object?> json) => GasPreset(
    id: _id(json['id']),
    name: _string(json['name'], 'name'),
    gas: Gas.fromJson(_map(json['gas'], 'gas')),
  );
}

final class GasSetPreset {
  GasSetPreset({
    required this.id,
    required this.name,
    required Iterable<GasSwitch> switches,
  }) : switches = List.unmodifiable(switches) {
    _id(id);
    _label(name);
  }
  final String id, name;
  final List<GasSwitch> switches;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'switches': switches.map((s) => s.toJson()).toList(),
  };
  factory GasSetPreset.fromJson(Map<String, Object?> json) => GasSetPreset(
    id: _id(json['id']),
    name: _string(json['name'], 'name'),
    switches: _list(
      json['switches'],
      'switches',
    ).map((s) => GasSwitch.fromJson(_map(s, 'switch'))),
  );
}

final class TankPreset {
  TankPreset({
    required this.id,
    required this.name,
    required this.waterLitres,
    required this.workingBar,
  }) {
    _id(id);
    _label(name);
    CylinderCapacity(waterLitres: waterLitres, workingBar: workingBar);
  }
  final String id, name;
  final double waterLitres, workingBar;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'waterLitres': waterLitres,
    'workingBar': workingBar,
  };
  factory TankPreset.fromJson(Map<String, Object?> json) => TankPreset(
    id: _id(json['id']),
    name: _string(json['name'], 'name'),
    waterLitres: _number(json['waterLitres'], 'waterLitres'),
    workingBar: _number(json['workingBar'], 'workingBar'),
  );
}

final class SettingsPreset {
  SettingsPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.ratioStops = 5,
  }) {
    _id(id);
    _label(name);
    if (ratioStops <= 0 || ratioStops > 10000) _invalid('ratioStops');
  }
  final String id, name;
  final CalculationSettings settings;
  final int ratioStops;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
    'ratioStops': ratioStops,
  };
  factory SettingsPreset.fromJson(Map<String, Object?> json) => SettingsPreset(
    id: _id(json['id']),
    name: _string(json['name'], 'name'),
    settings: CalculationSettings.fromJson(_map(json['settings'], 'settings')),
    ratioStops: _revision(json['ratioStops'] ?? 5),
  );
}

final class StoredCalculation {
  StoredCalculation({
    required this.inputRevision,
    required this.dependencyVersion,
    required this.result,
  }) {
    _revision(inputRevision);
    _string(dependencyVersion, 'dependencyVersion');
  }
  final int inputRevision;
  final String dependencyVersion;
  final CalculationResult result;
  Map<String, Object?> toJson() => {
    'inputRevision': inputRevision,
    'dependencyVersion': dependencyVersion,
    'result': result.toJson(),
  };
  factory StoredCalculation.fromJson(Map<String, Object?> json) =>
      StoredCalculation(
        inputRevision: _revision(json['inputRevision']),
        dependencyVersion: _string(
          json['dependencyVersion'],
          'dependencyVersion',
        ),
        result: CalculationResult.fromJson(_map(json['result'], 'result')),
      );
}

Map<String, StoredCalculation> _results(Object? value) =>
    _map(value, 'results').map(
      (key, v) =>
          MapEntry(key, StoredCalculation.fromJson(_map(v, 'result snapshot'))),
    );
void _checkResults(
  PlanRequest plan,
  String version,
  Map<String, StoredCalculation> results,
) {
  final ids = {
    ...plan.dives.map((d) => d.id),
    ...plan.bailouts.map((b) => b.id),
  };
  for (final entry in results.entries) {
    if (!ids.contains(entry.key) ||
        entry.value.result.diveId != entry.key ||
        entry.value.result.modelVersion != version ||
        entry.value.inputRevision > plan.revision) {
      _invalid('results identity/modelVersion');
    }
  }
}

final class ComparisonSnapshot {
  ComparisonSnapshot({
    required this.id,
    required this.name,
    required DateTime capturedAt,
    required this.plan,
    required Map<String, StoredCalculation> results,
    this.modelVersion = calculationModelVersion,
  }) : capturedAt = capturedAt.toUtc(),
       results = Map.unmodifiable(results) {
    _id(id);
    _label(name);
    _string(modelVersion, 'modelVersion');
    _checkResults(plan, modelVersion, this.results);
  }
  final String id, name, modelVersion;
  final DateTime capturedAt;
  final PlanRequest plan;
  final Map<String, StoredCalculation> results;
  bool get usesCurrentModel => modelVersion == calculationModelVersion;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'capturedAt': capturedAt.toIso8601String(),
    'modelVersion': modelVersion,
    'plan': {...plan.toJson(), 'modelVersion': modelVersion},
    'results': results.map((id, value) => MapEntry(id, value.toJson())),
  };
  factory ComparisonSnapshot.fromJson(Map<String, Object?> json) {
    final version = _string(json['modelVersion'], 'modelVersion');
    return ComparisonSnapshot(
      id: _id(json['id']),
      name: _string(json['name'], 'name'),
      capturedAt: _date(json['capturedAt'], 'capturedAt'),
      modelVersion: version,
      plan: _plan(json['plan'], version),
      results: _results(json['results']),
    );
  }
}

final class PlannerDocument {
  PlannerDocument({
    required this.id,
    required this.name,
    required DateTime createdAt,
    required DateTime modifiedAt,
    required this.plan,
    this.modelVersion = calculationModelVersion,
    PlannerPreferences? preferences,
    Iterable<GasPreset> gases = const [],
    Iterable<GasSetPreset> gasSets = const [],
    Iterable<TankPreset> tanks = const [],
    Iterable<SettingsPreset> settingsPresets = const [],
    Iterable<ComparisonSnapshot> comparisons = const [],
    Map<String, StoredCalculation> results = const {},
    Map<String, Map<String, String>> toolDrafts = const {},
  }) : createdAt = createdAt.toUtc(),
       modifiedAt = modifiedAt.toUtc(),
       preferences = preferences ?? PlannerPreferences(),
       gases = List.unmodifiable(gases),
       gasSets = List.unmodifiable(gasSets),
       tanks = List.unmodifiable(tanks),
       settingsPresets = List.unmodifiable(settingsPresets),
       comparisons = List.unmodifiable(comparisons),
       results = Map.unmodifiable(results),
       toolDrafts = Map.unmodifiable(
         toolDrafts.map(
           (key, fields) =>
               MapEntry(key, Map<String, String>.unmodifiable(fields)),
         ),
       ) {
    _id(id);
    _label(name);
    _string(modelVersion, 'modelVersion');
    if (this.modifiedAt.isBefore(this.createdAt)) _invalid('modifiedAt');
    _unique(this.gases.map((g) => g.id), 'gases');
    _unique(this.gasSets.map((g) => g.id), 'gasSets');
    _unique(this.tanks.map((t) => t.id), 'tanks');
    _unique(this.settingsPresets.map((s) => s.id), 'settingsPresets');
    _unique(this.comparisons.map((c) => c.id), 'comparisons');
    _checkResults(plan, modelVersion, this.results);
    for (final entry in this.toolDrafts.entries) {
      _string(entry.key, 'tool name');
      for (final key in entry.value.keys) {
        _string(key, 'draft field');
      }
    }
  }
  final String id, name, modelVersion;
  final DateTime createdAt, modifiedAt;
  final PlanRequest plan;
  final PlannerPreferences preferences;
  final List<GasPreset> gases;
  final List<GasSetPreset> gasSets;
  final List<TankPreset> tanks;
  final List<SettingsPreset> settingsPresets;
  final List<ComparisonSnapshot> comparisons;
  final Map<String, StoredCalculation> results;
  final Map<String, Map<String, String>> toolDrafts;
  bool get usesCurrentModel => modelVersion == calculationModelVersion;

  PlannerDocument copyWith({
    String? id,
    String? name,
    DateTime? modifiedAt,
    PlanRequest? plan,
    String? modelVersion,
    PlannerPreferences? preferences,
    Iterable<GasPreset>? gases,
    Iterable<GasSetPreset>? gasSets,
    Iterable<TankPreset>? tanks,
    Iterable<SettingsPreset>? settingsPresets,
    Iterable<ComparisonSnapshot>? comparisons,
    Map<String, StoredCalculation>? results,
    Map<String, Map<String, String>>? toolDrafts,
  }) => PlannerDocument(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    plan: plan ?? this.plan,
    modelVersion: modelVersion ?? this.modelVersion,
    preferences: preferences ?? this.preferences,
    gases: gases ?? this.gases,
    gasSets: gasSets ?? this.gasSets,
    tanks: tanks ?? this.tanks,
    settingsPresets: settingsPresets ?? this.settingsPresets,
    comparisons: comparisons ?? this.comparisons,
    results: results ?? this.results,
    toolDrafts: toolDrafts ?? this.toolDrafts,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'modelVersion': modelVersion,
    'plan': {...plan.toJson(), 'modelVersion': modelVersion},
    'preferences': preferences.toJson(),
    'gases': gases.map((g) => g.toJson()).toList(),
    'gasSets': gasSets.map((g) => g.toJson()).toList(),
    'tanks': tanks.map((t) => t.toJson()).toList(),
    'settingsPresets': settingsPresets.map((s) => s.toJson()).toList(),
    'comparisons': comparisons.map((c) => c.toJson()).toList(),
    'results': results.map((id, value) => MapEntry(id, value.toJson())),
    'toolDrafts': toolDrafts,
  };
  factory PlannerDocument.fromJson(Map<String, Object?> json) {
    final version = _string(json['modelVersion'], 'modelVersion');
    return PlannerDocument(
      id: _id(json['id']),
      name: _string(json['name'], 'name'),
      createdAt: _date(json['createdAt'], 'createdAt'),
      modifiedAt: _date(json['modifiedAt'], 'modifiedAt'),
      modelVersion: version,
      plan: _plan(json['plan'], version),
      preferences: PlannerPreferences.fromJson(
        _map(json['preferences'], 'preferences'),
      ),
      gases: _list(
        json['gases'],
        'gases',
      ).map((g) => GasPreset.fromJson(_map(g, 'gas preset'))),
      gasSets: _list(
        json['gasSets'] ?? const [],
        'gasSets',
      ).map((g) => GasSetPreset.fromJson(_map(g, 'gas set'))),
      tanks: _list(
        json['tanks'],
        'tanks',
      ).map((t) => TankPreset.fromJson(_map(t, 'tank preset'))),
      settingsPresets: _list(
        json['settingsPresets'],
        'settingsPresets',
      ).map((s) => SettingsPreset.fromJson(_map(s, 'settings preset'))),
      comparisons: _list(
        json['comparisons'],
        'comparisons',
      ).map((c) => ComparisonSnapshot.fromJson(_map(c, 'comparison'))),
      results: _results(json['results']),
      toolDrafts: _map(json['toolDrafts'], 'toolDrafts').map(
        (name, fields) => MapEntry(
          name,
          _map(fields, 'tool fields').map(
            (key, value) => MapEntry(
              key,
              value is String ? value : _invalid('draft value'),
            ),
          ),
        ),
      ),
    );
  }
}

Object? _canonical(Object? value, [int depth = 0]) {
  if (depth > 128) _invalid('nesting depth');
  return switch (value) {
    Map<String, Object?>() => SplayTreeMap<String, Object?>.from(
      value.map((key, v) => MapEntry(key, _canonical(v, depth + 1))),
    ),
    List<Object?>() => value.map((v) => _canonical(v, depth + 1)).toList(),
    _ => value,
  };
}

// JavaScript folds integral doubles into ints. A native schema-1 envelope
// can distinguish those tokens in its checksum even after a browser decodes it.
final _jsonStringsAndNumbers = RegExp(
  r'"(?:[^"\\]|\\.)*"|(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)',
);

String _wireNumberDigest(String source, Map<String, Object?> envelope) {
  // Pick a marker that cannot collide with a decoded JSON string or key.
  const prefix = '#decoplanner-number#';
  final used = RegExp(
    '$prefix([0-9]+):',
  ).allMatches(jsonEncode(envelope)).map((match) => match[1]!).toSet();
  var suffix = 0;
  while (used.contains('$suffix')) {
    suffix++;
  }
  final marker = '$prefix$suffix:';
  final tagged = source.replaceAllMapped(_jsonStringsAndNumbers, (match) {
    final number = match[1];
    return number == null ? match[0]! : '"$marker$number"';
  });
  final payload = _map(jsonDecode(tagged), 'envelope')['document'];
  final canonical = jsonEncode(
    _canonical(payload),
  ).replaceAllMapped(RegExp('"$marker([-+.0-9Ee]+)"'), (match) => match[1]!);
  return sha256.convert(utf8.encode(canonical)).toString();
}

Uint8List encodePlannerDocument(
  PlannerDocument document, {
  int maxBytes = maximumDocumentBytes,
}) {
  final payload = document.toJson();
  final digest = sha256
      .convert(utf8.encode(jsonEncode(_canonical(payload))))
      .toString();
  final bytes = utf8.encode(
    jsonEncode({
      'format': 'decoplanner-plan',
      'schemaVersion': plannerDocumentSchema,
      'sha256': digest,
      'document': payload,
    }),
  );
  if (bytes.length > maxBytes) {
    throw const DocumentFailure(
      DocumentFailureKind.tooLarge,
      'Document exceeds the size limit.',
    );
  }
  return bytes;
}

PlannerDocument decodePlannerDocument(
  List<int> bytes, {
  int maxBytes = maximumDocumentBytes,
}) {
  if (bytes.length > maxBytes) {
    throw const DocumentFailure(
      DocumentFailureKind.tooLarge,
      'Document exceeds the size limit.',
    );
  }
  try {
    final source = utf8.decode(bytes);
    final json = _map(jsonDecode(source), 'envelope');
    if (json['format'] != 'decoplanner-plan') _invalid('format');
    if (json['schemaVersion'] is! int) _invalid('schemaVersion');
    if (json['schemaVersion'] != plannerDocumentSchema) {
      throw const DocumentFailure(
        DocumentFailureKind.unsupportedSchema,
        'Unsupported document schema.',
      );
    }
    final payload = _map(json['document'], 'document');
    final digest = sha256
        .convert(utf8.encode(jsonEncode(_canonical(payload))))
        .toString();
    if (json['sha256'] != digest &&
        (!identical(1, 1.0) ||
            json['sha256'] != _wireNumberDigest(source, json))) {
      throw const DocumentFailure(
        DocumentFailureKind.integrity,
        'Document checksum does not match.',
      );
    }
    return PlannerDocument.fromJson(payload);
  } on DocumentFailure {
    rethrow;
  } on FormatException {
    throw const DocumentFailure(
      DocumentFailureKind.invalidDocument,
      'Document is not valid UTF-8 JSON.',
    );
  } on CalculationFailure {
    throw const DocumentFailure(
      DocumentFailureKind.invalidDocument,
      'Invalid calculation data in document.',
    );
  } on StackOverflowError {
    throw const DocumentFailure(
      DocumentFailureKind.invalidDocument,
      'Document nesting is too deep.',
    );
  }
}
