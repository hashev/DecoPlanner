import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/ui/features/plan/switches_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required bool ccr,
    required void Function(List<GasSwitch>?) result,
    List<GasSwitch> initial = const [],
    DisplayUnits units = DisplayUnits.metric,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await editGasSwitches(
                  context,
                  initial: initial,
                  units: units,
                  ccr: ccr,
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

  testWidgets(
    'clear switches remains a draft until apply and cancel preserves original list',
    (tester) async {
      final initial = [
        GasSwitch(depthMetres: 21, breathing: BreathingGas.oc(Gas(oxygen: .5))),
      ];
      List<GasSwitch>? result;
      await open(
        tester,
        ccr: false,
        initial: initial,
        result: (value) => result = value,
      );
      await tester.tap(find.text('Очистить переключения'));
      await tester.pumpAndSettle();
      expect(initial.length, 1);
      expect(find.text('Удалить переключение 1'), findsNothing);
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Очистить переключения'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Применить переключения'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
      expect(initial.length, 1);
    },
  );
  testWidgets(
    'OC add validates composition, preserves lost/minimum and only applies on confirmation',
    (tester) async {
      List<GasSwitch>? value;
      await open(tester, ccr: false, result: (v) => value = v);
      await tester.tap(find.text('Добавить переключение'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Кислород O₂, %'),
        '120',
      );
      await tester.tap(find.text('Сохранить газ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Сумма O₂ и He'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Кислород O₂, %'),
        '50',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Глубина переключения, м'),
        '21',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Минимальная остановка, мин (необязательно)',
        ),
        '2',
      );
      await tester.tap(find.text('Газ потерян'));
      await tester.tap(find.text('Сохранить газ'));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.text('Газ потерян'), findsOneWidget);
      await tester.tap(find.text('Применить переключения'));
      await tester.pumpAndSettle();
      expect(value!.single.depthMetres, 21);
      expect(value!.single.breathing.gas.oxygen, .5);
      expect(value!.single.lost, isTrue);
      expect(value!.single.minimumStopMin, 2);
    },
  );
  testWidgets(
    'unchanged imperial CCR switch retains physical values and cancelled list discards edits',
    (tester) async {
      final original = GasSwitch(
        depthMetres: 21,
        breathing: BreathingGas.ccr(
          Gas(oxygen: .18, helium: .45),
          Units.ataToBar(1.4),
        ),
        minimumStopMin: 1,
      );
      List<GasSwitch>? value;
      await open(
        tester,
        ccr: true,
        initial: [original],
        units: DisplayUnits.imperial,
        result: (v) => value = v,
      );
      await tester.tap(find.text('Изменить переключение 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить газ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Применить переключения'));
      await tester.pumpAndSettle();
      expect(value!.single.toJson(), original.toJson());
      value = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить переключение 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(value, isNull);
    },
  );
  testWidgets('switching invalid CCR setpoint to OC ignores hidden field', (
    tester,
  ) async {
    List<GasSwitch>? value;
    await open(tester, ccr: true, result: (v) => value = v);
    await tester.tap(find.text('Добавить переключение'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Setpoint, ATA'),
      'bad',
    );
    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<BreathingMode>,
        'Режим переключения',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OC').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить газ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить переключения'));
    await tester.pumpAndSettle();
    expect(value!.single.breathing.mode, BreathingMode.oc);
    expect(value!.single.breathing.setpointBar, isNull);
    expect(tester.takeException(), isNull);
  });
}
