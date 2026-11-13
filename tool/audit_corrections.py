"""Read-only completeness/evidence audit of the correction registry."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
EXPECTED = set("""vpm-oc-altitude
vpm-ccr-altitude-overwrite
vpm-si-index
buhlmann-si-inclusive
cns-integer-recovery
cns-high-po2
cns-movement-top-band
vpm-bad-root-bracket
vpm-unbounded-iteration
vpm-any-convergence
vpm-projected-ascent
real-gas-newton
real-gas-static-units
z-table-lower-bound
real-gas-drain
continuous-blending-limits
zero-rmv
zero-profile-duration
zero-oxygen-mod
legacy-chart-state
reserve-absence
decompiler-copy-loop
unofficial-distribution
multilevel-ascent-gas-label
cns-movement-band-equality
vpm-zero-crushing-ratio
vpm-swapped-gas-gradients
vpm-no-deco-missing-ascent-segment
ccr-usage-overlap
stop-group-average-count""".splitlines())
data = json.loads((ROOT/'docs/models/corrections.json').read_text())
rows = data['entries']
assert len(rows) == len(EXPECTED)
assert {r['id'] for r in rows} == EXPECTED
for row in rows:
    for name in ['classification','target_rule','source_version','required_checks','implementation_status','validation_status','permitted_legacy_difference']:
        assert row[name] and 'pending' not in row[name].lower(), (row['id'],name)
    for fixture in row['independent_fixtures']:
        assert (ROOT/'packages/deco_core/test/fixtures/independent'/fixture).is_file(), (row['id'],fixture)
    for evidence in row.get('evidence_files',[]):
        assert (ROOT/evidence).is_file(), evidence
    for parameter in row.get('reference_parameters',[]):
        assert (ROOT/'packages/deco_core/test/fixtures'/parameter).is_file(),parameter
    assert row['independent_fixtures'] or row.get('evidence_files'), row['id']
by_id = {r['id']:r for r in rows}
assert by_id['vpm-any-convergence']['classification'] == 'intentional-model-rule'
assert 'unproven' in by_id['vpm-projected-ascent']['classification']
assert by_id['reserve-absence']['classification'] == 'intentional-scope-boundary'
assert by_id['unofficial-distribution']['classification'] == 'provenance-limitation'
print(f"PASS: {len(rows)} correction/suspicion/scope entries retained with evidence; classifications preserved.")
