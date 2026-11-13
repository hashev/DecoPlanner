import 'package:deco_planner/domain/profile_data.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/plan/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'profile and numerical points avoid home indicator $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        await tester.runAsync(() => model.calculateSelection());
        await tester.pumpWidget(
          MaterialApp(
            theme: plannerTheme(brightness),
            home: ProfileView(
              data: ProfileData(
                result: model.snapshot.result!,
                settings: model.selected.settings,
              ),
              model: model,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final open = find.widgetWithText(
          OutlinedButton,
          'Численная таблица профиля',
        );
        await tester.scrollUntilVisible(
          open,
          500,
          maxScrolls: 40,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await Scrollable.ensureVisible(tester.element(open), alignment: 1);
        await tester.pumpAndSettle();
        expect(tester.getBottomRight(open).dy, lessThanOrEqualTo(667 - 34));
        await tester.tap(open);
        await tester.pumpAndSettle();
        final list = find.byType(Scrollable).last;
        final state = tester.state<ScrollableState>(list);
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = find.byType(ListTile).last;
        expect(tester.getBottomRight(last).dy, lessThanOrEqualTo(667 - 34));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
