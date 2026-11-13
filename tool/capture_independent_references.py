"""Capture external numerical oracles; run using local/oracles/python-env/bin/python.
No oracle implementation or reference executable enters the application.
"""
import copy,hashlib,importlib.util,importlib.metadata,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'packages/deco_core/test/fixtures/independent'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,data):
 (OUT/(name+'.json')).write_text(json.dumps(data,indent=2,allow_nan=False)+'\n')
import decotengu,decotengu.model
for letter in ['B','C']:
 engine=decotengu.create();engine.model=getattr(decotengu.model,'ZH_L16'+letter+'_GF')()
 engine.model.gf_low=.3;engine.model.gf_high=.85;engine.ascent_rate=9;engine.descent_rate=10;engine.add_gas(0,21)
 steps=list(engine.calculate(30,20));last=steps[-1]
 data={'schema_version':1,'id':'decotengu-'+letter.lower()+'-air-30-20','provenance':{'kind':'independent-execution','project':'DecoTengu','version':importlib.metadata.version('decotengu'),'source':'https://wrobell.dcmod.org/decotengu/','engine_module_sha256':digest(Path(decotengu.engine.__file__)),'model_module_sha256':digest(Path(decotengu.model.__file__))},'request':{'model':'ZH-L16'+letter+'-GF','coefficient_variant':'upstream default: B uses compartment 1b, C uses 1a','mode':'oc','depth_m':30,'bottom_runtime_min':20,'descent_m_min':10,'ascent_m_min':9,'gf_low':.3,'gf_high':.85,'o2_fraction':.21,'surface_bar':engine.surface_pressure,'water_vapour_bar':engine.model.water_vapour_pressure,'initial_n2_fraction':engine.model.START_P_N2},'expected':{'runtime_min':last.time,'stops':[{'depth_m':s.depth,'duration_min':s.time} for s in engine.deco_table],'final_tissues_bar':{'n2':[p[0] for p in last.data.tissues],'he':[p[1] for p in last.data.tissues]}},'scope':'Independent upstream conventions; normalize before comparing to legacy observations','comparison_policy':'pending-normalization; do not silently treat as exact legacy schedule'}
 write(data['id'],data)
vp=ROOT/'local/oracles/vpmb';commit=subprocess.check_output(['git','-C',str(vp),'rev-parse','HEAD'],text=True).strip()
assert commit=='bec938d84742e42dd43b574beec49ac26f6863ac'
spec=importlib.util.spec_from_file_location('independent_vpmb',vp/'vpmb.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
inp=json.loads((vp/'tests/msw_simple/vpm_decompression_input.json').read_text())
# The upstream OC engine ignores these fields. Remove them so the fixture cannot be mislabeled CCR.
for dive in inp['input']:
 for seg in dive['profile_codes']:
  seg.pop('setpoint',None)
  for ascent in seg.get('ascent_summary',[]):ascent.pop('setpoint',None)
state=module.DiveState(json_input=copy.deepcopy(inp));state.main();result=state.get_json()
for dive in result:dive.pop('time',None)
upstream=json.loads((vp/'tests/msw_simple/expected.json').read_text())
for dive in upstream:dive.pop('time',None)
assert result==upstream,'Independent execution must match author-owned numerical fixture'
write('vpmb-oc-80-30',{'schema_version':1,'id':'vpmb-oc-80-30','provenance':{'kind':'independent-execution','project':'bwaite/vpmb','repository':'https://github.com/bwaite/vpmb','commit':commit,'source_sha256':digest(vp/'vpmb.py'),'upstream_expected_sha256':digest(vp/'tests/msw_simple/expected.json'),'numerical_modifications':False},'request':inp,'expected':{'formatted_profiles':result,'final_n2_native_msw':state.Nitrogen_Pressure,'final_he_native_msw':state.Helium_Pressure,'adjusted_radius_n2_m':state.Adjusted_Critical_Radius_N2,'adjusted_radius_he_m':state.Adjusted_Critical_Radius_He,'barometric_native_msw':state.Barometric_Pressure,'runtime_min':state.Run_Time},'scope':'OC only; setpoint fields are not implemented by this oracle','comparison_policy':'native upstream conventions; normalize before product regression'})
print('Captured B, C and VPM-B independent executions; OC upstream expected profile matched')
