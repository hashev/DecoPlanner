import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reduced motion removes theme and route movement without changing calculation',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.runAsync(() => model.calculate());
      final result = model.snapshot.result;
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero,
      );
      model.setTheme(ThemeMode.dark);
      await tester.pump();
      expect(model.snapshot.result, same(result));
      final child = const Text('Без движения');
      bool? identicalChild;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                final route = ModalRoute.of(context)! as PageRoute<void>;
                final transition = plannerTheme(Brightness.light)
                    .pageTransitionsTheme
                    .builders[Theme.of(context).platform]!
                    .buildTransitions(
                      route,
                      context,
                      const AlwaysStoppedAnimation(.1),
                      const AlwaysStoppedAnimation(0),
                      child,
                    );
                identicalChild = identical(transition, child);
                return transition;
              },
            ),
          ),
        ),
      );
      expect(identicalChild, isTrue);
      expect(find.text('Без движения'), findsOneWidget);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final width in [375.0, 1000.0]) {
      testWidgets(
        'workspace labels, contrast and 48 targets $theme width$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final model = PlannerViewModel();
            addTearDown(model.dispose);
            model.setTheme(theme);
            await tester.pumpWidget(PlannerApp(viewModel: model));
            await tester.pumpAndSettle();
            Future<void> check() async {
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }

            await check();
            for (final icon in [
              Icons.science_outlined,
              Icons.settings_outlined,
            ]) {
              await tester.tap(find.byIcon(icon).first);
              await tester.pumpAndSettle();
              await check();
              final list = find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  )
                  .hitTestable();
              for (var step = 0; step < 3; step++) {
                await tester.drag(list.last, const Offset(0, -450));
                await tester.pumpAndSettle();
                await check();
              }
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
