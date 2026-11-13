import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/independent/oxygen-baker-mpmath.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final raw in [
    ...fixture['cases'] as List,
    ...fixture['worked_example_exact_depth'] as List,
  ]) {
    final row = raw as Map<String, dynamic>;
    test('independent quadrature: ${row['id']}', () {
      final result = OxygenPolicy.expose(
        OxygenState(),
        startOxygenBar: Units.ataToBar(
          double.parse(row['start_ata'] as String),
        ),
        endOxygenBar: Units.ataToBar(double.parse(row['end_ata'] as String)),
        durationMin: double.parse(row['duration_min'] as String),
      );
      expect(
        result.cnsFraction,
        closeTo(double.parse(row['cns_fraction'] as String), 1e-12),
      );
      expect(result.otu, closeTo(double.parse(row['otu'] as String), 1e-10));
    });
  }
  test(
    'all requested SI values have continuous recovery, preserved OTU and SI0 identity',
    () {
      final initial = OxygenState(cnsFraction: 1, otu: 100);
      for (final raw in fixture['recovery'] as List) {
        final row = raw as Map<String, dynamic>;
        final result = OxygenPolicy.surfaceInterval(
          initial,
          (row['surface_interval_min'] as num).toDouble(),
        );
        expect(
          result.cnsFraction,
          closeTo(double.parse(row['cns_from_one'] as String), 1e-14),
        );
        expect(result.otu, 100);
      }
      expect(
        identical(OxygenPolicy.surfaceInterval(initial, 0), initial),
        isTrue,
      );
      final twice = OxygenPolicy.surfaceInterval(
        OxygenPolicy.surfaceInterval(initial, 45),
        45,
      );
      expect(twice.cnsFraction, closeTo(.5, 1e-15));
      expect(OxygenPolicy.surfaceInterval(initial, 1440).otu, 100);
    },
  );
  test('high-PO2 legacy constants are replaced with a domain failure', () {
    for (final p in [1.600001, 1.74, 1.82, 1.9]) {
      expect(
        () => OxygenPolicy.expose(
          OxygenState(),
          startOxygenBar: Units.ataToBar(p),
          endOxygenBar: Units.ataToBar(p),
          durationMin: 10,
        ),
        throwsA(
          isA<CalculationFailure>().having(
            (f) => f.code,
            'code',
            CalculationFailureCode.outsideModelDomain,
          ),
        ),
      );
    }
  });
  test('zero-time exposure and JSON round trip retain unrounded state', () {
    final initial = OxygenState(
      cnsFraction: .123456789123456,
      otu: 100.123456789,
    );
    expect(
      identical(
        OxygenPolicy.expose(
          initial,
          startOxygenBar: 1,
          endOxygenBar: 1,
          durationMin: 0,
        ),
        initial,
      ),
      isTrue,
    );
    final copy = OxygenState.fromJson(
      (jsonDecode(jsonEncode(initial.toJson())) as Map).cast<String, Object?>(),
    );
    expect(copy.toJson(), initial.toJson());
    for (final invalid in [double.nan, double.infinity, -1.0]) {
      expect(
        () => OxygenState(cnsFraction: invalid),
        throwsA(isA<CalculationFailure>()),
      );
      expect(
        () => OxygenPolicy.surfaceInterval(initial, invalid),
        throwsA(isA<CalculationFailure>()),
      );
    }
  });
  test(
    'near-constant movement stays accurate and matches the constant limit',
    () {
      final constant = OxygenPolicy.expose(
        OxygenState(),
        startOxygenBar: Units.ataToBar(1.3),
        endOxygenBar: Units.ataToBar(1.3),
        durationMin: 10,
      );
      final linear = OxygenPolicy.expose(
        OxygenState(),
        startOxygenBar: Units.ataToBar(1.3),
        endOxygenBar: Units.ataToBar(1.300000000001),
        durationMin: 10,
      );
      expect(linear.cnsFraction, closeTo(constant.cnsFraction!, 1e-12));
      expect(linear.otu, closeTo(constant.otu, 1e-9));
    },
  );
  test(
    'unsupported CNS preserves numeric OTU and unknown state through SI/JSON',
    () {
      final data =
          jsonDecode(
                File(
                  'test/fixtures/independent/oxygen-outside-cns-domain-mpmath.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final raw in data['cases'] as List) {
        final row = raw as Map<String, dynamic>;
        final start = double.parse(row['start_ata'] as String),
            end = double.parse(row['end_ata'] as String);
        final context = PressureContext(
          surfaceBar: Units.ataToBar(.1),
          waterVapourBar: .01,
          barPerMetre: .1,
        );
        final physical = PropagationSegment(
          startDepthMetres: context.depthMetres(Units.ataToBar(start)),
          endDepthMetres: context.depthMetres(Units.ataToBar(end)),
          durationMin: (row['duration_min'] as num).toDouble(),
          breathing: BreathingGas.oc(Gas(oxygen: 1)),
        );
        final result = OxygenPolicy.exposeSegment(
          OxygenState(),
          physical,
          context,
        );
        expect(result.cnsFraction, isNull);
        expect(
          result.cnsUnavailableReason?.code,
          CalculationFailureCode.outsideModelDomain,
        );
        expect(result.otu, closeTo(double.parse(row['otu'] as String), 1e-10));
        final after = OxygenPolicy.surfaceInterval(result, 1440);
        expect(after.cnsFraction, isNull);
        expect(after.otu, result.otu);
        final copy = OxygenState.fromJson(
          (jsonDecode(jsonEncode(after.toJson())) as Map)
              .cast<String, Object?>(),
        );
        expect(copy.toJson(), after.toJson());
        final later = OxygenPolicy.expose(
          copy,
          startOxygenBar: Units.ataToBar(1.3),
          endOxygenBar: Units.ataToBar(1.3),
          durationMin: 1,
        );
        expect(later.cnsFraction, isNull);
        expect(later.otu, greaterThan(copy.otu));
        expect(
          later.cnsUnavailableReason?.message,
          copy.cnsUnavailableReason?.message,
        );
      }
    },
  );
  test(
    'clipped motion lower boundary uses intersections, not duplicate full bands',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/regression/cns-clipped-lower-band-equality.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expected = fixture['expected'] as Map<String, dynamic>;
      final result = OxygenPolicy.expose(
        OxygenState(),
        startOxygenBar: Units.ataToBar(.21),
        endOxygenBar: (1.01325 + 3) * .21,
        durationMin: 3,
      );
      expect(
        result.cnsFraction,
        closeTo(double.parse(expected['cns_fraction'] as String), 1e-12),
      );
      expect(
        result.otu,
        closeTo(double.parse(expected['otu'] as String), 1e-10),
      );
      expect(
        (fixture['legacy_observed'] as Map)['cns_fraction'],
        .004973526151167392,
      );
    },
  );
}
