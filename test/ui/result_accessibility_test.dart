import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/domain/profile_data.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/gas_usage_view.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/plan/profile_view.dart';
import 'package:deco_planner/ui/features/range/range_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [375.0, 1000.0]) {
      for (final screen in ['profile', 'usage', 'range']) {
        testWidgets('$screen labels targets contrast $brightness width$width', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final model = PlannerViewModel();
            addTearDown(model.dispose);
            await tester.runAsync(() => model.calculateSelection());
            final result = model.snapshot.result!;
            final view = switch (screen) {
              'profile' => ProfileView(
                data: ProfileData(
                  result: result,
                  settings: model.selected.settings,
                ),
                model: model,
              ),
              'usage' => GasUsageView(
                report: calculateGasUsage(result, model.selected.settings),
                units: DisplayUnits.metric,
                drafts: const {},
                onDraft: (_, _) {},
              ),
              _ => RangeView(model: model, sourceId: model.selected.id),
            };
            await tester.pumpWidget(
              MaterialApp(theme: plannerTheme(brightness), home: view),
            );
            await tester.pumpAndSettle();
            for (var step = 0; step < 16; step++) {
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
              for (final button in tester.widgetList<IconButton>(
                find.byType(IconButton),
              )) {
                expect(
                  tester
                      .getSemantics(find.byWidget(button))
                      .getSemanticsData()
                      .label,
                  button.tooltip,
                );
              }
              expect(tester.takeException(), isNull);
              final lists = find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  )
                  .hitTestable();
              if (lists.evaluate().isEmpty) break;
              final state = tester.state<ScrollableState>(lists.last);
              if (state.position.extentAfter < 1) break;
              await tester.drag(lists.last, const Offset(0, -500));
              await tester.pumpAndSettle();
            }
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
