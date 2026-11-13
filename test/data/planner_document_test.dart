import 'dart:convert';
import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/models/planner_document.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/document_fixtures.dart';

Map<String, Object?> copy(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

void main() {
  test(
    'gas-set optional schema1 extension validates and preserves full switches',
    () {
      final set = GasSetPreset(
        id: 'set-1',
        name: 'Deco gases',
        switches: [
          GasSwitch(
            depthMetres: 21,
            breathing: BreathingGas.oc(Gas(oxygen: .5)),
            lost: true,
            minimumStopMin: 2,
          ),
          GasSwitch(
            depthMetres: 6,
            breathing: BreathingGas.ccr(Gas(oxygen: .18, helium: .45), 1.4),
          ),
        ],
      );
      final document = documentFixture().copyWith(gasSets: [set]);
      expect(
        decodePlannerDocument(
          encodePlannerDocument(document),
        ).gasSets.single.toJson(),
        set.toJson(),
      );
      final old = copy(document.toJson())..remove('gasSets');
      expect(PlannerDocument.fromJson(old).gasSets, isEmpty);
      expect(
        () => document.copyWith(gasSets: [set, set]),
        throwsA(isA<DocumentFailure>()),
      );
      expect(() => document.gasSets.clear(), throwsUnsupportedError);
    },
  );

  test(
    'complete physical inputs, VPM state, unknown CNS, catalogues, comparisons and invalid drafts round-trip',
    () {
      final document = documentFixture();
      final bytes = encodePlannerDocument(document);
      final result = decodePlannerDocument(bytes);
      expect(result.toJson(), document.toJson());
      expect(encodePlannerDocument(result), bytes);
      expect(result.usesCurrentModel, isTrue);
      expect(result.plan.dives[1].surfaceIntervalMin, 45);
      expect(
        result.results['escape']!.result.finalState.oxygen.cnsFraction,
        isNull,
      );
      expect(
        result
            .results['escape']!
            .result
            .finalState
            .vpm!
            .maxCrushingPressureNitrogenBar,
        isNotEmpty,
      );
      expect(result.toolDrafts['mod']!['oxygen'], 'abc');
      expect(
        () => result.toolDrafts['mod']!['oxygen'] = '21',
        throwsUnsupportedError,
      );
      expect(() => result.results.clear(), throwsUnsupportedError);
      expect(() => result.gases.clear(), throwsUnsupportedError);
    },
  );
  test(
    'old model version retains inputs and outputs as stale without relabeling their provenance',
    () {
      final raw = copy(documentFixture().toJson());
      raw['modelVersion'] = 'old-engine-v0';
      (raw['plan'] as Map)['modelVersion'] = 'old-engine-v0';
      for (final result in (raw['results'] as Map).values) {
        ((result as Map)['result'] as Map)['modelVersion'] = 'old-engine-v0';
      }
      final old = PlannerDocument.fromJson(raw);
      final restored = decodePlannerDocument(encodePlannerDocument(old));
      expect(restored.usesCurrentModel, isFalse);
      expect(restored.modelVersion, 'old-engine-v0');
      expect(restored.plan.modelVersion, calculationModelVersion);
      expect(restored.results['source']!.result.modelVersion, 'old-engine-v0');
      expect(restored.toJson(), raw);
    },
  );
  test(
    'unknown schema, altered payload, non-UTF8 and oversized content fail explicitly',
    () {
      final bytes = encodePlannerDocument(documentFixture());
      final unknown = jsonDecode(utf8.decode(bytes)) as Map;
      unknown['schemaVersion'] = 99;
      expect(
        () => decodePlannerDocument(utf8.encode(jsonEncode(unknown))),
        throwsA(
          isA<DocumentFailure>().having(
            (e) => e.kind,
            'kind',
            DocumentFailureKind.unsupportedSchema,
          ),
        ),
      );
      final changed = jsonDecode(utf8.decode(bytes)) as Map;
      (changed['document'] as Map)['name'] = 'Changed';
      expect(
        () => decodePlannerDocument(utf8.encode(jsonEncode(changed))),
        throwsA(
          isA<DocumentFailure>().having(
            (e) => e.kind,
            'kind',
            DocumentFailureKind.integrity,
          ),
        ),
      );
      expect(
        () => decodePlannerDocument([255]),
        throwsA(isA<DocumentFailure>()),
      );
      expect(
        () => decodePlannerDocument(bytes, maxBytes: bytes.length - 1),
        throwsA(
          isA<DocumentFailure>().having(
            (e) => e.kind,
            'kind',
            DocumentFailureKind.tooLarge,
          ),
        ),
      );
      expect(
        () => encodePlannerDocument(documentFixture(), maxBytes: 100),
        throwsA(
          isA<DocumentFailure>().having(
            (e) => e.kind,
            'kind',
            DocumentFailureKind.tooLarge,
          ),
        ),
      );
    },
  );
  test('checksum is independent of JSON key ordering', () {
    final bytes = encodePlannerDocument(documentFixture());
    Object? reverse(Object? value) => switch (value) {
      Map() => Map.fromEntries(
        value.entries.toList().reversed.map(
          (e) => MapEntry(e.key, reverse(e.value)),
        ),
      ),
      List() => value.map(reverse).toList(),
      _ => value,
    };
    final reordered = utf8.encode(
      jsonEncode(reverse(jsonDecode(utf8.decode(bytes)))),
    );
    expect(
      decodePlannerDocument(reordered).toJson(),
      documentFixture().toJson(),
    );
  });
  test(
    'bad identifiers, invalid dates, duplicate catalogues and inconsistent snapshots are rejected',
    () {
      for (final id in ['', '../escape', r'a\b', 'a/b', 'a\n', '.hidden']) {
        expect(validDocumentId(id), isFalse);
      }
      for (final mutate in <void Function(Map<String, Object?>)>[
        (r) => r['id'] = '../outside',
        (r) => r['name'] = ' ',
        (r) => r['createdAt'] = '2026-02-31T00:00:00.000Z',
        (r) => r['modifiedAt'] = '2025-01-01T00:00:00.000Z',
        (r) => (r['gases'] as List).add((r['gases'] as List).first),
        (r) => ((r['results'] as Map)['source'] as Map)['inputRevision'] = 100,
        (r) =>
            (((r['results'] as Map)['source'] as Map)['result']
                    as Map)['diveId'] =
                'foreign',
      ]) {
        final raw = copy(documentFixture().toJson());
        mutate(raw);
        expect(
          () => PlannerDocument.fromJson(raw),
          throwsA(isA<DocumentFailure>()),
        );
      }
    },
  );
  test('overly nested JSON is rejected before recursive model parsing', () {
    final envelope =
        jsonDecode(utf8.decode(encodePlannerDocument(documentFixture())))
            as Map;
    Object? nested = 0;
    for (var i = 0; i < 140; i++) {
      nested = [nested];
    }
    (envelope['document'] as Map)['extra'] = nested;
    expect(
      () => decodePlannerDocument(utf8.encode(jsonEncode(envelope))),
      throwsA(isA<DocumentFailure>()),
    );
  });
}
