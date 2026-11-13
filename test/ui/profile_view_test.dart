import 'dart:io';
import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:deco_planner/domain/profile_data.dart';
import 'package:deco_planner/ui/features/documents/document_session.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/plan/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'profile zoom and keyboard pan preserve real result across theme and units',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.runAsync(() => model.calculateSelection());
      final result = model.snapshot.result!;
      final plan = jsonEncode(model.planRequest.toJson());
      await tester.pumpWidget(PlannerApp(viewModel: model));
      // Mount the profile with the same notifier used by the application shell.
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileView(
            data: ProfileData(
              result: result,
              settings: model.selected.settings,
            ),
            model: model,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Увеличить масштаб времени'));
      await tester.pumpAndSettle();
      expect(find.text('Масштаб времени ×2'), findsOneWidget);
      final horizontal = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      final state = tester.state<ScrollableState>(horizontal);
      var panFocused = false;
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused?.findAncestorWidgetOfExactType<IconButton>()?.tooltip ==
            'Прокрутить профиль вправо') {
          panFocused = true;
          break;
        }
      }
      expect(panFocused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0));
      model.setTheme(ThemeMode.dark);
      model.setUnits(DisplayUnits.imperial);
      await tester.pumpAndSettle();
      expect(find.text('Масштаб времени ×2'), findsOneWidget);
      expect(model.snapshot.result, same(result));
      expect(jsonEncode(model.planRequest.toJson()), plan);
      await tester.tap(find.text('Весь профиль'));
      await tester.pumpAndSettle();
      expect(find.text('Масштаб времени ×1'), findsOneWidget);
      expect(state.position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile selects points, saves frozen comparison, and confirms clear without altering plan',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      final root = Directory.systemTemp.createTempSync('profile-widget-');
      final session = DocumentSession(
        model: model,
        repository: DocumentRepository(root),
        autosaveDelay: const Duration(days: 1),
      );
      addTearDown(() {
        model.dispose();
        root.deleteSync(recursive: true);
      });
      await tester.runAsync(() => model.calculateSelection());
      final data = ProfileData(
        result: model.snapshot.result!,
        settings: model.selected.settings,
      );
      final revision = model.planRequest.revision;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileView(data: data, model: model, documents: session),
          ),
        );
        expect(find.text('Актуальный снимок'), findsOneWidget);
        final next = find.text('Следующая точка');
        await Scrollable.ensureVisible(tester.element(next), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text('Точка 2 из ${data.points.length}'), findsOneWidget);
        await tester.tap(find.text('Сохранить сравнение'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'До изменения',
        );
        await tester.tap(find.text('Сохранить снимок'));
        await tester.pumpAndSettle();
        expect(session.document.comparisons.length, 1);
        expect(
          session.document.comparisons.single.results.values.single.result
              .toJson(),
          data.result.toJson(),
        );
        expect(model.planRequest.revision, revision);
        await tester.tap(find.text('Очистить сравнения'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();
        expect(session.document.comparisons.length, 1);
        await tester.tap(find.text('Очистить сравнения'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить снимки'));
        await tester.pumpAndSettle();
        expect(session.document.comparisons, isEmpty);
        expect(model.planRequest.revision, revision);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }
    },
  );
  testWidgets(
    'profile supports chart touch, keyboard points, and stale result protection',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      final root = Directory.systemTemp.createTempSync('profile-input-');
      final session = DocumentSession(
        model: model,
        repository: DocumentRepository(root),
        autosaveDelay: const Duration(days: 1),
      );
      addTearDown(() {
        model.dispose();
        root.deleteSync(recursive: true);
      });
      await tester.runAsync(() => model.calculateSelection());
      final data = ProfileData(
        result: model.snapshot.result!,
        settings: model.selected.settings,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileView(data: data, model: model, documents: session),
          ),
        );
        final chart = find
            .descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label ==
                        'График глубины. Для выбора точек используйте ползунок и кнопки ниже.',
              ),
              matching: find.byType(CustomPaint),
            )
            .first;
        final bounds = tester.getRect(chart);
        await tester.tapAt(Offset(bounds.right - 1, bounds.center.dy));
        await tester.pumpAndSettle();
        expect(
          find.text('Точка ${data.points.length} из ${data.points.length}'),
          findsOneWidget,
        );
        await tester.tapAt(Offset(bounds.left + 1, bounds.center.dy));
        await tester.pumpAndSettle();
        expect(find.text('Точка 1 из ${data.points.length}'), findsOneWidget);
        final slider = find.byType(Slider);
        await Scrollable.ensureVisible(tester.element(slider), alignment: .3);
        await tester.pumpAndSettle();
        var sliderFocused = false;
        for (var i = 0; i < 20; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              (focused.widget is Slider ||
                  focused.findAncestorWidgetOfExactType<Slider>() != null)) {
            sliderFocused = true;
            break;
          }
        }
        expect(sliderFocused, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('Точка 2 из ${data.points.length}'), findsOneWidget);
        model.setSurfaceInterval(45);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Снимок предыдущего результата · входы изменены'),
          -250,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Снимок предыдущего результата · входы изменены'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Сохранить сравнение'),
              )
              .onPressed,
          isNull,
        );
        expect(data.points.last.state, same(data.result.finalState));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }
    },
  );
  testWidgets(
    'workspace can reopen an old graph with its frozen settings after plan changes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      final root = Directory.systemTemp.createTempSync('stale-profile-');
      final session = DocumentSession(
        model: model,
        repository: DocumentRepository(root),
        autosaveDelay: const Duration(days: 1),
      );
      addTearDown(() {
        model.dispose();
        root.deleteSync(recursive: true);
      });
      await tester.runAsync(() => model.calculateSelection());
      final old = model.snapshot.result!, settings = model.selected.settings;
      model.replaceSettings(
        CalculationSettings.fromJson({
          ...settings.toJson(),
          'model': DecompressionModel.buhlmannC.name,
        }),
      );
      try {
        await tester.pumpWidget(
          PlannerApp(viewModel: model, documentSession: session),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('profile-view'));
        await tester.scrollUntilVisible(
          button,
          250,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await Scrollable.ensureVisible(tester.element(button), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text('Снимок предыдущего результата · входы изменены'),
          findsOneWidget,
        );
        final profile = tester.widget<ProfileView>(find.byType(ProfileView));
        expect(profile.data.settings.model, settings.model);
        expect(profile.data.result, same(old));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }
    },
  );
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'profile/tissues $size text200 has readable numerical alternatives',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        await tester.runAsync(() => model.calculateSelection());
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileView(
              data: ProfileData(
                result: model.snapshot.result!,
                settings: model.selected.settings,
              ),
              model: model,
            ),
          ),
        );
        final table = find.text('Численная таблица профиля');
        await tester.scrollUntilVisible(
          table,
          300,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
          maxScrolls: 100,
        );
        await tester.ensureVisible(table);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(table);
        await tester.pumpAndSettle();
        expect(find.text('Численная таблица профиля'), findsOneWidget);
        expect(find.text('0.000 мин · 0 м'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
