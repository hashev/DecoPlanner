"""Read-only audit of the independent descending multilevel VPM matrix."""
import hashlib
import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT/'packages/deco_core/test/fixtures/independent/vpmb-multilevel-descending-units.json'
registry = json.loads((ROOT/'docs/models/vpm-multilevel-reference.json').read_text())
assert registry['fixture'] == str(FIX.relative_to(ROOT))
assert registry['fixture_sha256'] == hashlib.sha256(FIX.read_bytes()).hexdigest(), 'Fixture changed after independent validation.'
data = json.loads(FIX.read_text(), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
provenance = data['provenance']
for field, filename in [
    ('generator_sha256','capture_vpm_multilevel_descending.py'),
    ('adapter_sha256','reference_vpm_schedule.py'),
    ('oxygen_adapter_sha256','reference_oxygen_quadrature.py'),
]:
    assert provenance[field] == hashlib.sha256((ROOT/'tool'/filename).read_bytes()).hexdigest(), filename
assert provenance['commit'] == 'bec938d84742e42dd43b574beec49ac26f6863ac'
expected = {f'vpm-multilevel-descending-{mode}-{units}-c{c}' for c,units,mode in itertools.product(range(5),['metric','imperial'],['oc','ccr','bailout'])}
rows = data['cases']
assert len(rows) == len(expected) == 30
assert {row['id'] for row in rows} == expected
assert data['tolerances'] == dict(time_min=1e-7,tissue_bar=1e-8,gradient_bar=1e-8,radius_m=1e-15,phase_min=1e-7,cns_fraction=1e-10,otu=1e-9)
for row in rows:
    assert len(row['levels']) == 4
    assert all(b['depth_metres'] > a['depth_metres'] for a,b in zip(row['levels'],row['levels'][1:]))
    assert row['step_metres'] == (3 if row['units']=='metric' else 3.048)
    assert len(row['expected_profile_segments']) == 8
    assert abs(row['expected_segments'][-1]['end_depth_m']) < 1e-10
    assert all(len(row['expected_bubble'][key]) == 16 for key in ['initialRadiusNitrogenMetres','maxCrushingPressureNitrogenBar'])
print('PASS: 30 independent descending multilevel VPM references; matrix, provenance and declared tolerances intact.')
