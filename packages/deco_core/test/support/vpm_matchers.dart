import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';

/// Field tolerances declared by the independent normalized-reference fixture.
void expectVpmBubble(VpmState actual, Map<String, dynamic> expected) {
  final json = actual.toJson();
  expect(json.keys, unorderedEquals(expected.keys));
  for (final entry in json.entries) {
    final name = entry.key;
    final correct = expected[name];
    if (entry.value is List) {
      final tolerance = name.endsWith('Metres')
          ? 1e-15
          : name.endsWith('Min')
          ? 1e-7
          : 1e-8;
      for (var i = 0; i < 16; i++) {
        expect(
          (entry.value as List)[i],
          closeTo((correct as List)[i] as num, tolerance),
          reason: '$name tissue$i',
        );
      }
    } else if (name.endsWith('Tissues')) {
      expectTissues(entry.value as Map, correct as Map, name);
    } else if (entry.value is double) {
      expect(
        entry.value,
        closeTo(correct as num, name.endsWith('Min') ? 1e-7 : 1e-8),
        reason: name,
      );
    } else {
      expect(entry.value, correct, reason: name);
    }
  }
}

void expectTissues(Map actual, Map expected, String label) {
  for (final gas in ['nitrogenBar', 'heliumBar']) {
    for (var i = 0; i < 16; i++) {
      expect(
        (actual[gas] as List)[i],
        closeTo((expected[gas] as List)[i] as num, 1e-8),
        reason: '$label $gas tissue$i',
      );
    }
  }
}

void expectVpmProfile(CalculationResult result, Map<String, dynamic> row) {
  final prefix = result.segments
      .where(
        (s) =>
            s.phase == SegmentPhase.levelTravel ||
            s.phase == SegmentPhase.levelHold,
      )
      .toList();
  final expectedPrefix = (row['expected_profile_segments'] as List)
      .cast<Map<String, dynamic>>();
  expect(prefix.length, expectedPrefix.length);
  for (var i = 0; i < prefix.length; i++) {
    expect(
      prefix[i].endMin,
      closeTo(expectedPrefix[i]['end_min'] as num, 1e-7),
    );
    expectTissues(
      prefix[i].endState.tissues.toJson(),
      expectedPrefix[i]['tissues'] as Map,
      'prefix$i',
    );
    expectReferenceOxygen(
      prefix[i].endState.oxygen,
      expectedPrefix[i]['oxygen'] as Map,
    );
    final actual = prefix[i].endState.vpm!.toJson();
    final expected = expectedPrefix[i]['bubble'] as Map;
    for (final key in [
      'maxCrushingPressureNitrogenBar',
      'maxCrushingPressureHeliumBar',
      'adjustedInitialRadiusNitrogenMetres',
      'adjustedInitialRadiusHeliumMetres',
      'ambientOnsetBar',
      'tensionOnsetBar',
    ]) {
      final tolerance = key.endsWith('Metres') ? 1e-15 : 1e-8;
      for (var j = 0; j < 16; j++) {
        expect(
          (actual[key] as List)[j],
          closeTo((expected[key] as List)[j] as num, tolerance),
          reason: 'prefix$i $key tissue$j',
        );
      }
    }
  }
  final actual = result.segments
      .where(
        (s) =>
            s.phase == SegmentPhase.ascent ||
            s.phase == SegmentPhase.decompression,
      )
      .toList();
  final expected = (row['expected_segments'] as List)
      .cast<Map<String, dynamic>>();
  expect(actual.length, expected.length);
  final native = (row['request'] as Map)['input'] as List;
  final gases = (native.single as Map)['gasmix_summary'] as List;
  final setpoints = row['setpoints_bar'] as List;
  for (var n = 0; n < actual.length; n++) {
    final a = actual[n], e = expected[n];
    expect(a.phase.name, e['kind']);
    expect(a.physical.endDepthMetres, closeTo(e['end_depth_m'] as num, 1e-10));
    expect(a.physical.durationMin, closeTo(e['duration_min'] as num, 1e-7));
    expect(a.endMin, closeTo(e['end_min'] as num, 1e-7));
    final index = e['gas_index'] as int;
    final gas = gases[index] as Map;
    expect(a.physical.breathing.gas.oxygen, gas['fraction_O2']);
    expect(a.physical.breathing.gas.helium, gas['fraction_He']);
    expect(a.physical.breathing.setpointBar, setpoints[index]);
    expectTissues(
      a.endState.tissues.toJson(),
      e['tissues'] as Map,
      'segment$n',
    );
    expectReferenceOxygen(a.endState.oxygen, e['oxygen'] as Map);
  }
  expectVpmBubble(
    result.finalState.vpm!,
    row['expected_bubble'] as Map<String, dynamic>,
  );
  expect(CalculationResult.fromJson(result.toJson()).toJson(), result.toJson());
}

void expectReferenceOxygen(OxygenState actual, Map expected) {
  expect(actual.cnsFraction, closeTo(expected['cns_fraction'] as num, 1e-10));
  expect(actual.otu, closeTo(expected['otu'] as num, 1e-9));
}
