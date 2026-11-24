import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/data/repositories/document_store_web.dart';
import 'package:deco_planner/data/services/browser_worker.dart';
import 'package:deco_planner/data/services/calculation_worker.dart';
import 'package:deco_planner/data/services/range_worker.dart';
import 'package:web/web.dart';

import '../support/document_fixtures.dart';

@JS('failNextDocumentWrite')
external void _failNextDocumentWrite();

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, [_RequestInit options]);

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSString> text();
}

extension type _RequestInit._(JSObject _) implements JSObject {
  external factory _RequestInit({JSString method, JSString body});
}

Future<Map<String, Object?>> _fixture(String name) async {
  final response = await _fetch(name.toJS).toDart;
  if (!response.ok) throw StateError('Could not load fixture $name.');
  return jsonDecode((await response.text().toDart).toDart)
      as Map<String, Object?>;
}

void _near(num? actual, num expected, double tolerance, String label) {
  if (actual == null ||
      !actual.isFinite ||
      (actual - expected).abs() > tolerance) {
    throw StateError('$label: expected $expected ± $tolerance, got $actual.');
  }
}

CalculationSettings _settings(DecompressionModel model) => CalculationSettings(
  model: model,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
);

Future<void> _checkReferences() async {
  final worker = CalculationWorker();
  final range = RangeWorker();
  try {
    final air = DiveRequest(
      id: 'air',
      levels: [
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: BreathingGas.oc(Gas(oxygen: .21)),
        ),
      ],
      settings: _settings(DecompressionModel.buhlmannB),
    );
    final data = await _fixture('oc-air-30m-20min.json');
    final observed =
        (data['observed'] as List<Object?>).first as Map<String, Object?>;
    final plan = await worker
        .calculate(air, inputRevision: 1, dependencyVersion: 'reference')
        .result;
    final segments = observed['segments'] as List<Object?>;
    _near(plan.segments.length, segments.length, 0, 'Plan segment count');
    for (var i = 0; i < segments.length; i++) {
      final expected = segments[i] as Map<String, Object?>;
      final actual = plan.segments[i];
      _near(
        actual.physical.startDepthMetres,
        expected['start_depth_m'] as num,
        0,
        'Plan segment $i start depth',
      );
      _near(
        actual.physical.endDepthMetres,
        expected['end_depth_m'] as num,
        0,
        'Plan segment $i end depth',
      );
      _near(
        actual.physical.durationMin,
        expected['duration_min'] as num,
        1e-12,
        'Plan segment $i duration',
      );
    }
    _checkTissues(plan.finalTissues, observed['final_tissues_bar'], 1e-12);

    final bailoutData = await _fixture('buhlmann-bailout-normalized.json');
    final rows = (bailoutData['cases'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final diluent = Gas(oxygen: .21, helium: .35);
    for (final (label, model) in [
      ('B', DecompressionModel.buhlmannB),
      ('C', DecompressionModel.buhlmannC),
    ]) {
      final row = rows.firstWhere(
        (row) =>
            row['model'] == label &&
            row['mode'] == 'bailout' &&
            row['runtime_point_min'] == 12.5 &&
            row['changed_diluent'] == false &&
            (row['switches'] as List<Object?>).isNotEmpty,
      );
      final source = DiveRequest(
        id: 'ccr-source',
        settings: _settings(model),
        levels: [
          Level(
            depthMetres: 45,
            durationMin: 25,
            breathing: BreathingGas.ccr(diluent, 1.3),
          ),
        ],
      );
      final bailout = BailoutRequest(
        id: 'escape',
        sourceDiveId: source.id,
        runtimeMin: 12.5,
        initialOcGas: diluent,
        switches: (row['switches'] as List<Object?>).cast<List<Object?>>().map(
          (entry) => GasSwitch(
            depthMetres: (entry[0] as num).toDouble(),
            breathing: BreathingGas.oc(
              Gas(
                oxygen: (entry[1] as num).toDouble(),
                helium: (entry[2] as num).toDouble(),
              ),
            ),
          ),
        ),
      );
      final result = await worker
          .calculate(
            source,
            bailout: bailout,
            inputRevision: 2,
            dependencyVersion: 'reference',
          )
          .result;
      final expected = row['expected'] as Map<String, Object?>;
      _near(
        result.runtimeMin,
        expected['runtime_min'] as num,
        1e-10,
        'Bailout $label runtime',
      );
      _near(
        result.firstStopMetres,
        expected['first_stop_m'] as num,
        0,
        'Bailout $label first stop',
      );
    }

    final vpmData = await _fixture('vpmb-normalized-schedules.json');
    final vpmRow = (vpmData['cases'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((row) => row['id'] == 'c0-80m30');
    final vpm = DiveRequest(
      id: 'c0-80m30',
      levels: [
        Level(
          depthMetres: 80,
          durationMin: 30,
          breathing: BreathingGas.oc(Gas(oxygen: .15, helium: .45)),
        ),
      ],
      settings: CalculationSettings(
        model: DecompressionModel.vpmB,
        pressure: PressureContext(
          surfaceBar: 1,
          waterVapourBar: .0493,
          barPerMetre: .1,
        ),
        stopGrid: StopGrid.metric(),
        gradientFactors: GradientFactors(low: .3, high: .85),
        descentMetresPerMin: 23,
        ascentMetresPerMin: 10,
        includeDescentInLevelTime: true,
        vpmConservatism: 0,
        vpm: VpmParameters(criticalVolumeEnabled: true),
      ),
    );
    final vpmPlan = await worker
        .calculate(vpm, inputRevision: 3, dependencyVersion: 'reference')
        .result;
    final actualVpm = vpmPlan.segments
        .where(
          (segment) =>
              segment.phase == SegmentPhase.ascent ||
              segment.phase == SegmentPhase.decompression,
        )
        .toList();
    final expectedVpm = (vpmRow['expected_segments'] as List<Object?>)
        .cast<Map<String, Object?>>();
    _near(actualVpm.length, expectedVpm.length, 0, 'VPM segment count');
    for (var i = 0; i < actualVpm.length; i++) {
      _near(
        actualVpm[i].physical.endDepthMetres,
        expectedVpm[i]['end_depth_m'] as num,
        1e-10,
        'VPM segment $i depth',
      );
      _near(
        actualVpm[i].physical.durationMin,
        expectedVpm[i]['duration_min'] as num,
        1e-7,
        'VPM segment $i duration',
      );
    }

    final handle = range.calculate(
      source: air,
      depths: RangeAxis(first: 27, last: 30, step: 3),
      durations: RangeAxis(first: 20, last: 20, step: 1),
      variants: [RangeVariant.base, RangeVariant.noAdditionalGases],
      inputRevision: 3,
      dependencyVersion: 'reference',
    );
    final summaries = handle.cells.toList();
    await handle.done;
    final cells = await summaries;
    _near(cells.length, 4, 0, 'Range cell count');
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      _near(cell.depthMetres, i < 2 ? 27 : 30, 0, 'Range cell $i depth');
      final direct = calculateBuhlmann(cell.request);
      _near(cell.runtimeMin, direct.runtimeMin, 1e-10, 'Range cell $i runtime');
      _near(
        cell.decompressionMin,
        direct.decompressionMin,
        1e-10,
        'Range cell $i deco',
      );
      if (cell.depthMetres == 30) {
        _near(
          cell.ascentMin,
          observed['ascent_min'] as num,
          1e-12,
          'Range cell $i reference ascent',
        );
      }
    }
  } finally {
    range.dispose();
    await worker.dispose();
  }
}

Future<void> _workerFailure<T>(
  Future<T> pending,
  WorkerFailureKind kind,
) async {
  try {
    await pending;
  } on WorkerFailure catch (error) {
    if (error.kind == kind) return;
    rethrow;
  }
  throw StateError('Expected worker failure ${kind.name}.');
}

Future<void> _checkWorkerLifecycle() async {
  final worker = CalculationWorker();
  final range = RangeWorker();
  final source = documentFixture().plan.dives.first;
  CalculationHandle submit(int revision, {Duration? timeout}) =>
      worker.calculate(
        source,
        inputRevision: revision,
        dependencyVersion: 'lifecycle',
        timeout: timeout ?? const Duration(seconds: 20),
      );
  try {
    final cancelled = submit(1);
    final cancellation = _workerFailure(
      cancelled.result,
      WorkerFailureKind.cancelled,
    );
    cancelled.cancel();
    await cancellation;
    await _workerFailure(
      submit(2, timeout: Duration.zero).result,
      WorkerFailureKind.timeout,
    );
    final old = submit(3);
    final superseded = _workerFailure(old.result, WorkerFailureKind.superseded);
    final current = submit(4);
    if ((await current.result).diveId != source.id ||
        current.identity.inputRevision != 4) {
      throw StateError('Replacement returned a result for the wrong input.');
    }
    await superseded;

    final response = await _fetch('../fail-next-worker'.toJS).toDart;
    if (!response.ok) throw StateError('Worker failure fixture unavailable.');
    await _workerFailure(submit(5).result, WorkerFailureKind.unexpected);
    await submit(6).result;

    RangeHandle calculate(RangeAxis depths, RangeAxis durations) =>
        range.calculate(
          source: source,
          depths: depths,
          durations: durations,
          variants: [RangeVariant.base, RangeVariant.noAdditionalGases],
          inputRevision: 7,
          dependencyVersion: 'lifecycle',
        );
    final heavy = calculate(
      RangeAxis(first: 30, last: 49, step: 1),
      RangeAxis(first: 20, last: 44, step: 1),
    );
    final firstCell = Completer<void>();
    var cells = 0;
    final subscription = heavy.cells.listen((_) {
      cells++;
      if (!firstCell.isCompleted) firstCell.complete();
    });
    final ended = _workerFailure(heavy.done, WorkerFailureKind.cancelled);
    await firstCell.future;
    final control = HTMLInputElement();
    var inputAccepted = false;
    control.oninput = ((Event _) => inputAccepted = control.value == '31').toJS;
    await Future<void>.delayed(Duration.zero, () {
      control.value = '31';
      control.dispatchEvent(Event('input'));
    });
    if (!inputAccepted || cells >= 1000) {
      throw StateError(
        'Input must be handled while the heavy range is running.',
      );
    }
    final replacement = calculate(
      RangeAxis(first: 31, last: 31, step: 1),
      RangeAxis(first: 20, last: 20, step: 1),
    );
    await ended;
    await subscription.cancel();
    final next = await replacement.cells.toList();
    await replacement.done;
    if (next.length != 2 || next.any((cell) => cell.depthMetres != 31)) {
      throw StateError('The replacement range received a stale cell.');
    }
  } finally {
    range.dispose();
    await worker.dispose();
  }
}

Future<void> _checkDocumentStore() async {
  final original = documentFixture();
  final store = await IndexedDocumentStore.open(name: 'browser-check');
  await store.save(original);
  await store.save(original.copyWith(name: 'Сохранённая версия'));
  store.close();

  final reopened = await IndexedDocumentStore.open(name: 'browser-check');
  try {
    final before = (await reopened.load(original.id)).document;
    if (before.name != 'Сохранённая версия' ||
        !before.usesCurrentModel ||
        before.results.isEmpty ||
        encodePlannerDocument(before).length !=
            encodePlannerDocument(
              original.copyWith(name: before.name),
            ).length) {
      throw StateError('The saved document did not survive reopening.');
    }
    _failNextDocumentWrite();
    try {
      await reopened.save(before.copyWith(name: 'Отменённая запись'));
      throw StateError('Expected a write failure.');
    } on DocumentFailure catch (error) {
      if (error.kind != DocumentFailureKind.io) rethrow;
    }
    if ((await reopened.load(before.id)).document.name != before.name) {
      throw StateError('A failed transaction replaced the last saved plan.');
    }

    final stale = PlannerDocument(
      id: 'stale',
      name: 'Старый расчёт',
      createdAt: before.createdAt,
      modifiedAt: before.modifiedAt,
      plan: before.plan,
      modelVersion: 'old-model',
    );
    await reopened.save(stale);
    if ((await reopened.load(stale.id)).document.usesCurrentModel) {
      throw StateError('A saved document with an older model became current.');
    }
    await reopened.rename(before.id, 'Новое название');
    if ((await reopened.load(before.id)).document.name != 'Новое название') {
      throw StateError('Rename did not persist.');
    }
    await reopened.delete(before.id);
    if ((await reopened.list()).any((entry) => entry.id == before.id)) {
      throw StateError('Deleted document is still listed.');
    }
    try {
      await reopened.save(before);
      throw StateError('A delayed save resurrected the removed plan.');
    } on DocumentFailure catch (error) {
      if (error.kind != DocumentFailureKind.notFound) rethrow;
    }
  } finally {
    reopened.close();
  }
}

Future<void> _checkDocumentExchange() async {
  final response = await _fetch('native-plan.json'.toJS).toDart;
  if (!response.ok) throw StateError('Native document unavailable.');
  final wire = (await response.text().toDart).toDart;
  final original = decodePlannerDocument(utf8.encode(wire));
  if (!original.usesCurrentModel || original.plan.dives.length != 2) {
    throw StateError('Browser did not read the native document.');
  }
  for (final (input, kind) in [
    ('{', DocumentFailureKind.invalidDocument),
    (
      wire.replaceFirst('"schemaVersion":1', '"schemaVersion":99'),
      DocumentFailureKind.unsupportedSchema,
    ),
  ]) {
    try {
      decodePlannerDocument(utf8.encode(input));
      throw StateError('Invalid JSON import was accepted.');
    } on DocumentFailure catch (error) {
      if (error.kind != kind) rethrow;
    }
  }
  final payload = utf8.decode(
    encodePlannerDocument(original.copyWith(name: 'Из веб-версии')),
  );
  final saved = await _fetch(
    '../web-plan'.toJS,
    _RequestInit(method: 'POST'.toJS, body: payload.toJS),
  ).toDart;
  if (!saved.ok) throw StateError('Could not capture the browser export.');
}

void _checkTissues(TissueState actual, Object? raw, double tolerance) {
  final expected = raw as Map<String, Object?>;
  final nitrogen = (expected['n2'] as List<Object?>).cast<num>();
  final helium = (expected['he'] as List<Object?>).cast<num>();
  for (var i = 0; i < 16; i++) {
    _near(actual.nitrogenBar[i], nitrogen[i], tolerance, 'Tissue $i nitrogen');
    _near(actual.heliumBar[i], helium[i], tolerance, 'Tissue $i helium');
  }
}

Future<void> main() async {
  String result;
  try {
    await _checkReferences();
    await _checkWorkerLifecycle();
    await _checkDocumentStore();
    await _checkDocumentExchange();
    await prepareBrowserWorkers();
    final response = await _fetch('../fail-next-worker'.toJS).toDart;
    if (!response.ok) throw StateError('Offline worker fixture unavailable.');
    // A direct worker request would fail. The running page retains its script.
    await _checkReferences();
    result =
        'PASS: calculation references, Web Worker lifecycle, IndexedDB transactions';
  } catch (error, stack) {
    result = 'FAIL: $error\n$stack';
  }
  await _fetch(
    '../result'.toJS,
    _RequestInit(method: 'POST'.toJS, body: result.toJS),
  ).toDart;
}
