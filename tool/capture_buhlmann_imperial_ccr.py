"""Independent B/C CCR and bailout stop enumeration on a physical 10ft grid.
Reuses the reviewed external-kinetics/ODE reference without editing its 3m cases.
"""
import hashlib
import importlib.metadata
import inspect
import json
from pathlib import Path
import decotengu.model as dm
import capture_buhlmann_bailout as base

ROOT=Path(__file__).resolve().parents[1]
original=inspect.getsource(base.reference)
assert original.count('candidates = [0] + list(range(3, int(depth) + 1, 3))')==1
assert original.count('next_stop = max(0, depth - 3)')==1
adapted=original.replace('def reference(', 'def reference_grid(',1)
adapted=adapted.replace('candidates = [0] + list(range(3, int(depth) + 1, 3))','candidates = [0] + [i*3.048 for i in range(1, int(math.floor(depth/3.048))+1)]')
adapted=adapted.replace('next_stop = max(0, depth - 3)','next_stop = max(0, depth - 3.048)\n        if next_stop < 3.048e-10: next_stop = 0')
namespace=dict(base.__dict__)
exec(compile(adapted,'independent-buhlmann-10ft-reference','exec'),namespace)
reference=namespace['reference_grid']
rows=[]
for letter in ['B','C']:
    for variant in ['ccr-no-switch','ccr-switches','bailout-hold','bailout-end']:
        ccr=variant.startswith('ccr'); point=12.5 if variant=='bailout-hold' else 25.
        switches=[] if variant=='ccr-no-switch' else ([[7*3.048,.18,.45,1.4],[2*3.048,.21,.35,.7]] if ccr else [[7*3.048,.5,0],[2*3.048,.8,0]])
        row=reference(letter,point,switches,ccr=ccr)
        row['id']=f'buhlmann-{letter.lower()}-imperial-{variant}'
        rows.append(row)
        print(row['id'],row['expected']['runtime_min'],flush=True)
output=dict(schema_version=1,provenance=dict(kind='independent-external-kinetics-and-CCR-ODE-physical-grid-enumeration',decotengu_version=importlib.metadata.version('decotengu'),mpmath_version=importlib.metadata.version('mpmath'),model_source_sha256=hashlib.sha256(Path(dm.__file__).read_bytes()).hexdigest(),base_adapter_sha256=hashlib.sha256((ROOT/'tool/capture_buhlmann_bailout.py').read_bytes()).hexdigest(),generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),normalized_function_sha256=hashlib.sha256(adapted.encode()).hexdigest(),oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),command='local/oracles/python-env/bin/python tool/capture_buhlmann_imperial_ccr.py'),normalization='B/C1b; surface1.01325bar/vapour.0627bar/N2.79; GF30/85; step/last10ft=3.048m; physical level45m/25min; lowSP.7 then1.3; ascent9m/min; enumerate aligned minute departures. Floating residual of surface grid is snapped to zero within3.048e-10m.',tolerances=dict(time_min=1e-10,depth_m=1e-10,tissue_bar=1e-10,cns_fraction=1e-10,otu=1e-9),cases=rows)
(ROOT/'packages/deco_core/test/fixtures/independent/buhlmann-imperial-ccr-bailout.json').write_text(json.dumps(output,indent=2,allow_nan=False)+'\n')
