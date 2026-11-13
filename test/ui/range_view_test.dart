import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/range_worker.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/range/range_cell_view.dart';
import 'package:deco_planner/ui/features/range/range_view.dart';
import 'package:deco_planner/ui/features/range/range_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void blockedRange(Map<String, Object?> message) {
  while (true) {}
}

Future<void> show(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last,
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await show(tester, field, delta: -250);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> run(WidgetTester tester, RangeViewModel vm) async {
  final button = find.text('Построить таблицы');
  await show(tester, button);
  await tester.runAsync(() async {
    await tester.tap(button);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (vm.status == RangeStatus.calculating) {
      if (DateTime.now().isAfter(deadline)) throw StateError('Range timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'real range retains individual errors, opens a full successful cell and invalidates after input changes',
    (tester) async {
      final model = PlannerViewModel(), vm = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RangeView(
            model: model,
            sourceId: model.selected.id,
            viewModel: vm,
          ),
        ),
      );
      await edit(tester, 'Время от, мин', '0');
      await edit(tester, 'Время до, мин', '20');
      await edit(tester, 'Шаг времени, мин', '20');
      await run(tester, vm);
      expect(vm.status, RangeStatus.complete);
      expect(vm.cells.length, 2);
      expect(vm.cells.first.failure, isNotNull);
      expect(vm.cells.last.failure, isNull);
      final success = find.text('30 м · 20.0 мин · Базовый');
      await show(tester, success);
      await tester.tap(success);
      await tester.pump(const Duration(milliseconds: 300));
      final until = DateTime.now().add(const Duration(seconds: 10));
      final runtime = find.descendant(
        of: find.byType(RangeCellView),
        matching: find.textContaining('Runtime '),
      );
      while (runtime.evaluate().isEmpty) {
        if (DateTime.now().isAfter(until)) {
          throw StateError('Full cell timed out');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        // Do not advance fake time through an indeterminate progress animation:
        // doing so can expire the real worker's timeout before the OS schedules it.
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(RangeCellView), findsOneWidget);
      expect(runtime, findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await edit(tester, 'Глубина до, м', '33');
      expect(vm.inputsCurrent, isFalse);
      await show(
        tester,
        find.text('Предыдущий диапазон неактуален · пересчитайте'),
      );
      expect(
        find.text('Предыдущий диапазон неактуален · пересчитайте'),
        findsOneWidget,
      );
      expect(model.planRequest.revision, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid step preserves input; large range requires confirmation and can be hard cancelled',
    (tester) async {
      final model = PlannerViewModel(),
          vm = RangeViewModel(worker: RangeWorker(entryPoint: blockedRange));
      addTearDown(model.dispose);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RangeView(
            model: model,
            sourceId: model.selected.id,
            viewModel: vm,
          ),
        ),
      );
      await edit(tester, 'Шаг глубины, м', '0');
      await run(tester, vm);
      await show(
        tester,
        find.text('Введите допустимое конечное число'),
        delta: -250,
      );
      expect(find.text('Введите допустимое конечное число'), findsOneWidget);
      await edit(tester, 'Шаг глубины, м', '1');
      await edit(tester, 'Глубина от, м', '1');
      await edit(tester, 'Глубина до, м', '101');
      final calculate = find.text('Построить таблицы');
      await show(tester, calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      expect(find.text('Рассчитать 101 сценариев?'), findsOneWidget);
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(vm.status, RangeStatus.draft);
      await show(tester, calculate);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Построить'));
      await tester.pump();
      final cancel = find.text('Отменить диапазон');
      await Scrollable.ensureVisible(tester.element(cancel), alignment: .3);
      await tester.pump();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(vm.status, RangeStatus.cancelled);
      expect(vm.cells, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'units/theme preserve physical range and plan edits invalidate it',
    (tester) async {
      final model = PlannerViewModel(), vm = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RangeView(
            model: model,
            sourceId: model.selected.id,
            viewModel: vm,
          ),
        ),
      );
      await run(tester, vm);
      final value = vm.cells.single.runtimeMin;
      model.setUnits(DisplayUnits.imperial);
      model.setTheme(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(vm.inputsCurrent, isTrue);
      expect(vm.cells.single.runtimeMin, value);
      await show(
        tester,
        find.widgetWithText(TextFormField, 'Глубина от, ft'),
        delta: -250,
      );
      expect(
        double.parse(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Глубина от, ft'),
              )
              .controller!
              .text,
        ),
        closeTo(Units.metresToFeet(30), 1e-12),
      );
      model.setSurfaceInterval(45);
      await tester.pumpAndSettle();
      expect(vm.inputsCurrent, isFalse);
    },
  );
  testWidgets(
    'different document with same revision invalidates range and replaces draft',
    (tester) async {
      final model = PlannerViewModel(), vm = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(vm.dispose);
      final id = model.selected.id;
      await tester.pumpWidget(
        MaterialApp(
          home: RangeView(model: model, sourceId: id, viewModel: vm),
        ),
      );
      await run(tester, vm);
      expect(vm.inputsCurrent, isTrue);
      final now = DateTime.utc(2026, 11, 13);
      model.restoreDocument(
        PlannerDocument(
          id: 'other-plan',
          name: 'Другой',
          createdAt: now,
          modifiedAt: now,
          plan: PlanRequest(
            revision: 0,
            dives: [
              DiveRequest(
                id: id,
                settings: model.selected.settings,
                levels: [
                  Level(
                    depthMetres: 45,
                    durationMin: 20,
                    breathing: BreathingGas.oc(Gas(oxygen: .21)),
                  ),
                ],
              ),
            ],
          ),
          toolDrafts: {
            'mod': {
              'range:$id:main:depthFrom': '42',
              'range:$id:main:units': 'metric',
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(vm.inputsCurrent, isFalse);
      await show(
        tester,
        find.widgetWithText(TextFormField, 'Глубина от, м'),
        delta: -250,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Глубина от, м'),
            )
            .controller!
            .text,
        '42',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('range list/matrix $size text200 has no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final model = PlannerViewModel(), vm = RangeViewModel();
      addTearDown(model.dispose);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RangeView(
            model: model,
            sourceId: model.selected.id,
            viewModel: vm,
          ),
        ),
      );
      await run(tester, vm);
      await show(tester, find.text('Матрица вместо списка'));
      await tester.tap(find.text('Матрица вместо списка'));
      await tester.pumpAndSettle();
      await show(tester, find.byType(DataTable));
      expect(find.byType(DataTable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
