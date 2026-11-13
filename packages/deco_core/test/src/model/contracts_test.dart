import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

Map<String, Object?> roundTrip(Map<String, Object?> input) =>
    (jsonDecode(jsonEncode(input)) as Map).cast<String, Object?>();
void main() {
  final pressure = PressureContext(
    surfaceBar: .8,
    waterVapourBar: .0493,
    barPerMetre: .1,
  );
  final tissues = TissueState(
    nitrogenBar: List.generate(16, (i) => .6 + i / 100),
    heliumBar: List.generate(16, (i) => i / 1000),
  );
  final parameters = VpmParameters(
    version: 'custom-reference-test',
    lambdaPascalMinutes: 21e6,
    nitrogenRadiusMetres: .6e-6,
    heliumRadiusMetres: .5e-6,
    criticalVolumeEnabled: false,
  );
  test(
    'all influencing VPM arrays and scalar/saved tissue states round trip exactly',
    () {
      final initial = VpmState.initial(
        parameters: parameters,
        conservatism: 4,
        tissues: tissues,
        pressure: pressure,
      );
      final json = roundTrip(initial.toJson());
      var ordinal = 0;
      // Distinct values exercise every declared serialized vector, so swapping
      // nitrogen/helium, phase-time or onset fields cannot pass by zero equality.
      for (final key in json.keys.toList()) {
        if (json[key] is List) {
          json[key] = List.generate(16, (i) => .001 * (++ordinal) + i * 1e-6);
        }
      }
      json['maximumFirstStopMetres'] = 24.0;
      json['decoZoneStartMin'] = 20.123456789;
      json['savedRuntimeMin'] = 21.23456789;
      json['savedSegmentCount'] = 7;
      json['criticalVolumeIterations'] = 3;
      json['decoPhaseVolumeMin'] = 14.987654321;
      final state = VpmState.fromJson(json);
      expect(state.toJson(), json);
      expect(VpmState.fromJson(roundTrip(state.toJson())).toJson(), json);
      expect(
        () => state.adjustedInitialRadiusNitrogenMetres[0] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => state.previousPhaseVolumeMin.clear(),
        throwsUnsupportedError,
      );
      final outer = CalculationState(
        tissues: tissues,
        oxygen: OxygenState(cnsFraction: .123456789, otu: 100.123456789),
        vpm: state,
      );
      expect(
        CalculationState.fromJson(roundTrip(outer.toJson())).toJson(),
        outer.toJson(),
      );
    },
  );
  test(
    'request preserves full initial state, settings, gas roles and source bailout identity',
    () {
      final state = CalculationState(
        tissues: tissues,
        oxygen: OxygenState(),
        vpm: VpmState.initial(
          parameters: parameters,
          conservatism: 2,
          tissues: tissues,
          pressure: pressure,
        ),
      );
      final settings = CalculationSettings(
        model: DecompressionModel.vpmB,
        vpm: parameters,
        altitude: AltitudeSettings(
          enabled: true,
          diveAltitudeMetres: 2000,
          acclimatized: false,
          initialAltitudeMetres: 100,
          travelMin: 180.5,
          waitMin: 120.5,
        ),
        pressure: pressure,
        stopGrid: StopGrid(stepMetres: 3, lastStopMetres: 6),
        gradientFactors: GradientFactors(low: .2, high: .8),
        vpmConservatism: 4,
        descentMetresPerMin: 12.34,
        ascentMetresPerMin: 8.76,
        minimumStopMin: .5,
        includeDescentInLevelTime: false,
        lowSetpointBar: .75,
        bottomRmvLitresPerMin: 0,
        decoRmvLitresPerMin: 17.89,
        bottomOxygenLitresPerMin: .9,
        decoOxygenLitresPerMin: .55,
      );
      final gas = Gas(oxygen: .18, helium: .45);
      final dive = DiveRequest(
        id: 'source',
        levels: [
          Level(
            depthMetres: 45,
            durationMin: 25,
            breathing: BreathingGas.ccr(gas, 1.3),
          ),
        ],
        switches: [
          GasSwitch(
            depthMetres: 6,
            breathing: BreathingGas.ccr(gas, .7),
            lost: true,
            minimumStopMin: 2,
          ),
        ],
        settings: settings,
        surfaceIntervalMin: 45,
        initialState: state,
      );
      final other = DiveRequest.fromJson({...dive.toJson(), 'id': 'other'});
      expect(
        () => PlanRequest(
          revision: 0,
          dives: [dive, other],
          bailouts: [
            BailoutRequest(
              id: other.id,
              sourceDiveId: dive.id,
              runtimeMin: 25,
              initialOcGas: gas,
            ),
          ],
        ),
        throwsA(isA<CalculationFailure>()),
      );
      final plan = PlanRequest(
        revision: 7,
        dives: [dive],
        bailouts: [
          BailoutRequest(
            id: 'branch',
            sourceDiveId: 'source',
            runtimeMin: 25,
            initialOcGas: gas,
          ),
        ],
      );
      expect(
        PlanRequest.fromJson(roundTrip(plan.toJson())).toJson(),
        plan.toJson(),
      );
      expect(() => plan.dives.clear(), throwsUnsupportedError);
      expect(() => dive.levels.clear(), throwsUnsupportedError);
      expect(() => dive.switches.clear(), throwsUnsupportedError);
    },
  );
  test('valid calculation result segments/stops/unknown CNS round trip', () {
    final settings = CalculationSettings(
      model: DecompressionModel.buhlmannB,
      pressure: PressureContext(
        surfaceBar: 1.01325,
        waterVapourBar: .0627,
        barPerMetre: .1,
      ),
      stopGrid: StopGrid.metric(),
      gradientFactors: GradientFactors(low: .3, high: .85),
    );
    final result = calculateBuhlmann(
      DiveRequest(
        id: 'result',
        settings: settings,
        levels: [
          Level(
            depthMetres: 30,
            durationMin: 20,
            breathing: BreathingGas.oc(Gas(oxygen: .21)),
          ),
        ],
      ),
    );
    final copy = CalculationResult.fromJson(roundTrip(result.toJson()));
    expect(copy.toJson(), result.toJson());
    expect(copy.stops.map((s) => s.depthMetres), [12, 9, 6, 3]);
    expect(copy.runtimeMin, result.runtimeMin);
    expect(() => copy.segments.clear(), throwsUnsupportedError);
    final failure = const CalculationFailure(
      CalculationFailureCode.outsideModelDomain,
      'CNS domain exceeded.',
    );
    final unknown = CalculationState(
      tissues: tissues,
      oxygen: OxygenState.unavailable(reason: failure, otu: 10),
    );
    expect(
      CalculationState.fromJson(roundTrip(unknown.toJson())).toJson(),
      unknown.toJson(),
    );
    expect(
      CalculationFailure.fromJson(roundTrip(failure.toJson())).toJson(),
      failure.toJson(),
    );
  });
  test(
    'invalid/NaN/infinite and structurally incomplete state cannot deserialize',
    () {
      final valid = VpmState.initial(
        parameters: parameters,
        conservatism: 0,
        tissues: tissues,
        pressure: pressure,
      ).toJson();
      for (final invalid in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1.0,
      ]) {
        expect(
          () => TissueState(
            nitrogenBar: List.filled(16, invalid),
            heliumBar: List.filled(16, 0),
          ),
          throwsA(isA<CalculationFailure>()),
        );
        final json = Map<String, Object?>.from(valid)..['surfaceBar'] = invalid;
        expect(
          () => VpmState.fromJson(json),
          throwsA(isA<CalculationFailure>()),
        );
      }
      expect(
        () => VpmState.fromJson(
          Map.from(valid)..remove('previousPhaseVolumeMin'),
        ),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => VpmState.fromJson(Map.from(valid)..['ambientOnsetBar'] = [1, 2]),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => TissueState.fromJson({'nitrogenBar': 'wrong', 'heliumBar': []}),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => Gas.fromJson({'oxygen': null, 'helium': 0}),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => PlanRequest(revision: 0, dives: [], modelVersion: 'unknown'),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => OxygenState.fromJson({'cnsFraction': null, 'otu': 0}),
        throwsA(isA<CalculationFailure>()),
      );
    },
  );
}
