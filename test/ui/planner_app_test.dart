import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 599.0, 600.0, 999.0, 1000.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'adaptive shell width$width scale$scale preserves profile and has no overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final model = PlannerViewModel();
          addTearDown(model.dispose);
          await tester.pumpWidget(PlannerApp(viewModel: model));
          await tester.pumpAndSettle();
          expect(find.text('Планировщик'), findsOneWidget);
          expect(tester.takeException(), isNull);
          model.setTheme(ThemeMode.dark);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.physicalSize = const Size(740, 375);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(model.selected.levels.first.depthMetres, 30);
        },
      );
    }
  }
  testWidgets('OC edit, real worker calculation, result and stale state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(PlannerApp(viewModel: model));
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    final duration = find.widgetWithText(TextFormField, 'Длительность, мин');
    await tester.enterText(duration, '25');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(model.selected.levels.first.durationMin, 25);
    final calculate = find.byKey(const Key('calculate'));
    await tester.ensureVisible(calculate);
    await tester.runAsync(() async {
      await tester.tap(calculate);
      final elapsed = Stopwatch()..start();
      while (model.calculating) {
        if (elapsed.elapsed > const Duration(seconds: 5)) {
          throw StateError('Real isolate UI calculation did not complete.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(model.snapshot.status, PlanStatus.ready);
    expect(find.text('Расчёт завершён'), findsOneWidget);
    expect(find.text('Один дайвер · без резервов'), findsOneWidget);
    model.replaceLevels([
      Level(
        depthMetres: 30,
        durationMin: 30,
        breathing: model.selected.levels.first.breathing,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Входы изменены — пересчитайте'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid editor remains open; cancel does not mutate the profile',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Длительность, мин'),
        '-1',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Введите конечное число не меньше нуля'),
        findsOneWidget,
      );
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отменить изменения'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.first.durationMin, 20);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dirty Back can continue editing without losing the draft', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(PlannerApp(viewModel: model));
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Длительность, мин'),
      '25',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Сохранить изменения уровня?'), findsOneWidget);
    await tester.tap(find.text('Продолжить редактирование'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    expect(model.selected.levels.first.durationMin, 20);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(model.selected.levels.first.durationMin, 25);
  });
  testWidgets(
    'saving unchanged imperial form preserves exact canonical values',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final original = Level(
        depthMetres: 30.123456789,
        durationMin: 20.123456789,
        breathing: BreathingGas.ccr(
          Gas(oxygen: .213456789, helium: .312345678),
          1.323456789,
        ),
      );
      model.replaceLevels([original]);
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.first.toJson(), original.toJson());
    },
  );
  testWidgets('repeat interval requires explicit validated save', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    model.addDive();
    await tester.pumpWidget(PlannerApp(viewModel: model));
    await tester.tap(find.text('Интервал 60 мин · изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Длительность, мин'),
      '45',
    );
    expect(model.selected.surfaceIntervalMin, 60);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(model.selected.surfaceIntervalMin, 45);
  });
  testWidgets(
    'computed high-PO2 plan displays unavailable CNS reason and numeric OTU',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      model.replaceLevels([
        Level(
          depthMetres: 45,
          durationMin: 25,
          breathing: BreathingGas.oc(Gas(oxygen: .21, helium: .35)),
        ),
      ]);
      final settings = model.selected.settings;
      model.replaceSettings(
        CalculationSettings(
          model: settings.model,
          pressure: settings.pressure,
          stopGrid: StopGrid.imperial(),
          gradientFactors: settings.gradientFactors,
        ),
      );
      model.replaceSwitches([
        GasSwitch(
          depthMetres: Units.feetToMetres(20),
          breathing: BreathingGas.oc(Gas(oxygen: 1)),
        ),
      ]);
      await tester.runAsync(model.calculate);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      expect(model.snapshot.status, PlanStatus.ready);
      expect(model.snapshot.result!.finalState.oxygen.cnsFraction, isNull);
      expect(find.text('Недоступен'), findsOneWidget);
      expect(find.textContaining('CNS недоступен: ppO₂'), findsOneWidget);
      expect(model.snapshot.result!.finalState.oxygen.otu, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'three destinations and local help survive responsive navigation',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Газовые инструменты'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Кислород O₂, %'),
        '32',
      );
      await tester.scrollUntilVisible(
        find.text('Рассчитать MOD'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Рассчитать MOD')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Рассчитать MOD'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('MOD'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('MOD'), findsOneWidget);
      expect(find.textContaining('34.2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Тёмная'));
      await tester.pumpAndSettle();
      expect(model.theme, ThemeMode.dark);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Тёмная'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(find.text('32'), findsOneWidget);
      await tester.tap(find.byTooltip('Справка'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Кислородная нагрузка'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'level add, reorder, confirmed delete and cancelled editor use real controls',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      final add = find.text('Добавить уровень');
      await tester.scrollUntilVisible(
        add,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.length, 2);
      final up = find.byTooltip('Уровень 2 вверх');
      await tester.scrollUntilVisible(
        up,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(up);
      await tester.tap(up);
      await tester.pumpAndSettle();
      expect(model.selected.levels.first.depthMetres, 21);
      final remove = find.byTooltip('Удалить уровень 2');
      await tester.scrollUntilVisible(
        remove,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(model.selected.levels.length, 2);
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.length, 1);
      await tester.scrollUntilVisible(
        add,
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(model.selected.levels.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dive add and confirmed delete preserve the remaining dive identity',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final first = model.selected.id;
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.tap(find.text('Добавить погружение'));
      await tester.pumpAndSettle();
      expect(model.dives.length, 2);
      expect(model.selectedIndex, 1);
      await tester.tap(find.text('Удалить погружение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(model.dives.length, 2);
      await tester.tap(find.text('Удалить погружение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(model.dives.single.id, first);
      expect(tester.takeException(), isNull);
    },
  );
}
