"""Synthetic independent contract for projected-ascent safeguard.
Forcing a deliberately shallow candidate does not prove a normal legacy
schedule was affected; the separate search report records that distinction.
"""
import copy,hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/vpmb';FIX=ROOT/'packages/deco_core/test/fixtures'
spec=importlib.util.spec_from_file_location('projected_contract',REF/'vpmb.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
case=json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases'][0]
state=module.DiveState(json_input=copy.deepcopy(case['request']));original=state.projected_ascent
class Captured(Exception):pass
result=None
def check(*args):
    global result
    native_candidate=state.Deco_Stop_Depth;state.Deco_Stop_Depth=0;factor=1.01325/state.Units_Factor
    inp=dict(from_m=args[0],ascent_m_min=abs(args[1]),step_m=args[2],candidate_m=0,
        tissues=dict(nitrogenBar=[v*factor for v in state.Nitrogen_Pressure],heliumBar=[v*factor for v in state.Helium_Pressure]),
        nitrogen_gradients_bar=[v*factor for v in state.Allowable_Gradient_N2],helium_gradients_bar=[v*factor for v in state.Allowable_Gradient_He],
        oxygen=.15,helium=.45,surface_bar=state.Barometric_Pressure*factor,vapour_bar=state.Water_Vapor_Pressure*factor)
    original(*args)
    assert state.Deco_Stop_Depth>0
    result=dict(schema_version=1,id='projected-ascent-synthetic-contract',
        role='Synthetic deliberately shallow candidate; not a proven affected original schedule',
        provenance=dict(kind='independent-synthetic-helper-execution',repository='https://github.com/bwaite/vpmb',
            commit='bec938d84742e42dd43b574beec49ac26f6863ac',source_sha256=hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),
            command='local/oracles/python-env/bin/python tool/capture_projected_ascent_contract.py'),
        original_selected_candidate_m=native_candidate,input=inp,expected=dict(candidate_m=state.Deco_Stop_Depth))
    raise Captured()
state.projected_ascent=check
try:state.main()
except Captured:pass
assert result
(FIX/'independent/vpmb-projected-ascent-contract.json').write_text(json.dumps(result,indent=2)+'\n')
print('Captured independent synthetic projected safeguard:',result['input']['candidate_m'],'→',result['expected']['candidate_m'])
