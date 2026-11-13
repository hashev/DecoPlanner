"""Independent tissue replay, not an independent stop-search oracle.
Schedules originate in immutable legacy observations. All tissue propagation is
executed by external DecoTengu, with explicitly normalized compartment1b.
"""
import hashlib
import importlib.metadata
import json
from pathlib import Path
from types import SimpleNamespace
import decotengu.model
ROOT=Path(__file__).resolve().parents[1]
FIXTURES=ROOT/'packages/deco_core/test/fixtures'
NAMES=['oc-air-30m-20min','oc-b-no-deco','oc-c-no-deco','oc-nitrox-18m-30min',
       'oc-b-gf100','oc-c-gf100','last-stop-double-b','minimum-stop-override-b',
       'oc-b-deco-switch','oc-c-deco-switch','oc-b-lost-oxygen','oc-c-lost-oxygen',
       'oc-b-multilevel','oc-c-multilevel']
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name in NAMES:
    source=FIXTURES/'legacy_baseline'/(name+'.json')
    data=json.loads(source.read_text());observed=data['observed'][0]
    model=getattr(decotengu.model,'ZH_L16'+data['request']['model'].upper()+'_GF')()
    first=decotengu.model.ZH_L16B_GF()
    for attr in ['N2_HALF_LIFE','HE_HALF_LIFE','N2_A','N2_B','HE_A','HE_B']:
        setattr(model,attr,(getattr(first,attr)[0],)+getattr(model,attr)[1:])
    model.n2_k_const=model._k_const(model.N2_HALF_LIFE)
    model.he_k_const=model._k_const(model.HE_HALF_LIFE)
    model.START_P_N2=.79
    state=model.init(1.01325);snapshots=[];segments=[]
    for index,row in enumerate(observed['segments']):
        row=dict(row)
        if name.endswith('multilevel') and index==2:
            assert (row['start_depth_m'],row['end_depth_m'],row['o2_fraction'],row['he_fraction'])==(36,21,.5,0)
            row.update(o2_fraction=.21,he_fraction=.35)
        gas=SimpleNamespace(n2=100*(1-row['o2_fraction']-row['he_fraction']),he=100*row['he_fraction'])
        state=model.load(1.01325+row['start_depth_m']*.1,row['duration_min'],gas,
            (row['end_depth_m']-row['start_depth_m'])*.1/row['duration_min'],state)
        segments.append(row)
        snapshots.append({'n2':[p[0] for p in state.tissues],'he':[p[1] for p in state.tissues]})
    final=snapshots[-1]
    assert all(abs(final[g][i]-observed['final_tissues_bar'][g][i])<1e-10
               for g in ['n2','he'] for i in range(16)),name
    result=dict(schema_version=1,id=name+'-tissue-replay',
        provenance=dict(kind='independent-tissue-replay-of-legacy-schedule',
            project='DecoTengu',version=importlib.metadata.version('decotengu'),
            source='https://wrobell.dcmod.org/decotengu/_modules/decotengu/model.html',
            source_sha256=digest(Path(decotengu.model.__file__)),legacy_fixture_sha256=digest(source),
            command='local/oracles/python-env/bin/python tool/capture_schedule_replay.py'),
        normalization='surface1.01325bar/vapour.0627bar, nitrogen.79, compartment1b; legacy schedule timing',
        scope='Tissue propagation only. Stop search/timing remain legacy observations, not independently generated schedules.',
        expected=dict(segments=segments,tissue_snapshots_bar=snapshots,final_tissues_bar=final),
        tolerances=dict(tissue_bar=1e-10,time_min=1e-10))
    out=FIXTURES/'independent'/(result['id']+'.json');out.write_text(json.dumps(result,indent=2)+'\n')
    if name.endswith('multilevel'):
        regression=dict(schema_version=1,id=name+'-gas-label-corrected',
            correction='multilevel-ascent-gas-label',
            provenance=dict(legacy_fixture_sha256=digest(source),independent_fixture=out.name,
                independent_fixture_sha256=digest(out),expected_origin='external DecoTengu tissue replay, not Dart actual output'),
            request=data['request'],expected=result['expected'],tolerances=result['tolerances'])
        target=FIXTURES/'regression';target.mkdir(exist_ok=True)
        (target/(name+'-gas-label-corrected.json')).write_text(json.dumps(regression,indent=2)+'\n')
print('14 legacy schedules replayed independently; two proven gas-label corrections captured')
