"""Verify observed coefficient numbers against independent DecoTengu tables.
Run in the private reference Python environment, before testing our engine.
"""
import hashlib
import importlib.metadata
import json
from pathlib import Path
from types import SimpleNamespace
import decotengu.model
ROOT=Path(__file__).resolve().parents[1]
observed=json.loads((ROOT/'packages/deco_core/test/fixtures/parameters/buhlmann-observed.json').read_text())['tables']
fields={'n2_half':'N2_HALF_LIFE','he_half':'HE_HALF_LIFE','n2_a_bar':'N2_A','he_a_bar':'HE_A','n2_b':'N2_B','he_b':'HE_B'}
output=[]
for letter in ['b','c']:
    model=getattr(decotengu.model, 'ZH_L16'+letter.upper()+'_GF')()
    # Product explicitly selects compartment1b for both versions. Replace only
    # upstream C's1a row with upstream B's1b row; do not load observed numbers.
    first=decotengu.model.ZH_L16B_GF()
    for attr in fields.values():
        setattr(model,attr,(getattr(first,attr)[0],)+getattr(model,attr)[1:])
    tables={name:list(getattr(model,attr)) for name,attr in fields.items()}
    assert tables==observed[letter+'-oc']==observed[letter+'-ccr']
    n2=[.7 + .2*i for i in range(16)];he=[.03*i for i in range(16)]
    data=SimpleNamespace(tissues=list(zip(n2,he)))
    output.append(dict(model='zh-l16'+letter+'-1b-v1',tables=tables,
        tissue_case=dict(n2_bar=n2,he_bar=he),
        expected_ceilings_bar={str(gf):list(model.gf_limit(gf,data)) for gf in [.1,.3,.85,1.0]}))
source=Path(decotengu.model.__file__)
result=dict(schema_version=1,provenance=dict(kind='independent-parameter-verification-and-execution',
    project='DecoTengu',version=importlib.metadata.version('decotengu'),source='https://wrobell.dcmod.org/decotengu/_modules/decotengu/model.html',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),command='local/oracles/python-env/bin/python tool/capture_buhlmann_parameters.py'),
    normalization='Compartment1b selected for both versions from independent B tables; remaining C rows unchanged',models=output)
(ROOT/'packages/deco_core/test/fixtures/independent/buhlmann-1b-parameters-and-ceilings.json').write_text(json.dumps(result,indent=2)+'\n')
print('All six16-component tables verified for B/C OC/CCR; captured independent ceilings')
