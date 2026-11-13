import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/planner_pdf.dart';
import 'package:deco_planner/data/services/range_worker.dart';
import 'package:deco_planner/domain/planner_report.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dive report preserves physical inputs, segments, units and model; renders offline PDF',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final request = model.selected;
      final result = calculateBuhlmann(request);
      for (final units in DisplayUnits.values) {
        final report = PlannerReport.dive(
          result: result,
          request: request,
          units: units,
        );
        expect(report.conditions.join(' '), contains(calculationModelVersion));
        expect(
          report.conditions.join(' '),
          contains('Runtime ${PlannerReport.number(result.runtimeMin)}'),
        );
        expect(report.tables.last.rows.length, result.segments.length);
        expect(
          report.tables.first.rows.first.first,
          contains(units == DisplayUnits.metric ? 'м' : 'ft'),
        );
        final bytes = await const PlannerPdf().build(report);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(10000));
        final dir = Directory('local/validation/pdf')
          ..createSync(recursive: true);
        File('${dir.path}/dive-${units.name}.pdf').writeAsBytesSync(bytes);
      }
    },
  );
  test(
    'range PDF preserves failed cells, axes and all 1000 rows across pages',
    () async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final worker = RangeWorker();
      addTearDown(worker.dispose);
      final handle = worker.calculate(
        source: model.selected,
        depths: RangeAxis(first: 30, last: 30, step: 3),
        durations: RangeAxis(first: 0, last: 20, step: 20),
        variants: [RangeVariant.base],
        inputRevision: 0,
        dependencyVersion: 'report-test',
      );
      final collected = handle.cells.toList();
      await handle.done;
      final cells = await collected;
      expect(cells.first.failure, isNotNull);
      expect(cells.last.failure, isNull);
      final many = List.generate(1000, (i) => cells[i % 2]);
      final report = PlannerReport.range(
        cells: many,
        depths: RangeAxis(first: 30, last: 30, step: 3),
        durations: RangeAxis(first: 0, last: 20, step: 20),
        variants: [RangeVariant.base],
        units: DisplayUnits.imperial,
        status: 'cancelled',
        total: 1000,
      );
      expect(report.tables.last.rows.length, 1000);
      expect(report.tables.last.rows.first[2], '-');
      expect(
        report.tables.last.rows.first.last,
        contains(cells.first.failure!.code.name),
      );
      expect(report.conditions.join(' '), contains('cancelled'));
      final bytes = await const PlannerPdf().build(report);
      File('local/validation/pdf/range-1000.pdf').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(20000));
    },
  );
  test('report keeps decompression and OTU when CNS is unavailable', () async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    final request = DiveRequest(
      id: 'oxygen-domain',
      settings: model.selected.settings,
      levels: [
        Level(
          depthMetres: 10,
          durationMin: 5,
          breathing: BreathingGas.oc(Gas(oxygen: 1)),
        ),
      ],
    );
    final result = calculateBuhlmann(request);
    expect(result.finalState.oxygen.cnsFraction, isNull);
    final report = PlannerReport.dive(
      result: result,
      request: request,
      units: DisplayUnits.metric,
    );
    expect(report.conditions.join(' '), contains('CNS недоступен'));
    expect(
      report.conditions.join(' '),
      contains('OTU ${PlannerReport.number(result.finalState.oxygen.otu)}'),
    );
    expect(report.tables.last.rows.length, result.segments.length);
  });
}
