import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:deco_planner/ui/features/plan/gas_usage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CalculationSettings get settings => CalculationSettings(
  model: DecompressionModel.buhlmannB,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
);
GasUsageReport report({bool ccr = false}) => calculateGasUsage(
  calculateBuhlmann(
    DiveRequest(
      id: 'usage',
      settings: settings,
      levels: [
        Level(
          depthMetres: 30,
          durationMin: 20,
          breathing: ccr
              ? BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3)
              : BreathingGas.oc(Gas(oxygen: .21)),
        ),
      ],
    ),
  ),
  settings,
);
void main() {
  testWidgets(
    'imperial catalog capacity has exact unchanged round-trip and converts nominal CuFt',
    (tester) async {
      TankRequirement? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await editTankParameters(
                    context,
                    waterLitres: 11.1,
                    workingBar: 207,
                    editableCount: false,
                    nominalCapacity: true,
                    units: DisplayUnits.imperial,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final capacity = find.widgetWithText(
        TextFormField,
        'Номинальная ёмкость, CuFt',
      );
      expect(capacity, findsOneWidget);
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(answer!.waterLitres, 11.1);
      expect(answer!.workingBar, 207);
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.enterText(capacity, '80');
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(
        answer!.waterLitres,
        closeTo(
          CylinderCapacity.fromImperial(
            nominalCubicFeet: 80,
            workingPsi: Units.barToPsi(207),
          ).waterLitres,
          1e-12,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real OC volume, tank apply/cancel, invalid form and canonical draft',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final usage = report(), drafts = <String, String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: GasUsageView(
            report: usage,
            units: DisplayUnits.metric,
            drafts: drafts,
            onDraft: (k, v) => drafts[k] = v,
          ),
        ),
      );
      expect(
        find.text(
          'Расход ${usageVolume(usage.gases.single.litres, DisplayUnits.metric)}',
        ),
        findsOneWidget,
      );
      final selector = find.text('Выбрать баллон · OC 21.0/0.0');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Число баллонов'),
        '0',
      );
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите положительное целое число'), findsOneWidget);
      expect(drafts, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Число баллонов'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Водяной объём одного баллона, L'),
        '10',
      );
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(jsonDecode(drafts.values.single), {
        'litres': 10.0,
        'count': 1,
        'bar': 232.0,
      });
      expect(
        find.text(
          'Давление расхода ${usagePressure(usage.gases.single.litres / 10, DisplayUnits.metric)}',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Водяной объём одного баллона, L'),
        '15',
      );
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(jsonDecode(drafts.values.single)['litres'], 10);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('imperial catalog tank selection keeps canonical litres and bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drafts = <String, String>{};
    final usage = report();
    await tester.pumpWidget(
      MaterialApp(
        home: GasUsageView(
          report: usage,
          units: DisplayUnits.imperial,
          drafts: drafts,
          onDraft: (k, v) => drafts[k] = v,
          tanks: [
            TankPreset(
              id: 'al80',
              name: 'AL80',
              waterLitres: 11.1,
              workingBar: 207,
            ),
          ],
        ),
      ),
    );
    final selector = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Копия баллона из справочника',
    );
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AL80').last);
    await tester.pumpAndSettle();
    expect(jsonDecode(drafts.values.single), {
      'litres': 11.1,
      'count': 2,
      'bar': 207.0,
    });
    expect(
      find.text(
        'Давление расхода ${usagePressure(usage.gases.single.litres / 22.2, DisplayUnits.imperial)}',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'CCR core report $size text200 has explicit limits and no overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final usage = report(ccr: true);
        await tester.pumpWidget(
          MaterialApp(
            home: GasUsageView(
              report: usage,
              units: DisplayUnits.imperial,
              drafts: const {},
              onDraft: (_, _) {},
            ),
          ),
        );
        expect(find.textContaining('Дилюент, промывки'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Кислород CCR'),
          200,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Кислород CCR'), findsOneWidget);
        expect(
          find.text(
            'Расход ${usageVolume(usage.gases.single.litres, DisplayUnits.imperial)}',
          ),
          findsOneWidget,
        );
        for (var i = 0; i < 12; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
