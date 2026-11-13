import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/settings_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CalculationSettings get initial => CalculationSettings(
  model: DecompressionModel.buhlmannB,
  pressure: PressureContext(
    surfaceBar: 1.01325,
    waterVapourBar: .0627,
    barPerMetre: .1,
  ),
  stopGrid: StopGrid.metric(),
  gradientFactors: GradientFactors(low: .3, high: .85),
);
void main() {
  Future<void> open(
    WidgetTester tester,
    DisplayUnits units,
    void Function(SettingsEdit?) result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await editCalculationSettings(
                  context,
                  initial: initial,
                  units: units,
                  allowDefaults: true,
                ),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets('unchanged imperial settings preserve exact physical values', (
    tester,
  ) async {
    SettingsEdit? value;
    await open(tester, DisplayUnits.imperial, (v) => value = v);
    await tester.tap(find.text('Применить к погружению'));
    await tester.pumpAndSettle();
    expect(value!.settings.toJson(), initial.toJson());
    expect(value!.action, SettingsAction.apply);
  });
  testWidgets('GF validation, explicit defaults action and cancelled draft', (
    tester,
  ) async {
    SettingsEdit? value;
    await open(tester, DisplayUnits.metric, (v) => value = v);
    await tester.enterText(find.byKey(const Key('settings-gfLow')), '90');
    await tester.tap(find.text('Применить к погружению'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Проверьте: 0 < GF Low'), findsOneWidget);
    expect(value, isNull);
    await tester.enterText(find.byKey(const Key('settings-gfLow')), '40');
    await tester.tap(find.text('Сохранить по умолчанию'));
    await tester.pumpAndSettle();
    expect(value!.action, SettingsAction.saveDefaults);
    expect(value!.settings.gradientFactors.low, .4);
    value = null;
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-gfLow')), '50');
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(value, isNull);
  });
  testWidgets(
    'VPM switches applicable fields and retains canonical numeric parameters',
    (tester) async {
      SettingsEdit? value;
      await open(tester, DisplayUnits.metric, (v) => value = v);
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<DecompressionModel>,
          'Модель',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('VPM-B').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-gfLow')), findsNothing);
      expect(find.text('GF не применяется к VPM-B.'), findsOneWidget);
      await tester.tap(find.text('Применить к погружению'));
      await tester.pumpAndSettle();
      expect(value!.settings.model, DecompressionModel.vpmB);
      expect(value!.settings.pressure.waterVapourBar, .0493);
      expect(value!.settings.vpm.toJson(), initial.vpm.toJson());
    },
  );
  testWidgets(
    'altitude travel rejects invalid destination and preserves disabled values',
    (tester) async {
      SettingsEdit? value;
      await open(tester, DisplayUnits.metric, (v) => value = v);
      final scroll = find.byType(Scrollable).last;
      final altitude = find.text('Планирование на высоте');
      await tester.scrollUntilVisible(altitude, 250, scrollable: scroll);
      await tester.tap(altitude);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings-diveAltitudeMetres')),
        '2000',
      );
      await tester.tap(find.text('Акклиматизирован'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings-initialAltitudeMetres')),
        '2500',
      );
      await tester.tap(find.text('Применить к погружению'));
      await tester.pumpAndSettle();
      expect(value, isNull);
      await tester.enterText(
        find.byKey(const Key('settings-initialAltitudeMetres')),
        '1000',
      );
      await tester.tap(find.text('Применить к погружению'));
      await tester.pumpAndSettle();
      expect(value!.settings.altitude.enabled, isTrue);
      expect(value!.settings.altitude.acclimatized, isFalse);
      expect(value!.settings.altitude.diveAltitudeMetres, 2000);
      expect(value!.settings.altitude.initialAltitudeMetres, 1000);
      final result = calculateBuhlmann(
        DiveRequest(
          id: 'altitude-editor',
          settings: value!.settings,
          levels: [
            Level(
              depthMetres: 30,
              durationMin: 20,
              breathing: BreathingGas.oc(Gas(oxygen: .21)),
            ),
          ],
        ),
      );
      expect(result.pressure.surfaceBar, lessThan(1.01325));
    },
  );
  for (final size in [
    const Size(375, 667),
    const Size(667, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('settings form $size text200 scrolls without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, DisplayUnits.metric, (_) {});
      expect(tester.takeException(), isNull);
      final scroll = find.byType(SingleChildScrollView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(scroll, const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
    });
  }
}
