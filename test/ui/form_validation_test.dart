import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/level_editor.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final announce in [false, true]) {
    testWidgets(
      'submit reveals and focuses first error above keyboard announce$announce',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(supportsAnnounce: announce);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(375, 667);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = PlannerViewModel();
          addTearDown(model.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: plannerTheme(Brightness.light),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => editLevel(
                      context,
                      level: model.selected.levels.first,
                      units: DisplayUnits.metric,
                      previousDepth: 0,
                      settings: model.selected.settings,
                    ),
                    child: const Text('Редактор'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Редактор'));
          await tester.pumpAndSettle();
          final depth = find.widgetWithText(TextFormField, 'Глубина, м');
          await tester.enterText(depth, '');
          final oxygen = find.widgetWithText(TextFormField, 'Кислород O₂, %');
          await tester.ensureVisible(oxygen);
          await tester.enterText(oxygen, '32');
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          final save = find.text('Сохранить');
          await tester.ensureVisible(save);
          tester.takeAnnouncements();
          await tester.tap(save);
          await tester.pumpAndSettle();
          final field = tester.widget<TextFormField>(depth);
          expect(field.controller!.text, '');
          expect(tester.widget<TextFormField>(oxygen).controller!.text, '32');
          final focused = FocusManager.instance.primaryFocus?.context;
          final input = focused?.widget is EditableText
              ? focused!.widget as EditableText
              : focused?.findAncestorWidgetOfExactType<EditableText>();
          expect(input?.controller, same(field.controller));
          final error = tester.state<FormFieldState<String>>(depth).errorText;
          expect(error, isNotEmpty);
          final textField = tester
              .widgetList<TextField>(find.byType(TextField))
              .firstWhere((value) => value.controller == field.controller);
          final label = tester
              .getSemantics(find.byWidget(textField))
              .getSemanticsData()
              .label;
          expect(label, contains('Глубина, м'));
          final announcedError = tester
              .getSemantics(find.text(error!))
              .getSemanticsData();
          expect(announcedError.label, error);
          if (announce) {
            expect(tester.takeAnnouncements().map((value) => value.message), [
              error,
            ]);
          } else {
            var node = tester.getSemantics(find.text(error));
            while (!node.getSemanticsData().flagsCollection.isLiveRegion &&
                node.parent != null) {
              node = node.parent!;
            }
            expect(
              node.getSemanticsData().flagsCollection.isLiveRegion,
              isTrue,
            );
            expect(tester.takeAnnouncements(), isEmpty);
          }
          expect(depth.hitTestable(), findsOneWidget);
          expect(model.selected.levels.first.breathing.gas.oxygen, .21);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
