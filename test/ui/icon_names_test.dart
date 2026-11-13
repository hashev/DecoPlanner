import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('icon actions expose names as labels rather than tooltip only', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      final buttons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .toList();
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        expect(button.tooltip, isNotEmpty);
        final data = tester
            .getSemantics(find.byWidget(button))
            .getSemanticsData();
        expect(
          data.label,
          button.tooltip,
          reason:
              'Native action name must not depend on optional tooltip announcements',
        );
      }
    } finally {
      handle.dispose();
    }
  });
}
