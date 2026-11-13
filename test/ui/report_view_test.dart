import 'dart:typed_data';
import 'package:deco_planner/data/services/pdf_actions.dart';
import 'package:deco_planner/domain/planner_report.dart';
import 'package:deco_planner/ui/features/export/report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Actions implements PdfActions {
  bool fail = false;
  int calls = 0;
  @override
  Future<PdfCapabilities> capabilities() async =>
      const PdfCapabilities(canPrint: true, canShare: true);
  @override
  bool get saveUsesShare => false;
  Future<PdfActionResult> perform() async {
    calls++;
    if (fail) throw StateError('dialog');
    return PdfActionResult.cancelled;
  }

  @override
  Future<PdfActionResult> print(Uint8List b) => perform();
  @override
  Future<PdfActionResult> save(Uint8List b, String n, Rect r) => perform();
  @override
  Future<PdfActionResult> share(Uint8List b, String n, Rect r) => perform();
}

void main() {
  testWidgets(
    'cancel and failure preserve preview; input changes block all export actions',
    (tester) async {
      final changes = ValueNotifier(true);
      addTearDown(changes.dispose);
      final actions = Actions();
      await tester.pumpWidget(
        MaterialApp(
          home: ReportView(
            report: PlannerReport('Погружение', [], []),
            changes: changes,
            isCurrent: () => changes.value,
            actions: actions,
            generate: (_) async => Uint8List.fromList([1]),
            preview: (_) => const Text('PDF страница'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Печать'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Действие отменено'), findsOneWidget);
      expect(find.text('PDF страница'), findsOneWidget);
      actions.fail = true;
      await tester.tap(find.text('Сохранить PDF'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Не удалось выполнить'), findsOneWidget);
      expect(find.text('PDF страница'), findsOneWidget);
      changes.value = false;
      await tester.pumpAndSettle();
      expect(find.text('PDF страница'), findsNothing);
      for (final label in ['Печать', 'Сохранить PDF', 'Поделиться']) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      expect(actions.calls, 2);
    },
  );
  testWidgets('failed generation retries without losing report', (
    tester,
  ) async {
    final changes = ValueNotifier(true);
    addTearDown(changes.dispose);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportView(
          report: PlannerReport('План', [], []),
          changes: changes,
          isCurrent: () => true,
          generate: (_) async {
            if (calls++ == 0) throw StateError('render');
            return Uint8List(1);
          },
          preview: (_) => const Text('Готовый PDF'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось сформировать'), findsOneWidget);
    await tester.tap(find.text('Повторить формирование'));
    await tester.pumpAndSettle();
    expect(find.text('Готовый PDF'), findsOneWidget);
  });
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'PDF preview ${size.width}x${size.height} at text200 keeps actions scrollable',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final changes = ValueNotifier(true);
        addTearDown(changes.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ReportView(
              report: PlannerReport('Длинное название погружения', [], []),
              changes: changes,
              isCurrent: () => true,
              actions: Actions(),
              generate: (_) async => Uint8List(1),
              preview: (_) => const Text('Страница PDF'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final share = find.text('Поделиться');
        await tester.ensureVisible(share);
        await tester.tap(share);
        await tester.pumpAndSettle();
        expect(find.text('Страница PDF'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
