import 'dart:convert';
import 'dart:io';

import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

DiveRequest source({
  DecompressionModel model = DecompressionModel.buhlmannB,
  bool changed = false,
  BreathingMode mode = BreathingMode.ccr,
  List<GasSwitch> switches = const [],
}) {
  final diluent = Gas(oxygen: .21, helium: .35);
  return DiveRequest(
    id: 'ccr-source',
    switches: switches,
    settings: CalculationSettings(
      model: model,
      pressure: PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: .0627,
        barPerMetre: .1,
      ),
      stopGrid: StopGrid.metric(),
      gradientFactors: GradientFactors(low: .3, high: .85),
    ),
    levels: [
      Level(
        depthMetres: 45,
        durationMin: 25,
        breathing: mode == BreathingMode.ccr
            ? BreathingGas.ccr(diluent, 1.3)
            : BreathingGas.oc(diluent),
      ),
      if (changed)
        Level(
          depthMetres: 45,
          durationMin: 10,
          breathing: BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.4),
        ),
    ],
  );
}

BailoutRequest branch(
  double point, {
  String id = 'escape',
  String sourceId = 'ccr-source',
  List<GasSwitch> switches = const [],
}) => BailoutRequest(
  id: id,
  sourceDiveId: sourceId,
  runtimeMin: point,
  initialOcGas: Gas(oxygen: .21, helium: .35),
  switches: switches,
);

void tissues(
  TissueState actual,
  Map<String, dynamic> expected, {
  String nitrogenKey = 'n2',
  String heliumKey = 'he',
}) {
  for (var i = 0; i < 16; i++) {
    expect(
      actual.nitrogenBar[i],
      closeTo((expected[nitrogenKey] as List)[i] as num, 1e-10),
    );
    expect(
      actual.heliumBar[i],
      closeTo((expected[heliumKey] as List)[i] as num, 1e-10),
    );
  }
}

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/buhlmann-bailout-normalized.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(
      'independent ${row['model']} ${row['mode']} at ${row['runtime_point_min']} changed=${row['changed_diluent']} switches=${(row['switches'] as List).length}',
      () {
        final ccr = row['mode'] == 'ccr';
        final switches = [
          for (final s in row['switches'] as List)
            GasSwitch(
              depthMetres: (s[0] as num).toDouble(),
              breathing: ccr
                  ? BreathingGas.ccr(
                      Gas(
                        oxygen: (s[1] as num).toDouble(),
                        helium: (s[2] as num).toDouble(),
                      ),
                      (s[3] as num).toDouble(),
                    )
                  : BreathingGas.oc(
                      Gas(
                        oxygen: (s[1] as num).toDouble(),
                        helium: (s[2] as num).toDouble(),
                      ),
                    ),
            ),
        ];
        final request = source(
          model: row['model'] == 'B'
              ? DecompressionModel.buhlmannB
              : DecompressionModel.buhlmannC,
          changed: row['changed_diluent'] as bool,
          switches: ccr ? switches : const [],
        );
        final original = calculateBuhlmann(request);
        final before = jsonEncode(original.toJson());
        final point = row['runtime_point_min'] as double;
        final result = ccr
            ? original
            : calculateBuhlmannBailout(
                request,
                branch(point, switches: switches),
              );
        expect(result.diveId, ccr ? 'ccr-source' : 'escape');
        expect(jsonEncode(original.toJson()), before);
        expect(jsonEncode(calculateBuhlmann(request).toJson()), before);
        final prefix = result.segments.where((s) => s.endMin <= point).toList();
        final expectedPrefix = (row['prefix'] as List)
            .cast<Map<String, dynamic>>();
        expect(prefix.length, expectedPrefix.length);
        for (var i = 0; i < prefix.length; i++) {
          expect(prefix[i].physical.breathing.mode, BreathingMode.ccr);
          expect(
            prefix[i].physical.endDepthMetres,
            expectedPrefix[i]['end_depth_m'],
          );
          tissues(prefix[i].endState.tissues, expectedPrefix[i]);
          expect(
            prefix[i].endState.oxygen.cnsFraction,
            closeTo(expectedPrefix[i]['cns_fraction'] as num, 1e-10),
          );
          expect(
            prefix[i].endState.oxygen.otu,
            closeTo(expectedPrefix[i]['otu'] as num, 1e-9),
          );
        }
        final expected = row['expected'] as Map<String, dynamic>;
        expect(result.firstStopMetres, expected['first_stop_m']);
        expect(
          result.runtimeMin,
          closeTo(expected['runtime_min'] as num, 1e-10),
        );
        final suffix = result.segments
            .where((s) => s.startMin >= point)
            .toList();
        final expectedSuffix = (expected['segments'] as List)
            .cast<Map<String, dynamic>>();
        expect(suffix.length, expectedSuffix.length);
        for (var i = 0; i < suffix.length; i++) {
          final actual = suffix[i], e = expectedSuffix[i];
          expect(
            actual.physical.breathing.mode,
            ccr ? BreathingMode.ccr : BreathingMode.oc,
          );
          expect(actual.physical.breathing.setpointBar, e['setpoint_bar']);
          expect(actual.physical.breathing.gas.oxygen, e['o2']);
          expect(actual.physical.breathing.gas.helium, e['he']);
          expect(actual.phase.name, e['phase']);
          expect(actual.startMin, closeTo(e['start_min'] as num, 1e-10));
          expect(
            actual.physical.durationMin,
            closeTo(e['duration_min'] as num, 1e-10),
          );
          expect(actual.physical.startDepthMetres, e['start_depth_m']);
          expect(actual.physical.endDepthMetres, e['end_depth_m']);
          tissues(
            actual.endState.tissues,
            e,
            nitrogenKey: 'n2_bar',
            heliumKey: 'he_bar',
          );
          expect(
            actual.endState.oxygen.cnsFraction,
            closeTo(e['cns_fraction'] as num, 1e-10),
          );
          expect(actual.endState.oxygen.otu, closeTo(e['otu'] as num, 1e-9));
        }
        expect(
          CalculationResult.fromJson(result.toJson()).toJson(),
          result.toJson(),
        );
        expect(
          result.finalState.oxygen.otu,
          greaterThan(prefix.last.endState.oxygen.otu),
        );
      },
    );
  }

  test(
    'failure inside a CCR ascent or stop preserves continuous prefix and oxygen',
    () {
      final request = source();
      final original = calculateBuhlmann(request);
      for (final phase in [SegmentPhase.ascent, SegmentPhase.decompression]) {
        final segment = original.segments.firstWhere((s) => s.phase == phase);
        final point = segment.startMin + segment.physical.durationMin / 2;
        final result = calculateBuhlmannBailout(request, branch(point));
        final prefix = result.segments.lastWhere((s) => s.endMin <= point);
        final preceding = original.segments.where(
          (s) => s.endMin <= segment.startMin,
        );
        final initial = preceding.isEmpty
            ? original.initialState
            : preceding.last.endState;
        final expectedPhysical = PropagationSegment(
          startDepthMetres: segment.physical.startDepthMetres,
          endDepthMetres:
              (segment.physical.startDepthMetres +
                  segment.physical.endDepthMetres) /
              2,
          durationMin: segment.physical.durationMin / 2,
          breathing: segment.physical.breathing,
        );
        final expected = expectedPhysical.propagate(
          initial.tissues,
          BuhlmannCoefficients.b().kinetics,
          original.pressure,
        );
        expect(prefix.endMin, point);
        expect(prefix.endState.tissues.nitrogenBar, expected.nitrogenBar);
        expect(prefix.endState.tissues.heliumBar, expected.heliumBar);
        expect(
          prefix.endState.oxygen.toJson(),
          OxygenPolicy.exposeSegment(
            initial.oxygen,
            expectedPhysical,
            original.pressure,
          ).toJson(),
        );
        expect(
          result.segments
              .firstWhere((s) => s.startMin == point)
              .physical
              .breathing
              .mode,
          BreathingMode.oc,
        );
        expect(result.segments.last.physical.endDepthMetres, 0);
        expect(result.decompressionMin, lessThanOrEqualTo(result.ascentMin));
      }
    },
  );

  test(
    'unknown CNS before failure is carried, future unknown CNS is excluded',
    () {
      final base = source();
      DiveRequest withSetpoints(double first, double second) => DiveRequest(
        id: base.id,
        settings: base.settings,
        levels: [
          Level(
            depthMetres: 45,
            durationMin: 25,
            breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), first),
          ),
          Level(
            depthMetres: 45,
            durationMin: 10,
            breathing: BreathingGas.ccr(Gas(oxygen: .21, helium: .35), second),
          ),
        ],
      );
      final future = withSetpoints(1.3, 1.8);
      expect(calculateBuhlmann(future).finalState.oxygen.cnsFraction, isNull);
      expect(
        calculateBuhlmannBailout(
          future,
          branch(12.5),
        ).finalState.oxygen.cnsFraction,
        isNotNull,
      );
      final past = calculateBuhlmannBailout(
        withSetpoints(1.8, 1.3),
        branch(12.5),
      );
      expect(past.finalState.oxygen.cnsFraction, isNull);
      expect(
        past.finalState.oxygen.cnsUnavailableReason?.code,
        CalculationFailureCode.outsideModelDomain,
      );
      expect(past.finalState.oxygen.otu, greaterThan(0));
    },
  );

  test(
    'exact boundary uses next segment breathing, not the previous CCR segment',
    () {
      final base = source();
      final mixed = DiveRequest(
        id: base.id,
        settings: base.settings,
        levels: [
          base.levels.single,
          Level(
            depthMetres: 45,
            durationMin: 5,
            breathing: BreathingGas.oc(Gas(oxygen: .21, helium: .35)),
          ),
        ],
      );
      expect(
        () => calculateBuhlmannBailout(mixed, branch(25)),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        calculateBuhlmannBailout(
          mixed,
          branch(24.999),
        ).segments.last.physical.endDepthMetres,
        0,
      );
    },
  );

  test(
    'rejects mismatched source, reused identity, OC source, surface and outside runtime',
    () {
      for (final b in [
        branch(10, sourceId: 'missing'),
        branch(10, id: 'ccr-source'),
        branch(0),
        branch(10000),
      ]) {
        expect(
          () => calculateBuhlmannBailout(source(), b),
          throwsA(isA<CalculationFailure>()),
        );
      }
      expect(
        () => calculateBuhlmannBailout(
          source(mode: BreathingMode.oc),
          branch(10),
        ),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => calculateBuhlmannBailout(
          source(model: DecompressionModel.vpmB),
          branch(10),
        ),
        throwsA(isA<CalculationFailure>()),
      );
    },
  );

  test(
    'shares cancellation and evaluation budget between source and escape',
    () {
      expect(
        () => calculateBuhlmannBailout(
          source(),
          branch(10),
          budget: CalculationBudget(isCancelled: () => true),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (e) => e.code,
            'code',
            CalculationFailureCode.cancelled,
          ),
        ),
      );
      expect(
        () => calculateBuhlmannBailout(
          source(),
          branch(10),
          budget: CalculationBudget(maxIterations: 1),
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (e) => e.code,
            'code',
            CalculationFailureCode.budgetExceeded,
          ),
        ),
      );
    },
  );
}
