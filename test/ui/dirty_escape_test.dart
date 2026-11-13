import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/bailout_editor.dart';
import 'package:deco_planner/ui/features/plan/level_editor.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final bailout in [false, true]) {
      testWidgets(
        'Escape preserves dirty draft and nested focus $brightness bailout$bailout',
        (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          tester.view.physicalSize = const Size(375, 667);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = PlannerViewModel();
          final opener = FocusNode();
          addTearDown(model.dispose);
          addTearDown(opener.dispose);
          model.replaceLevels([
            Level(
              depthMetres: 45,
              durationMin: 25,
              breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
            ),
          ]);
          final original = model.selected.toJson();
          await tester.pumpWidget(
            MaterialApp(
              theme: plannerTheme(brightness),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    focusNode: opener,
                    autofocus: true,
                    onPressed: () {
                      if (bailout) {
                        editBailout(
                          context,
                          source: model.selected,
                          units: DisplayUnits.metric,
                        );
                      } else {
                        editLevel(
                          context,
                          level: model.selected.levels.first,
                          units: DisplayUnits.metric,
                          previousDepth: 0,
                          settings: model.selected.settings,
                        );
                      }
                    },
                    child: const Text('Открыть'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          final route = ModalRoute.of(
            tester.element(find.byType(Dialog).last),
          )!;
          expect(route.transitionDuration, Duration.zero);
          expect(route.reverseTransitionDuration, Duration.zero);
          final input = bailout
              ? find.byKey(const Key('bailout-time'))
              : find.widgetWithText(TextFormField, 'Глубина, м');
          await tester.ensureVisible(input);
          await tester.enterText(input, bailout ? '12.5' : '42');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          final title = bailout
              ? 'Сохранить изменения bailout?'
              : 'Сохранить изменения уровня?';
          expect(find.text(title), findsOneWidget);
          final confirmation = ModalRoute.of(tester.element(find.text(title)))!;
          expect(confirmation.transitionDuration, Duration.zero);
          expect(confirmation.reverseTransitionDuration, Duration.zero);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text(title), findsNothing);
          expect(
            tester.widget<TextFormField>(input).controller!.text,
            bailout ? '12.5' : '42',
          );
          expect(model.selected.toJson(), original);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          var reachedDiscard = false;
          for (var step = 0; step < 40; step++) {
            final button = FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<TextButton>();
            if (button?.child case Text(data: 'Отменить изменения')) {
              reachedDiscard = true;
              break;
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
          }
          expect(reachedDiscard, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          expect(opener.hasPrimaryFocus, isTrue);
          expect(model.selected.toJson(), original);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
