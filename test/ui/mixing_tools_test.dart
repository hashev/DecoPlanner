import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/ui/features/tools/mixing_tools.dart';
import 'package:deco_planner/ui/features/tools/mixing_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/mixing_fixtures.dart';

Future<void> show(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last,
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await show(tester, field, delta: -250);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> calculate(WidgetTester tester) async {
  final button = find.text('Рассчитать рецепт');
  await show(tester, button);
  await tester.runAsync(() async {
    await tester.tap(button);
    final vm =
        tester
                .widget<ListenableBuilder>(
                  find
                      .descendant(
                        of: find.byType(MixingToolView),
                        matching: find.byType(ListenableBuilder),
                      )
                      .first,
                )
                .listenable
            as MixingViewModel;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (vm.status == MixingStatus.calculating) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Mixing isolate timed out');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'partial recipe updates, hides stale instructions, drains and reports impossible mixture',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: MixingToolView(model: model)));
      await calculate(tester);
      await show(tester, find.textContaining('Актуальный рецепт'));
      expect(find.text('Добавить O₂'), findsOneWidget);
      await edit(tester, 'Целевой O₂, %', '36');
      await show(
        tester,
        find.text(
          'Предыдущий рецепт неактуален. Инструкция скрыта до успешного пересчёта.',
        ),
      );
      expect(find.text('Добавить O₂'), findsNothing);
      await calculate(tester);
      await show(tester, find.textContaining('Актуальный рецепт'));
      await edit(tester, 'Исходный O₂, %', '100');
      await edit(tester, 'Исходное давление, bar', '200');
      await edit(tester, 'Целевой O₂, %', '21');
      await calculate(tester);
      await show(tester, find.textContaining('Стравить'));
      expect(find.textContaining('Стравить'), findsOneWidget);
      await edit(tester, 'Целевой O₂, %', '0');
      await calculate(tester);
      await show(tester, find.textContaining('Невозможно получить смесь'));
      expect(find.textContaining('Невозможно получить смесь'), findsOneWidget);
      expect(find.text('Объём и стоимость'), findsNothing);
      expect(model.planRequest.revision, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('continuous method exposes applicable options and real recipe', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(home: MixingToolView(model: model)));
    final method = find.byType(DropdownButtonFormField<MixingMethod>);
    await tester.tap(method);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Непрерывное смешивание').last);
    await tester.pumpAndSettle();
    expect(find.text('Порядок добавления'), findsNothing);
    final variant = find.byType(DropdownButtonFormField<ContinuousVariant>);
    await show(tester, variant, delta: -250);
    await tester.tap(variant);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Два потока').last);
    await tester.pumpAndSettle();
    expect(find.text('Путь потоков'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await calculate(tester);
    await show(tester, find.textContaining('Актуальный рецепт'));
    expect(find.text('van der Waals · 294.0 K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cost uses source amounts, permits zero prices and invalidates for a new recipe',
    (tester) async {
      final model = PlannerViewModel();
      final mixer = MixingViewModel();
      addTearDown(model.dispose);
      addTearDown(mixer.dispose);
      await tester.runAsync(() => mixer.calculate(input()));
      await tester.pumpWidget(
        MaterialApp(
          home: MixingCostView(model: model, mixer: mixer),
        ),
      );
      final button = find.text('Пересчитать стоимость');
      await show(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final oxygenBar = (.32 - .21) * 200 / .79;
      final total = oxygenBar * 24 / Units.barPerAta * .1 + 10;
      await show(tester, find.text('Итого: ${total.toStringAsFixed(2)}'));
      expect(find.text('Итого: ${total.toStringAsFixed(2)}'), findsOneWidget);
      await edit(tester, 'Цена O₂ за L', '0');
      await edit(tester, 'Цена He за L', '0');
      await edit(tester, 'Дозаправка, фиксированная плата', '0');
      await show(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await show(tester, find.text('Итого: 0.00'));
      expect(find.text('Итого: 0.00'), findsOneWidget);
      mixer.invalidate();
      await tester.pumpAndSettle();
      await show(tester, button, delta: -250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Пересчитать стоимость'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'partial order and imperial pressures preserve recipe physics across units',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: MixingToolView(model: model)));
      final order = find.byType(DropdownButtonFormField<FillOrder>);
      await show(tester, order, delta: -250);
      await tester.tap(order);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сначала He').last);
      await tester.pumpAndSettle();
      await edit(tester, 'Целевой O₂, %', '18');
      await edit(tester, 'Целевой He, %', '45');
      await calculate(tester);
      await show(tester, find.textContaining('Актуальный рецепт'));
      final vm =
          tester
                  .widget<ListenableBuilder>(
                    find
                        .descendant(
                          of: find.byType(MixingToolView),
                          matching: find.byType(ListenableBuilder),
                        )
                        .first,
                  )
                  .listenable
              as MixingViewModel;
      final before = vm.result!.partial!;
      expect(before.steps.first.component, FillComponent.helium);
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      await show(
        tester,
        find.widgetWithText(TextFormField, 'Целевое давление, PSI'),
        delta: -250,
      );
      expect(
        double.parse(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Целевое давление, PSI'),
              )
              .controller!
              .text,
        ),
        closeTo(Units.barToPsi(200), 1e-10),
      );
      expect(vm.current, isTrue);
      await calculate(tester);
      expect(
        vm.result!.partial!.oxygenMolesPerLitre,
        closeTo(before.oxygenMolesPerLitre, 1e-12),
      );
      expect(
        vm.result!.partial!.heliumMolesPerLitre,
        closeTo(before.heliumMolesPerLitre, 1e-12),
      );
    },
  );
  testWidgets(
    'cost catalog copies water volume and rejects negative prices without losing draft',
    (tester) async {
      final model = PlannerViewModel(), mixer = MixingViewModel();
      addTearDown(model.dispose);
      addTearDown(mixer.dispose);
      await tester.runAsync(() => mixer.calculate(input()));
      await tester.pumpWidget(
        MaterialApp(
          home: MixingCostView(
            model: model,
            mixer: mixer,
            tanks: [
              TankPreset(
                id: 'tank-12',
                name: 'Один 12L',
                waterLitres: 12,
                workingBar: 232,
              ),
            ],
          ),
        ),
      );
      final tank = find.byType(DropdownButtonFormField<String>);
      await show(tester, tank, delta: 250);
      await tester.tap(tank);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Один 12L · 12.0 L').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Водяной объём баллона, L'),
            )
            .controller!
            .text,
        '12',
      );
      await edit(tester, 'Цена O₂ за L', '-1');
      final button = find.text('Пересчитать стоимость');
      await show(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await show(
        tester,
        find.text('Введите допустимое конечное число'),
        delta: -250,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Цена O₂ за L'),
            )
            .controller!
            .text,
        '-1',
      );
      expect(find.text('Введите допустимое конечное число'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('mixing and cost $size text200 remain usable', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: MixingToolView(model: model)));
      await calculate(tester);
      await show(tester, find.text('Объём и стоимость'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Объём и стоимость'));
      await tester.pumpAndSettle();
      final button = find.text('Пересчитать стоимость');
      await show(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await show(tester, find.text('Стоимость актуальна'));
      expect(find.text('Стоимость актуальна'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
