import 'dart:convert';
import 'dart:io';
import 'package:deco_core/deco_core.dart';
import 'package:test/test.dart';
import '../../support/legacy_request.dart';

void main() {
  for (final id in [
    'oc-b-no-deco',
    'oc-c-no-deco',
    'oc-nitrox-18m-30min',
    'oc-b-gf100',
    'oc-c-gf100',
    'last-stop-double-b',
    'minimum-stop-override-b',
    'oc-b-deco-switch',
    'oc-c-deco-switch',
    'oc-b-lost-oxygen',
    'oc-c-lost-oxygen',
    'oc-b-multilevel',
    'oc-c-multilevel',
  ]) {
    test('$id raw schedule compared to preserved original observation', () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/legacy_baseline/$id.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source = fixture['request'] as Map<String, dynamic>;
      final actual = calculateBuhlmann(legacyOcRequest(source));
      final observed =
          (fixture['observed'] as List).first as Map<String, dynamic>;
      final independent =
          jsonDecode(
                File(
                  'test/fixtures/independent/$id-tissue-replay.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final replay = independent['expected'] as Map<String, dynamic>;
      final expected = replay['segments'] as List;
      final snapshots = replay['tissue_snapshots_bar'] as List;
      // Only the documented multilevel gas label changes. Legacy files remain
      // immutable; external replay proves that their tissues used the old gas.
      if (id.endsWith('multilevel')) {
        final legacyRows = observed['segments'] as List;
        expect((legacyRows[2] as Map)['o2_fraction'], .5);
        expect((expected[2] as Map)['o2_fraction'], .21);
        expect((expected[2] as Map)['he_fraction'], .35);
      } else {
        expect(expected, observed['segments']);
      }
      expect(
        actual.segments.length,
        expected.length,
        reason:
            'segment count; actual: ${actual.segments.map((s) => [s.physical.startDepthMetres, s.physical.endDepthMetres, s.physical.durationMin, s.physical.breathing.gas.oxygen]).toList()}; expected: ${expected.map((e) => [(e as Map)['start_depth_m'], e['end_depth_m'], e['duration_min'], e['o2_fraction']]).toList()}',
      );
      for (var i = 0; i < expected.length; i++) {
        final row = expected[i] as Map<String, dynamic>;
        final segment = actual.segments[i];
        expect(
          segment.physical.startDepthMetres,
          row['start_depth_m'],
          reason: 'segment$i start',
        );
        expect(
          segment.physical.endDepthMetres,
          row['end_depth_m'],
          reason: 'segment$i end',
        );
        expect(
          segment.physical.durationMin,
          closeTo(row['duration_min'] as num, 1e-10),
          reason: 'segment$i duration',
        );
        expect(
          segment.physical.breathing.gas.oxygen,
          closeTo(row['o2_fraction'] as num, 1e-14),
        );
        expect(
          segment.physical.breathing.gas.helium,
          closeTo(row['he_fraction'] as num, 1e-14),
        );
      }
      for (var index = 0; index < snapshots.length; index++) {
        final tissue = snapshots[index] as Map<String, dynamic>;
        for (var i = 0; i < 16; i++) {
          expect(
            actual.segments[index].endState.tissues.nitrogenBar[i],
            closeTo((tissue['n2'] as List)[i] as num, 1e-10),
            reason: 'segment$index N2 tissue$i',
          );
          expect(
            actual.segments[index].endState.tissues.heliumBar[i],
            closeTo((tissue['he'] as List)[i] as num, 1e-10),
            reason: 'segment$index He tissue$i',
          );
        }
      }
      final oxygenData =
          jsonDecode(
                File(
                  'test/fixtures/independent/oc-oxygen-replay.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final oxygen = (oxygenData['cases'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == id);
      expect(
        actual.finalState.oxygen.cnsFraction,
        closeTo(double.parse(oxygen['cns_fraction'] as String), 1e-12),
      );
      expect(
        actual.finalState.oxygen.otu,
        closeTo(double.parse(oxygen['otu'] as String), 1e-10),
      );
      final expectedTissues =
          observed['final_tissues_bar'] as Map<String, dynamic>;
      for (var i = 0; i < 16; i++) {
        expect(
          actual.finalTissues.nitrogenBar[i],
          closeTo((expectedTissues['n2'] as List)[i] as num, 1e-10),
        );
        expect(
          actual.finalTissues.heliumBar[i],
          closeTo((expectedTissues['he'] as List)[i] as num, 1e-10),
        );
      }
    });
  }
}
