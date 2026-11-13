import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 1440.0]) {
    testWidgets(
      'real result details and usage $width preserve stale boundary',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        await tester.runAsync(() => model.calculateSelection());
        expect(model.snapshot.status, PlanStatus.ready);
        await tester.pumpWidget(PlannerApp(viewModel: model));
        await tester.pumpAndSettle();
        final rows = find.byKey(const PageStorageKey('result-segment-0'));
        await tester.scrollUntilVisible(
          rows,
          250,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await Scrollable.ensureVisible(tester.element(rows), alignment: .2);
        await tester.pumpAndSettle();
        await tester.tap(rows);
        await tester.pumpAndSettle();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          rows,
          200,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.ensureVisible(rows);
        await tester.pumpAndSettle();
        final segment = model.snapshot.result!.segments.first;
        final expected = calculateGasUsage(
          model.snapshot.result!,
          model.selected.settings,
        ).segments.first.litres;
        expect(find.textContaining('ppO₂ в конце'), findsOneWidget);
        expect(find.textContaining('Плотность газа в конце'), findsOneWidget);
        expect(
          find.textContaining(
            'Расход сегмента ${expected.toStringAsFixed(1)} L',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('GF по глубине'), findsOneWidget);
        expect(
          find.textContaining('конец ${segment.endMin.toStringAsFixed(3)} мин'),
          findsOneWidget,
        );
        final usage = find.byKey(const Key('gas-usage'));
        await tester.scrollUntilVisible(
          usage,
          -200,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.ensureVisible(usage);
        await tester.tap(usage);
        await tester.pumpAndSettle();
        expect(find.text('Расход газа и баллоны'), findsOneWidget);
        final old = model.snapshot.result;
        model.replaceLevels([
          Level(
            depthMetres: 33,
            durationMin: 25,
            breathing: model.selected.levels.first.breathing,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(
          find.text('Результат изменён. Вернитесь к плану и пересчитайте.'),
          findsOneWidget,
        );
        expect(model.snapshot.result, same(old));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final button = tester.widget<TextButton>(
          find.byKey(const Key('gas-usage')),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Расход и GF доступны после актуального расчёта.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
