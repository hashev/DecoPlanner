import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/tools/auxiliary_tools.dart';
import 'package:deco_planner/ui/features/tools/gas_property_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> show(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last,
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .3);
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await show(tester, field, delta: -200);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> calculate(WidgetTester tester, {bool capacity = false}) async {
  final button = find.text(capacity ? 'Преобразовать' : 'Рассчитать');
  await show(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'top-off validates lower pressure and composition, handles equality and new input',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AuxiliaryToolView(model: model, tool: AuxiliaryTool.topOff),
        ),
      );
      await calculate(tester);
      await show(tester, find.textContaining('O₂ 29.250'));
      expect(find.textContaining('N₂ 70.750'), findsOneWidget);
      await edit(tester, 'Итоговое давление, bar', '40');
      await calculate(tester);
      await show(
        tester,
        find.text('Итоговое давление должно быть выше исходного'),
        delta: -200,
      );
      expect(
        find.text('Итоговое давление должно быть выше исходного'),
        findsOneWidget,
      );
      await edit(tester, 'Итоговое давление, bar', '50');
      await calculate(tester);
      await show(
        tester,
        find.text('Итоговое давление должно быть выше исходного'),
        delta: -200,
      );
      expect(
        find.text('Итоговое давление должно быть выше исходного'),
        findsOneWidget,
      );
      await edit(tester, 'Итоговое давление, bar', '200');
      await edit(tester, 'Исходный He, %', '90');
      await calculate(tester);
      await show(
        tester,
        find.text('O₂ + He не должны превышать100%').first,
        delta: -200,
      );
      expect(find.text('O₂ + He не должны превышать100%'), findsNWidgets(2));
      expect(model.planRequest.revision, 0);
    },
  );
  testWidgets(
    'equalizer uses tank factor with imperial pressure and rejects zero volume',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AuxiliaryToolView(model: model, tool: AuxiliaryTool.equalizer),
        ),
      );
      await calculate(tester);
      await show(tester, find.text('После уравнивания: 170.968 bar'));
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      await show(
        tester,
        find.widgetWithText(
          TextFormField,
          'Баллон 1, tank factor CuFt/100 PSI',
        ),
        delta: -200,
      );
      final factor = double.parse(
        tester
            .widget<TextFormField>(
              find.widgetWithText(
                TextFormField,
                'Баллон 1, tank factor CuFt/100 PSI',
              ),
            )
            .controller!
            .text,
      );
      expect(
        factor,
        closeTo(
          12 *
              100 *
              Units.barPerPsi /
              Units.barPerAta /
              Units.litresPerCubicFoot,
          1e-12,
        ),
      );
      await calculate(tester);
      final expected = Units.barToPsi((12 * 50 + 50 * 200) / 62);
      await show(
        tester,
        find.text('После уравнивания: ${expected.toStringAsFixed(3)} PSI'),
      );
      expect(
        find.text('После уравнивания: ${expected.toStringAsFixed(3)} PSI'),
        findsOneWidget,
      );
      await edit(tester, 'Баллон 1, tank factor CuFt/100 PSI', '0');
      await calculate(tester);
      await show(
        tester,
        find.text('Значение должно быть больше нуля'),
        delta: -200,
      );
      expect(find.text('Значение должно быть больше нуля'), findsOneWidget);
    },
  );
  testWidgets(
    'capacity converts both explicit directions and preserves previous result on overflow',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AuxiliaryToolView(model: model, tool: AuxiliaryTool.capacity),
        ),
      );
      await calculate(tester, capacity: true);
      final expected = CylinderCapacity(waterLitres: 12, workingBar: 232);
      await show(
        tester,
        find.text(
          'Номинальная ёмкость: ${expected.nominalCubicFeet.toStringAsFixed(6)} CuFt',
        ),
      );
      expect(
        find.text(
          'Номинальная ёмкость: ${expected.nominalCubicFeet.toStringAsFixed(6)} CuFt',
        ),
        findsOneWidget,
      );
      await edit(tester, 'Водяной объём, L', '1e308');
      await calculate(tester, capacity: true);
      expect(
        find.textContaining('Значения вне численной области модели'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final direction = find.byType(DropdownButtonFormField<bool>);
      await show(tester, direction, delta: -200);
      await tester.tap(direction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CuFt/PSI → L/bar').last);
      await tester.pumpAndSettle();
      await calculate(tester, capacity: true);
      final reverse = CylinderCapacity.fromImperial(
        nominalCubicFeet: 80,
        workingPsi: 3000,
      );
      await show(
        tester,
        find.text('Водяной объём: ${reverse.waterLitres.toStringAsFixed(6)} L'),
      );
      expect(
        find.text('Водяной объём: ${reverse.waterLitres.toStringAsFixed(6)} L'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tool navigation/back restores each draft without changing gas plan',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      final top = find.text('Дозаправка');
      await show(tester, top, delta: -200);
      await tester.tap(top);
      await tester.pumpAndSettle();
      await edit(tester, 'Исходное давление, bar', '123,4');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Уравнивание баллонов'));
      await tester.pumpAndSettle();
      await edit(tester, 'Баллон 1, водяной объём L', '15');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(top);
      await tester.pumpAndSettle();
      await show(
        tester,
        find.widgetWithText(TextFormField, 'Исходное давление, bar'),
        delta: 200,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Исходное давление, bar'),
            )
            .controller!
            .text,
        '123,4',
      );
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      expect(
        double.parse(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Исходное давление, PSI'),
              )
              .controller!
              .text,
        ),
        closeTo(Units.barToPsi(123.4), 1e-9),
      );
      expect(model.planRequest.revision, 0);
    },
  );
  for (final tool in AuxiliaryTool.values) {
    for (final size in [
      const Size(375, 667),
      const Size(667, 375),
      const Size(1440, 900),
    ]) {
      testWidgets('$tool $size text200 presents real result without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: AuxiliaryToolView(model: model, tool: tool),
          ),
        );
        await calculate(tester, capacity: tool == AuxiliaryTool.capacity);
        await show(tester, find.text('Результат актуален'));
        expect(find.text('Результат актуален'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
