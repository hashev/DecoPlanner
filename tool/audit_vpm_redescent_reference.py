"""Read-only audit of the independently executed partial-ascent VPM matrix."""
import hashlib
import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT/'packages/deco_core/test/fixtures/independent/vpmb-redescent-normalized.json'
registry = json.loads((ROOT/'docs/models/vpm-redescent-reference.json').read_text())
assert registry['fixture'] == str(FIX.relative_to(ROOT))
assert registry['fixture_sha256'] == hashlib.sha256(FIX.read_bytes()).hexdigest(), 'Fixture changed after validation.'
data = json.loads(FIX.read_text(), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
provenance = data['provenance']
for field, filename in [
    ('generator_sha256','capture_vpm_redescent.py'),
    ('adapter_sha256','reference_vpm_multilevel.py'),
    ('base_adapter_sha256','reference_vpm_schedule.py'),
    ('oxygen_adapter_sha256','reference_oxygen_quadrature.py'),
]:
    assert provenance[field] == hashlib.sha256((ROOT/'tool'/filename).read_bytes()).hexdigest(), filename
assert provenance['commit'] == 'bec938d84742e42dd43b574beec49ac26f6863ac'
expected = {f'vpm-redescent{suffix}-{mode}-{units}-c{c}' for c,units,mode,suffix in itertools.product(range(5),['metric','imperial'],['oc','ccr','bailout'],['','-stops'])}
rows = data['cases']
assert len(rows) == len(expected) == 60
assert {row['id'] for row in rows} == expected
assert data['tolerances'] == dict(time_min=1e-7,tissue_bar=1e-8,gradient_bar=1e-8,radius_m=1e-15,cns_fraction=1e-10,otu=1e-9)
for row in rows:
    segments = row['expected_timeline']
    assert row['step_metres'] == (3 if row['units']=='metric' else 3.048)
    assert any(s['kind']=='levelTravel' and s['end_depth_m']>s['start_depth_m']>0 for s in segments)
    assert segments[-1]['bubble'] == row['expected_bubble']
    assert abs(segments[-1]['end_depth_m']) < 1e-10
    assert abs(segments[-1]['end_min']-row['metrics']['runtime_min']) < 1e-7
    assert row['raw_surface_bubble']['modelVersion'] == row['expected_bubble']['modelVersion']
    if row['variant']=='with-stops':
        target_hold = next(i for i,s in enumerate(segments) if i>2 and s['kind']=='levelHold')
        assert any(s['kind']=='decompression' for s in segments[:target_hold])
    for segment in segments:
        assert segment['duration_min'] > 0
        assert len(segment['tissues']['nitrogenBar']) == len(segment['tissues']['heliumBar']) == 16
print('PASS: 60 independent VPM partial-ascent/redescent references; full matrix, hashes, state and tolerance contracts intact.')
