import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/app/planner_app.dart';
import 'package:deco_planner/ui/features/plan/bailout_editor.dart';
import 'package:deco_planner/ui/features/plan/planner_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void ccr(PlannerViewModel model) => model.replaceLevels([
  Level(
    depthMetres: 45,
    durationMin: 25,
    breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
  ),
]);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'CCR source → edited OC gases → real bailout result → source edit marks branch stale',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = PlannerViewModel();
      addTearDown(model.dispose);
      ccr(model);
      await tester.pumpWidget(PlannerApp(viewModel: model));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('create-bailout')));
      await tester.enterText(find.byKey(const Key('bailout-time')), '12.5');
      for (final input in [(21, 50), (6, 100)]) {
        await tapVisible(tester, find.byKey(const Key('bailout-add-gas')));
        final i = input.$1 == 21 ? 0 : 1;
        await tester.enterText(
          find.byKey(Key('bailout-switch-$i-depth')),
          '${input.$1}',
        );
        await tester.enterText(
          find.byKey(Key('bailout-switch-$i-o2')),
          '${input.$2}',
        );
      }
      await tester.tap(find.byKey(const Key('bailout-save')));
      await tester.pumpAndSettle();
      expect(model.selectedBailout!.runtimeMin, 12.5);
      expect(model.selectedBailout!.switches.length, 2);
      final calculate = find.byKey(const Key('calculate'));
      await tester.scrollUntilVisible(
        calculate,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(calculate);
      await tester.runAsync(() async {
        await tester.tap(calculate);
        final clock = Stopwatch()..start();
        while (model.calculating) {
          if (clock.elapsed > const Duration(seconds: 5)) {
            throw StateError('Bailout worker timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(model.displaySnapshot.status, PlanStatus.ready);
      expect(find.text('Bailout · результат'), findsOneWidget);
      final reference =
          jsonDecode(
                File(
                  'packages/deco_core/test/fixtures/independent/buhlmann-bailout-normalized.json',
                ).readAsStringSync(),
              )
              as Map;
      final expected = (reference['cases'] as List).cast<Map>().firstWhere(
        (r) =>
            r['model'] == 'B' &&
            r['mode'] == 'bailout' &&
            r['runtime_point_min'] == 12.5,
      );
      expect(
        model.displaySnapshot.result!.runtimeMin,
        closeTo((expected['expected'] as Map)['runtime_min'] as num, 1e-10),
      );
      final original = jsonEncode(model.snapshot.result!.toJson());
      model.selectBailout(null);
      await tester.pumpAndSettle();
      expect(jsonEncode(model.displaySnapshot.result!.toJson()), original);
      final id = model.selectedDiveBailouts.single.id;
      model.selectBailout(id);
      ccr(model);
      await tester.pumpAndSettle();
      expect(model.displaySnapshot.status, PlanStatus.stale);
      expect(find.text('Входы изменены — пересчитайте'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(375, 812),
    const Size(740, 375),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'bailout form validation and dirty Back retain draft at $size with text200%',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final model = PlannerViewModel();
        addTearDown(model.dispose);
        ccr(model);
        await tester.pumpWidget(PlannerApp(viewModel: model));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('create-bailout')));
        await tester.enterText(find.byKey(const Key('bailout-time')), '0');
        await tester.tap(find.byKey(const Key('bailout-save')));
        await tester.pumpAndSettle();
        expect(
          find.text('Время перехода должно быть больше нуля'),
          findsOneWidget,
        );
        expect(model.selectedDiveBailouts, isEmpty);
        await tester.enterText(find.byKey(const Key('bailout-time')), '12.5');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Сохранить изменения bailout?'), findsOneWidget);
        await tester.tap(find.text('Продолжить редактирование'));
        await tester.pumpAndSettle();
        expect(
          (tester.widget<TextFormField>(
            find.byKey(const Key('bailout-time')),
          )).controller!.text,
          '12.5',
        );
        await tester.tap(find.byKey(const Key('bailout-save')));
        await tester.pumpAndSettle();
        expect(model.selectedBailout!.runtimeMin, 12.5);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unchanged imperial bailout form preserves canonical gas and switch values',
    (tester) async {
      final source = DiveRequest(
        id: 'source',
        levels: [
          Level(
            depthMetres: 45,
            durationMin: 25,
            breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), 1.3),
          ),
        ],
        settings: CalculationSettings(
          model: DecompressionModel.buhlmannB,
          pressure: PressureContext(
            surfaceBar: 1.01325,
            waterVapourBar: .0627,
            barPerMetre: .1,
          ),
          stopGrid: StopGrid.metric(),
          gradientFactors: GradientFactors(low: .3, high: .85),
        ),
      );
      final gas = Gas(oxygen: .1876543210987654, helium: .4234567890123456);
      final initial = BailoutRequest(
        id: 'escape',
        sourceDiveId: source.id,
        runtimeMin: 12.3456789012345,
        initialOcGas: gas,
        switches: [
          GasSwitch(
            depthMetres: 21.1234567890123,
            breathing: BreathingGas.oc(gas),
            lost: true,
            minimumStopMin: 1.234567890123,
          ),
        ],
      );
      BailoutDraft? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await editBailout(
                    context,
                    source: source,
                    units: DisplayUnits.imperial,
                    initial: initial,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bailout-save')));
      await tester.pumpAndSettle();
      expect(saved!.runtimeMin, initial.runtimeMin);
      expect(saved!.initialOcGas.toJson(), gas.toJson());
      expect(saved!.switches.single.toJson(), initial.switches.single.toJson());
    },
  );
}
