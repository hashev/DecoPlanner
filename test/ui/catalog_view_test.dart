import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/data/repositories/document_repository.dart';
import 'package:deco_planner/ui/features/documents/catalog_view.dart';
import 'package:deco_planner/ui/features/documents/document_session.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:deco_planner/ui/features/plan/switches_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'catalog gas/tank create and confirmed delete do not alter copied plan',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('catalog-widget-');
      final model = PlannerViewModel();
      model.replaceSwitches([
        GasSwitch(depthMetres: 21, breathing: BreathingGas.oc(Gas(oxygen: .5))),
      ]);
      final session = DocumentSession(
        model: model,
        repository: DocumentRepository(root),
        autosaveDelay: const Duration(days: 1),
      );
      addTearDown(() {
        model.dispose();
        root.deleteSync(recursive: true);
      });
      try {
        final revision = model.planRequest.revision;
        await tester.pumpWidget(
          MaterialApp(home: CatalogView(session: session)),
        );
        await tester.tap(find.text('Добавить набор газов'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Применить переключения'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'Деко 50',
        );
        await tester.tap(find.text('Сохранить в справочник'));
        await tester.pumpAndSettle();
        expect(
          session.document.gasSets.single.switches.single.breathing.gas.oxygen,
          .5,
        );
        expect(model.planRequest.revision, revision);
        await tester.tap(find.text('Добавить баллон'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextFormField, 'Число баллонов'),
          findsNothing,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Водяной объём одного баллона, L'),
          '11.1',
        );
        await tester.tap(find.text('Применить'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'AL80',
        );
        await tester.tap(find.text('Сохранить в справочник'));
        await tester.pumpAndSettle();
        expect(session.document.tanks.single.waterLitres, 11.1);
        await tester.tap(find.text('Удалить набор'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();
        expect(session.document.gasSets, hasLength(1));
        await tester.tap(find.text('Удалить набор'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        expect(session.document.gasSets, isEmpty);
        expect(model.selected.switches.single.breathing.gas.oxygen, .5);
        expect(model.planRequest.revision, revision);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }
    },
  );
  testWidgets(
    'loading a gas set creates a draft copy and still requires apply',
    (tester) async {
      final preset = GasSetPreset(
        id: 'set',
        name: 'Деко 50',
        switches: [
          GasSwitch(
            depthMetres: 21,
            breathing: BreathingGas.oc(Gas(oxygen: .5)),
            lost: true,
          ),
        ],
      );
      List<GasSwitch>? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  value = await editGasSwitches(
                    context,
                    initial: [],
                    units: DisplayUnits.metric,
                    ccr: false,
                    presets: [preset],
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Загрузить копию набора',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Деко 50').last);
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.text('Газ потерян'), findsOneWidget);
      await tester.tap(find.text('Применить переключения'));
      await tester.pumpAndSettle();
      expect(value!.single.toJson(), preset.switches.single.toJson());
      expect(preset.switches.length, 1);
    },
  );
}
