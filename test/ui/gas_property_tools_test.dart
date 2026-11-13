import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/tools/gas_property_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/document_fixtures.dart';

Finder vertical() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
Future<void> visible(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: vertical(),
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .3);
  await tester.pumpAndSettle();
}

Future<void> tap(
  WidgetTester tester,
  String label, {
  double delta = 200,
}) async {
  final target = find.text(label);
  await visible(tester, target, delta: delta);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await visible(tester, field, delta: -200);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<GasPropertyTool>);
  tester.state<ScrollableState>(vertical()).position.jumpTo(0);
  await tester.pumpAndSettle();
  await visible(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'MOD/END validates gas and limits, preserves stale values and reacts to input',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Кислород O₂, %', '32');
      await tap(tester, 'Рассчитать MOD');
      await visible(tester, find.text('MOD'));
      expect(find.text('34.2 м'), findsOneWidget);
      await edit(tester, 'Кислород O₂, %', '80');
      await edit(tester, 'Гелий He, %', '30');
      await tap(tester, 'Рассчитать MOD');
      await visible(
        tester,
        find.text('O₂ + He не должны превышать100%').first,
        delta: -200,
      );
      expect(find.text('O₂ + He не должны превышать100%'), findsNWidgets(2));
      await edit(tester, 'Кислород O₂, %', '50');
      await edit(tester, 'Гелий He, %', '0');
      await edit(tester, 'Минимальный PO₂, bar', '2');
      await tap(tester, 'Рассчитать MOD');
      await visible(
        tester,
        find.text('Максимальный PO₂ должен быть больше минимального'),
        delta: -200,
      );
      expect(
        find.text('Максимальный PO₂ должен быть больше минимального'),
        findsOneWidget,
      );
      await edit(tester, 'Минимальный PO₂, bar', '0,18');
      await tap(tester, 'Рассчитать MOD');
      await visible(tester, find.text('MOD'));
      expect(find.text('18.2 м'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'density uses real gas and keeps separate drafts across tool navigation',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Кислород O₂, %', '32');
      await choose(tester, 'Плотность газа');
      await tap(tester, 'Рассчитать');
      await visible(tester, find.text('Плотность'));
      final expected = GasProperties.densityGramsPerLitre(
        Gas(oxygen: .21, helium: .35),
        45,
        model.selected.settings.pressure,
      );
      expect(find.text('${expected.toStringAsFixed(4)} г/л'), findsOneWidget);
      await choose(tester, 'MOD и END');
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Кислород O₂, %'),
            )
            .controller!
            .text,
        '32',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Кислород O₂, %'),
            )
            .controller!
            .text,
        '32',
      );
    },
  );
  testWidgets(
    'unit change converts depth and PO2 and retains invalid draft unit tags',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Глубина, м', '45');
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      final depth = find.widgetWithText(TextFormField, 'Глубина, ft');
      await visible(tester, depth, delta: -200);
      expect(
        double.parse(tester.widget<TextFormField>(depth).controller!.text),
        closeTo(Units.metresToFeet(45), 1e-12),
      );
      await edit(tester, 'Глубина, ft', 'ошибка');
      model.setUnits(DisplayUnits.metric);
      await tester.pumpAndSettle();
      expect(find.textContaining('Единицы полей сохранены'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Глубина, ft'),
            )
            .controller!
            .text,
        'ошибка',
      );
      await edit(tester, 'Глубина, ft', '100');
      await visible(
        tester,
        find.widgetWithText(TextFormField, 'Глубина, м'),
        delta: -200,
      );
      expect(
        double.parse(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Глубина, м'),
              )
              .controller!
              .text,
        ),
        closeTo(Units.feetToMetres(100), 1e-12),
      );
      expect(model.planRequest.revision, 0);
    },
  );
  testWidgets(
    'custom mix transfers only on explicit confirmed action, blocks stale and impossible results',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final before = model.selected.levels.first.breathing.gas;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await choose(tester, 'Подбор смеси');
      await tap(tester, 'Рассчитать');
      await tap(tester, 'Добавить газ в план');
      expect(model.selected.levels.first.breathing.gas, same(before));
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.first.breathing.gas, same(before));
      await tap(tester, 'Добавить газ в план');
      await tester.tap(find.text('Применить газ'));
      await tester.pumpAndSettle();
      final expected = GasProperties.customMix(
        depthMetres: 45,
        oxygenBar: Units.ataToBar(1.3),
        maximumEndMetres: 30,
        oxygenNarcosis: 1,
        pressure: model.selected.settings.pressure,
      );
      expect(
        model.selected.levels.first.breathing.gas.toJson(),
        expected.toJson(),
      );
      await edit(tester, 'Максимальный END, м', '0');
      await visible(tester, find.text('Добавить газ в план'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Добавить газ в план'),
            )
            .onPressed,
        isNull,
      );
      await edit(tester, 'Максимальный PO₂, bar', '100');
      await tap(tester, 'Рассчитать');
      expect(
        find.textContaining('Невозможно получить физическую смесь'),
        findsOneWidget,
      );
      expect(
        model.selected.levels.first.breathing.gas.toJson(),
        expected.toJson(),
      );
    },
  );
  testWidgets(
    'zero oxygen yields unavailable depths and numeric density survives imperial conversion',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Кислород O₂, %', '0');
      await edit(tester, 'Гелий He, %', '100');
      await tap(tester, 'Рассчитать MOD');
      await visible(tester, find.text('MOD'));
      expect(find.text('Недоступно для этих условий'), findsNWidgets(2));
      await choose(tester, 'Плотность газа');
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      await tap(tester, 'Рассчитать');
      await visible(tester, find.text('Плотность'));
      final expected = GasProperties.densityGramsPerLitre(
        Gas(oxygen: .21, helium: .35),
        45,
        model.selected.settings.pressure,
      );
      expect(find.text('${expected.toStringAsFixed(4)} г/л'), findsOneWidget);
      model.replaceSettings(
        CalculationSettings.fromJson({
          ...model.selected.settings.toJson(),
          'altitude': AltitudeSettings(
            enabled: true,
            diveAltitudeMetres: 2000,
          ).toJson(),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Предыдущий результат · пересчитайте'), findsOneWidget);
      await tap(tester, 'Рассчитать', delta: -200);
      await visible(tester, find.text('Результат актуален'));
      expect(find.text('Результат актуален'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'overflowing conversion and unavailable altitude preserve inputs without a widget exception',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Глубина, м', '1e308');
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Глубина, м'),
            )
            .controller!
            .text,
        '1e308',
      );
      model.replaceSettings(
        CalculationSettings.fromJson({
          ...model.selected.settings.toJson(),
          'altitude': AltitudeSettings(
            enabled: true,
            diveAltitudeMetres: 12000,
          ).toJson(),
        }),
      );
      await tester.pumpAndSettle();
      await visible(
        tester,
        find.textContaining('Поверхностное давление недоступно'),
        delta: -200,
      );
      expect(
        find.textContaining('Поверхностное давление недоступно'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'opening another document replaces visible tool draft without leaking previous input',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      await edit(tester, 'Кислород O₂, %', '32');
      final document = documentFixture();
      model.restoreDocument(
        document.copyWith(
          toolDrafts: {
            'mod': {
              'properties:modEnd:oxygen': '50',
              'properties:modEnd:helium': '0',
              'properties:modEnd:units': 'metric',
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Кислород O₂, %'),
            )
            .controller!
            .text,
        '50',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('gas tools $size text200 stay usable', (tester) async {
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
          home: Scaffold(body: GasPropertyTools(model: model)),
        ),
      );
      for (final label in ['MOD и END', 'Плотность газа', 'Подбор смеси']) {
        await choose(tester, label);
        await tap(
          tester,
          label == 'MOD и END' ? 'Рассчитать MOD' : 'Рассчитать',
        );
        await visible(tester, find.text('Результат актуален'));
        expect(find.text('Результат актуален'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
