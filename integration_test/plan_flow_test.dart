import 'package:deco_planner/data/services/planner_pdf.dart';
import 'package:deco_planner/domain/planner_report.dart';
import 'package:printing/printing.dart';
import 'package:deco_planner/ui/features/export/report_view.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/tools/mixing_tools.dart';
import 'package:deco_planner/ui/features/tools/mixing_view_model.dart';
import 'package:deco_planner/ui/features/range/range_view.dart';
import 'package:deco_planner/ui/features/range/range_view_model.dart';
import 'package:deco_planner/ui/features/range/range_cell_view.dart';
import 'package:deco_planner/ui/features/documents/document_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import '../test/support/document_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native application storage location, verified publication and last-good recovery',
    (tester) async {
      await tester.runAsync(() async {
        final app = await DocumentRepository.application();
        final testBase = Directory(
          p.join(app.directory.parent.path, 'integration-test-data'),
        );
        await testBase.create(recursive: true);
        final root = await testBase.createTemp('document-');
        try {
          final repository = DocumentRepository(root);
          final first = documentFixture();
          await repository.save(first);
          await repository.save(
            documentFixture(name: 'Native revision2', revision: 2),
          );
          expect(
            (await repository.load(first.id)).document.name,
            'Native revision2',
          );
          await File(
            p.join(root.path, '${first.id}.json'),
          ).writeAsString('{broken');
          final recovered = await repository.load(first.id);
          expect(recovered.recoveredFromBackup, isTrue);
          expect(recovered.document.toJson(), first.toJson());
        } finally {
          await root.delete(recursive: true);
        }
      });
    },
  );
  testWidgets(
    'native document library saves, restores and deletes a plan',
    (tester) async {
      debugPrint('LIBRARY_PHASE=repository');
      final app = await DocumentRepository.application();
      final testBase = Directory(
        p.join(app.directory.parent.path, 'integration-test-data'),
      );
      await testBase.create(recursive: true);
      final root = await testBase.createTemp('library-');
      final model = PlannerViewModel();
      final session = DocumentSession(
        model: model,
        repository: DocumentRepository(root),
      );
      addTearDown(() async {
        session.dispose();
        model.dispose();
        await root.delete(recursive: true);
      });
      debugPrint('LIBRARY_PHASE=mount');
      await tester.pumpWidget(
        PlannerApp(viewModel: model, documentSession: session),
      );
      await tester.pumpAndSettle();
      debugPrint('LIBRARY_PHASE=open-library');
      await tester.tap(find.byTooltip('Документы'));
      await tester.pumpAndSettle();
      debugPrint('LIBRARY_PHASE=save');
      await tester.tap(find.text('Сохранить план'));
      await tester.pumpAndSettle();
      expect(find.text('План сохранён'), findsOneWidget);
      final savedId = session.document.id;
      debugPrint('LIBRARY_PHASE=rename');
      await session.rename(savedId, 'Нативный план');
      debugPrint('LIBRARY_PHASE=new');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Новый план'));
      await tester.pumpAndSettle();
      expect(session.document.id, isNot(savedId));
      final savedCard = find.ancestor(
        of: find.text('Нативный план'),
        matching: find.byType(Card),
      );
      final open = find.descendant(
        of: savedCard,
        matching: find.text('Открыть'),
      );
      await tester.ensureVisible(open);
      debugPrint('LIBRARY_PHASE=open-saved');
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(session.document.id, savedId);
      expect(find.text('Планировщик'), findsOneWidget);
      debugPrint('LIBRARY_PHASE=open-library');
      await tester.tap(find.byTooltip('Документы'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Нативный план'),
            matching: find.byType(Card),
          ),
          matching: find.text('Удалить'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();
      expect(find.text('План удалён'), findsOneWidget);
      expect((await session.list()).map((e) => e.id), isNot(contains(savedId)));
      expect(tester.takeException(), isNull);
      debugPrint('LIBRARY_PHASE=complete');
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
  testWidgets(
    'native gas properties reject invalid gas and explicitly transfer a calculated mix',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      Finder vertical() => find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last;
      Future<void> reveal(Finder target, double delta) async {
        await tester.scrollUntilVisible(target, delta, scrollable: vertical());
        await Scrollable.ensureVisible(tester.element(target), alignment: .3);
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Кислород O₂, %'),
        '80',
      );
      final helium = find.widgetWithText(TextFormField, 'Гелий He, %');
      await reveal(helium, 150);
      await tester.enterText(helium, '30');
      final calculate = find.text('Рассчитать MOD');
      await reveal(calculate, 150);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      await reveal(find.text('O₂ + He не должны превышать100%').first, -150);
      expect(find.text('O₂ + He не должны превышать100%'), findsNWidgets(2));
      final select = find
          .ancestor(
            of: find.text('Инструмент'),
            matching: find.byWidgetPredicate(
              (w) => w is DropdownButtonFormField,
            ),
          )
          .first;
      await reveal(select, -150);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подбор смеси').last);
      await tester.pumpAndSettle();
      await reveal(find.text('Рассчитать'), 150);
      await tester.tap(find.text('Рассчитать'));
      await tester.pumpAndSettle();
      final apply = find.text('Добавить газ в план');
      await reveal(apply, 150);
      final original = model.selected.levels.first.breathing.gas;
      expect(original.oxygen, .21);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(model.selected.levels.first.breathing.gas, same(original));
      await tester.tap(find.text('Применить газ'));
      await tester.pumpAndSettle();
      expect(
        model.selected.levels.first.breathing.gas.oxygen,
        closeTo(Units.ataToBar(1.3) / 5.51325, 1e-12),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native mixing calculates recipe and cost and invalidates instructions after edit',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Смешивание газов'));
      await tester.pumpAndSettle();
      Future<void> reveal(Finder target, double delta) async {
        await tester.scrollUntilVisible(
          target,
          delta,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await Scrollable.ensureVisible(tester.element(target), alignment: .3);
        await tester.pumpAndSettle();
      }

      final calculate = find.text('Рассчитать рецепт');
      await reveal(calculate, 200);
      await tester.runAsync(() async {
        await tester.tap(calculate);
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
            throw StateError('Native mixing timeout');
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(vm.current, isTrue);
      });
      await tester.pumpAndSettle();
      final cost = find.text('Объём и стоимость');
      await reveal(cost, 200);
      await tester.tap(cost);
      await tester.pumpAndSettle();
      final price = find.text('Пересчитать стоимость');
      await reveal(price, 200);
      await tester.tap(price);
      await tester.pumpAndSettle();
      final expected =
          ((.32 - .21) * 200 / .79) * 24 / Units.barPerAta * .1 + 10;
      await reveal(find.text('Итого: ${expected.toStringAsFixed(2)}'), 200);
      expect(
        find.text('Итого: ${expected.toStringAsFixed(2)}'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final oxygen = find.widgetWithText(TextFormField, 'Целевой O₂, %');
      await reveal(oxygen, -200);
      await tester.enterText(oxygen, '36');
      await tester.pumpAndSettle();
      final stale = find.text(
        'Предыдущий рецепт неактуален. Инструкция скрыта до успешного пересчёта.',
      );
      await reveal(stale, 200);
      expect(stale, findsOneWidget);
      expect(find.text('Объём и стоимость'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('native range calculates real cell and opens full result', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(PlannerApp(viewModel: model));
    await tester.pumpAndSettle();
    Future<void> reveal(Finder target, double delta) async {
      await tester.scrollUntilVisible(
        target,
        delta,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await Scrollable.ensureVisible(tester.element(target), alignment: .3);
      await tester.pumpAndSettle();
    }

    final button = find.byKey(const Key('range-view'));
    await reveal(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final calculate = find.text('Построить таблицы');
    await reveal(calculate, 200);
    await tester.runAsync(() async {
      await tester.tap(calculate);
      final vm =
          tester
                  .widget<ListenableBuilder>(
                    find
                        .descendant(
                          of: find.byType(RangeView),
                          matching: find.byType(ListenableBuilder),
                        )
                        .first,
                  )
                  .listenable
              as RangeViewModel;
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (vm.status == RangeStatus.calculating) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Native range timeout');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(vm.status, RangeStatus.complete);
      expect(vm.cells.single.runtimeMin, closeTo(27.333333333333332, 1e-10));
    });
    await tester.pumpAndSettle();
    final cell = find.text('30 м · 20.0 мин · Базовый');
    await reveal(cell, 200);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.byType(RangeCellView), findsOneWidget);
    expect(find.textContaining('Runtime 27.333 мин'), findsOneWidget);
    final preview = find.text('Печатный вид');
    await reveal(preview, 200);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.byType(ReportView), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('Снимок актуальных результатов'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Сохранить PDF'),
          )
          .onPressed,
      isNotNull,
    );
    expect(model.planRequest.revision, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native PDF generates and rasterizes offline with bundled Cyrillic fonts',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.runAsync(() async {
        final request = model.selected;
        final report = PlannerReport.dive(
          result: calculateBuhlmann(request),
          request: request,
          units: DisplayUnits.metric,
        );
        final bytes = await const PlannerPdf().build(report);
        final info = await Printing.info();
        expect(info.canRaster, isTrue);
        expect(info.canPrint, isTrue);
        final page = await Printing.raster(bytes, pages: [0], dpi: 72).first;
        expect(page.width, greaterThan(500));
        expect(page.height, greaterThan(800));
        final dir = await Directory.systemTemp.createTemp(
          'planner-pdf-native-',
        );
        await File(p.join(dir.path, 'report.pdf')).writeAsBytes(bytes);
        await File(
          p.join(dir.path, 'page.png'),
        ).writeAsBytes(await page.toPng());
        debugPrint('PLANNER_PDF_CAPTURE=${dir.path}');
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('native OC calculation, theme and physical result preservation', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PlannerApp(viewModel: model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Расчётные настройки'));
    await tester.pumpAndSettle();
    final rmv = find.byKey(const Key('settings-bottomRmvLitresPerMin'));
    await tester.scrollUntilVisible(
      rmv,
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.ensureVisible(rmv);
    await tester.pumpAndSettle();
    await tester.enterText(rmv, '21');
    await tester.tap(find.text('Применить к погружению'));
    await tester.pumpAndSettle();
    expect(model.selected.settings.bottomRmvLitresPerMin, 21);
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    final calculate = find.byKey(const Key('calculate'));
    await tester.scrollUntilVisible(
      calculate,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(calculate);
      final clock = Stopwatch()..start();
      while (model.calculating) {
        if (clock.elapsed > const Duration(seconds: 10)) {
          throw StateError('Native calculation timed out.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(model.snapshot.status, PlanStatus.ready);
    expect(
      model.snapshot.result!.runtimeMin,
      closeTo(27.333333333333332, 1e-10),
    );
    final usageButton = find.byKey(const Key('gas-usage'));
    await tester.scrollUntilVisible(
      usageButton,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(usageButton);
    await tester.pumpAndSettle();
    await tester.tap(usageButton);
    await tester.pumpAndSettle();
    final expectedUsage = calculateGasUsage(
      model.snapshot.result!,
      model.selected.settings,
    );
    expect(
      find.textContaining(
        'Расход ${expectedUsage.gases.single.litres.toStringAsFixed(1)} L',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Давление расхода ${(expectedUsage.gases.single.litres / 24).toStringAsFixed(1)} bar',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final profileButton = find.byKey(const Key('profile-view'));
    await tester.scrollUntilVisible(
      profileButton,
      -150,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(profileButton),
      alignment: .3,
    );
    await tester.pumpAndSettle();
    await tester.tap(profileButton);
    await tester.pumpAndSettle();
    expect(find.text('Профиль и ткани'), findsOneWidget);
    expect(find.text('Актуальный снимок'), findsOneWidget);
    final zoom = find.byTooltip('Увеличить масштаб времени');
    await Scrollable.ensureVisible(tester.element(zoom), alignment: .3);
    await tester.pumpAndSettle();
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    expect(find.text('Масштаб времени ×2'), findsOneWidget);
    await tester.tap(find.byTooltip('Прокрутить профиль вправо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Весь профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Масштаб времени ×1'), findsOneWidget);
    final nextPoint = find.text('Следующая точка');
    await tester.scrollUntilVisible(
      nextPoint,
      150,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await Scrollable.ensureVisible(tester.element(nextPoint), alignment: .3);
    await tester.pumpAndSettle();
    await tester.tap(nextPoint);
    await tester.pumpAndSettle();
    expect(
      find.text('Точка 2 из ${model.snapshot.result!.segments.length + 1}'),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final status = find.text('Расчёт завершён');
    await tester.scrollUntilVisible(
      status,
      -150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(status);
    await tester.pumpAndSettle();
    expect(status, findsOneWidget);
    final output = await Directory.systemTemp.createTemp(
      'planner-native-capture-',
    );
    Future<void> save(String file) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File.fromUri(
        output.uri.resolve(file),
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    model.setTheme(ThemeMode.light);
    await tester.pumpAndSettle();
    await save('native-oc-light.png');
    model.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    await save('native-oc-dark.png');
    expect(model.snapshot.status, PlanStatus.ready);
    // Host copies only these generated app frames, never user documents.
    debugPrint('PLANNER_NATIVE_CAPTURES=${output.path}');
    expect(tester.takeException(), isNull);
  });
  testWidgets('native CCR editor to linked bailout preserves original result', (
    tester,
  ) async {
    final model = PlannerViewModel();
    addTearDown(model.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PlannerApp(viewModel: model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<BreathingMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CCR — ребризер').last);
    await tester.pumpAndSettle();
    for (final field in [
      ('Глубина, м', '45'),
      ('Длительность, мин', '25'),
      ('Гелий He, %', '35'),
      ('Setpoint, ATA', '${Units.barToAta(1.3)}'),
    ]) {
      await tester.enterText(
        find.widgetWithText(TextFormField, field.$1),
        field.$2,
      );
    }
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('create-bailout'));
    await tester.scrollUntilVisible(
      create,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bailout-time')), '25');
    await tester.tap(find.byKey(const Key('bailout-save')));
    await tester.pumpAndSettle();
    final calculate = find.byKey(const Key('calculate'));
    await tester.scrollUntilVisible(
      calculate,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(calculate);
      final clock = Stopwatch()..start();
      while (model.calculating) {
        if (clock.elapsed > const Duration(seconds: 10)) {
          throw StateError('Native bailout timed out');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(model.snapshot.status, PlanStatus.ready);
    expect(model.displaySnapshot.status, PlanStatus.ready);
    // Independent normalized B1b escape at25min, no deco gases.
    expect(
      model.displaySnapshot.result!.runtimeMin,
      closeTo(68.33333333333333, 1e-10),
    );
    expect(
      model.displaySnapshot.result!.segments.first.physical.breathing.mode,
      BreathingMode.ccr,
    );
    expect(
      model.displaySnapshot.result!.segments.last.physical.breathing.mode,
      BreathingMode.oc,
    );
    final source = jsonEncode(model.snapshot.result!.toJson());
    final branchId = model.selectedBailout!.id;
    model.selectBailout(null);
    await tester.pumpAndSettle();
    expect(jsonEncode(model.displaySnapshot.result!.toJson()), source);
    model.selectBailout(branchId);
    await tester.pumpAndSettle();
    final heading = find.text('Bailout · результат');
    if (heading.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        heading,
        150,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    final output = await Directory.systemTemp.createTemp(
      'planner-native-bailout-',
    );
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      model.setTheme(theme);
      await tester.pumpAndSettle();
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File.fromUri(
        output.uri.resolve('native-bailout-${theme.name}.png'),
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
    debugPrint('PLANNER_BAILOUT_CAPTURES=${output.path}');
    expect(tester.takeException(), isNull);
  });
}
