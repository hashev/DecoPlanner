import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:deco_planner/data/services/document_files.dart';
import 'package:deco_planner/ui/features/documents/document_library.dart';
import 'package:deco_planner/ui/features/documents/document_session.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/document_fixtures.dart';

class TestFiles implements DocumentFiles {
  Uint8List? incoming, exported;
  DocumentExport outcome = DocumentExport.cancelled;
  @override
  Future<Uint8List?> pickJson() async => incoming;
  @override
  Future<DocumentExport> exportJson(
    Uint8List bytes,
    String name,
    Rect origin,
  ) async {
    exported = bytes;
    expect(origin.isEmpty, isFalse);
    return outcome;
  }
}

void main() {
  late Directory root;
  late PlannerViewModel model;
  late DocumentSession session;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('deco-library-');
    model = PlannerViewModel();
    session = DocumentSession(
      model: model,
      repository: DocumentRepository(root),
      autosaveDelay: const Duration(days: 1),
    );
  });
  tearDown(() async {
    session.dispose();
    model.dispose();
    await root.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (!session.busy &&
          !tester.binding.hasScheduledFrame &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Future<void> act(WidgetTester tester, String text) async {
    // Refresh can leave a visible action disabled while disk work completes.
    // Wait for its enabled state so the tap cannot be silently discarded.
    var ready = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      final buttons = find.ancestor(
        of: find.text(text).last,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      if (buttons.evaluate().isNotEmpty &&
          tester.widget<ButtonStyleButton>(buttons.first).onPressed != null) {
        ready = true;
        break;
      }
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(ready, isTrue, reason: 'Action "$text" did not become enabled');
    await tester.ensureVisible(find.text(text).last);
    await tester.runAsync(() async {
      await tester.tap(find.text(text).last);
      // Disk work and FakeAsync callbacks advance together in settle().
    });
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
  }

  testWidgets('actions wait for refresh to enable the button', (tester) async {
    var enabled = false;
    var taps = 0;
    late StateSetter refresh;
    late BuildContext buttonContext;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            buttonContext = context;
            return TextButton(
              onPressed: enabled ? () => taps++ : null,
              child: const Text('Действие'),
            );
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (buttonContext.mounted) refresh(() => enabled = true);
        }),
      );
    });
    await act(tester, 'Действие');
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library saves, renames with validation, opens and confirms deletion',
    (tester) async {
      await tester.runAsync(
        () => tester.pumpWidget(
          PlannerApp(viewModel: model, documentSession: session),
        ),
      );
      await tester.runAsync(() => tester.tap(find.byTooltip('Документы')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      await act(tester, 'Сохранить план');
      expect(find.text('План сохранён'), findsOneWidget);
      await act(tester, 'Переименовать');
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(find.text('Введите название'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Мой план');
      await act(tester, 'Сохранить');
      expect(session.document.name, 'Мой план');
      await act(tester, 'Удалить');
      expect(find.text('Удалить план?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await settle(tester);
      expect((await tester.runAsync(session.list))!.length, 1);
      await act(tester, 'Открыть');
      expect(find.text('Планировщик'), findsOneWidget);
      expect(find.text('Мой план'), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.byTooltip('Документы')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      await act(tester, 'Удалить');
      await act(tester, 'Удалить');
      expect(find.text('План удалён'), findsOneWidget);
      expect((await tester.runAsync(session.list)), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled import/export and invalid JSON preserve current plan',
    (tester) async {
      final files = TestFiles();
      await tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            home: DocumentLibrary(session: session, files: files),
          ),
        ),
      );
      final id = session.document.id;
      final before = model.planRequest.toJson();
      await act(tester, 'Импорт JSON');
      expect(session.document.id, id);
      expect(model.planRequest.toJson(), before);
      files.incoming = Uint8List.fromList([0]);
      await act(tester, 'Импорт JSON');
      expect(find.text('Некорректный документ или имя плана.'), findsOneWidget);
      expect(model.planRequest.toJson(), before);
      await act(tester, 'Экспорт JSON');
      expect(decodePlannerDocument(files.exported!).plan.toJson(), before);
      expect(find.text('JSON сохранён'), findsNothing);
      files.incoming = encodePlannerDocument(documentFixture());
      await act(tester, 'Импорт JSON');
      expect(session.document.id, isNot(id));
      expect(model.snapshot.status, PlanStatus.stale);
      expect(find.textContaining('Документ импортирован.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('document library fits $size at text 200 percent', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => session.repository.save(documentFixture()));
      await tester.runAsync(
        () => tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DocumentLibrary(session: session, files: TestFiles()),
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      expect(find.text('Документы'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'suggested filenames cannot escape directories or use Windows device names',
    () {
      expect(documentFileName('../CON:план?'), '.._CON_план_.json');
      expect(documentFileName('CON'), '_CON.json');
      expect(documentFileName('nul.json'), '_nul.json');
      expect(documentFileName('  .. '), 'plan.json');
      expect(documentFileName('План.json'), 'План.json');
    },
  );
}
