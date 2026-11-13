import 'package:deco_planner/ui/features/plan/bailout_editor.dart';
import 'package:deco_planner/ui/features/plan/gas_usage_view.dart';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/core/planner_theme.dart';
import 'package:deco_planner/ui/features/plan/level_editor.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/plan/settings_editor.dart';
import 'package:deco_planner/ui/features/plan/switches_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [375.0, 1000.0]) {
      for (final editor in [
        'level',
        'settings',
        'switches',
        'bailout',
        'tank',
      ]) {
        for (final escape in [false, true]) {
          testWidgets(
            '$editor keyboard cancel restores opener focus $brightness escape$escape width$width',
            (tester) async {
              tester.view.physicalSize = Size(width, 900);
              final semantics = tester.ensureSemantics();
              try {
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                final model = PlannerViewModel();
                final opener = FocusNode();
                addTearDown(model.dispose);
                addTearDown(opener.dispose);
                if (editor == 'bailout') {
                  model.replaceLevels([
                    Level(
                      depthMetres: 45,
                      durationMin: 25,
                      breathing: BreathingGas.ccr(
                        Gas(oxygen: .21, helium: .35),
                        1.3,
                      ),
                    ),
                  ]);
                }
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
                            switch (editor) {
                              case 'level':
                                editLevel(
                                  context,
                                  level: model.selected.levels.first,
                                  units: DisplayUnits.metric,
                                  previousDepth: 0,
                                  settings: model.selected.settings,
                                );
                              case 'settings':
                                editCalculationSettings(
                                  context,
                                  initial: model.selected.settings,
                                  units: DisplayUnits.metric,
                                );
                              case 'bailout':
                                editBailout(
                                  context,
                                  source: model.selected,
                                  units: DisplayUnits.metric,
                                );
                              case 'tank':
                                editTankParameters(
                                  context,
                                  units: DisplayUnits.metric,
                                );
                              case 'switches':
                                editGasSwitches(
                                  context,
                                  initial: const [],
                                  units: DisplayUnits.metric,
                                  ccr: false,
                                );
                            }
                          },
                          child: const Text('Открыть редактор'),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(opener.hasPrimaryFocus, isTrue);
                await tester.sendKeyEvent(LogicalKeyboardKey.enter);
                await tester.pumpAndSettle();
                expect(find.byType(Dialog), findsOneWidget);
                expect(opener.hasFocus, isFalse);
                for (final field in tester.widgetList<TextField>(
                  find.byType(TextField),
                )) {
                  final label = field.decoration?.labelText;
                  expect(label, isNotEmpty);
                  expect(
                    tester
                        .getSemantics(find.byWidget(field))
                        .getSemanticsData()
                        .label,
                    contains(label!),
                  );
                }
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
                if (!escape) {
                  var foundCancel = false;
                  for (var step = 0; step < 100; step++) {
                    final context = FocusManager.instance.primaryFocus?.context;
                    final button = context
                        ?.findAncestorWidgetOfExactType<TextButton>();
                    if (button?.child case Text(data: 'Отменить')) {
                      foundCancel = true;
                      break;
                    }
                    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                    await tester.pumpAndSettle();
                    expect(
                      opener.hasFocus,
                      isFalse,
                      reason: 'Dialog traps traversal',
                    );
                  }
                  expect(
                    foundCancel,
                    isTrue,
                    reason: 'Cancel is keyboard reachable',
                  );
                }
                await tester.sendKeyEvent(
                  escape ? LogicalKeyboardKey.escape : LogicalKeyboardKey.enter,
                );
                await tester.pumpAndSettle();
                expect(find.byType(Dialog), findsNothing);
                expect(opener.hasPrimaryFocus, isTrue);
                expect(model.selected.toJson(), original);
                expect(tester.takeException(), isNull);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
}
