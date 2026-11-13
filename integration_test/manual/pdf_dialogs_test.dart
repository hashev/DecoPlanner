import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/pdf_actions.dart';
import 'package:deco_planner/data/services/planner_pdf.dart';
import 'package:deco_planner/domain/planner_report.dart';
import 'package:deco_planner/ui/features/export/report_view.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in interactive validation: an operator cancels the OS Save and Print
/// dialogs. Run this file explicitly with --run-skipped and a desktop session.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // AX attachment creates an engine-owned semantics handle. Establish it before
  // testWidgets records its leak-check baseline, rather than during the test.
  setUpAll(() async {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Text('Подключите accessibility client для проверки PDF'),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!binding.platformDispatcher.semanticsEnabled) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'Attach native accessibility client before running dialog checks.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  testWidgets(
    'native PDF Save, cancellations and Share dismissal preserve preview and plan',
    (tester) async {
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      final request = model.selected,
          result = calculateBuhlmann(model.selected);
      final report = PlannerReport.dive(
        result: result,
        request: request,
        units: DisplayUnits.metric,
      );
      final bytes = await tester.runAsync(
        () => const PlannerPdf().build(report),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReportView(
            report: report,
            changes: model,
            isCurrent: () => true,
            generate: (_) async => bytes!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      const actions = NativePdfActions();
      await tester.runAsync(() async {
        final savedName =
            'planner-native-${DateTime.now().microsecondsSinceEpoch}.pdf';
        final expected = await Directory.systemTemp.createTemp(
          'planner-pdf-expected-',
        );
        await File('${expected.path}/$savedName').writeAsBytes(bytes!);
        debugPrint('PDF_EXPECTED=${expected.path}/$savedName');
        debugPrint('PDF_DIALOG_PHASE=save-success');
        final completed = await actions.save(
          bytes,
          savedName,
          const Rect.fromLTWH(20, 20, 100, 100),
        );
        expect(completed, PdfActionResult.completed);
        debugPrint('PDF_DIALOG_PHASE=save-cancel');
        final saved = await actions.save(
          bytes,
          'planner-dialog-test.pdf',
          const Rect.fromLTWH(20, 20, 100, 100),
        );
        expect(saved, PdfActionResult.cancelled);
        debugPrint('PDF_DIALOG_PHASE=print-cancel');
        final printed = await actions.print(bytes);
        expect(printed, PdfActionResult.cancelled);
        debugPrint('PDF_DIALOG_PHASE=share-dismiss');
        final shared = await actions.share(
          bytes,
          'planner-dialog-test.pdf',
          const Rect.fromLTWH(20, 20, 100, 100),
        );
        expect(shared, PdfActionResult.handedOff);
        // The macOS API acknowledges handoff immediately. Allow an operator to
        // inspect and dismiss the picker; this does not assert final delivery.
        await Future<void>.delayed(const Duration(seconds: 20));
        debugPrint('PDF_DIALOG_PHASE=complete');
      });
      await tester.pumpAndSettle();
      expect(find.text('Печатный вид'), findsOneWidget);
      expect(model.planRequest.revision, 0);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Сохранить PDF'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
    skip: true, // Interactive OS dialogs; enable explicitly with --run-skipped.
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
