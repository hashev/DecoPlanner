"""Find an actual independent model profile whose projected candidate deepens.
Stop the source program immediately after its first projected-ascent check.
"""
import copy,hashlib,importlib.util,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/vpmb';PIN='bec938d84742e42dd43b574beec49ac26f6863ac'
assert subprocess.check_output(['git','-C',str(REF),'rev-parse','HEAD'],text=True).strip()==PIN
spec=importlib.util.spec_from_file_location('projected_reference',REF/'vpmb.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
base=json.loads((REF/'tests/msw_simple/vpm_decompression_input.json').read_text())
class Captured(Exception):pass
found=None;tested=0;rejected={};start=time.monotonic()
for depth in [30,45,60,80,100,150,200,250,350,500,750,1000]:
 for duration in [10,20,30,60,120,240]:
  for oxygen,helium in [(.21,0),(.21,.35),(.1,.7),(.08,.8),(.03,.95),(.02,.97)]:
   for conserv,scale in [(0,1),(2,1.15),(4,1.35)]:
    if time.monotonic()-start>30:raise SystemExit('Reference search time budget exhausted without proof')
    if duration<depth/23:continue
    request=copy.deepcopy(base);dive=request['input'][0]
    dive['gasmix_summary'][0].update(fraction_O2=oxygen,fraction_He=helium,fraction_N2=1-oxygen-helium)
    for segment in dive['profile_codes']:
     segment.pop('setpoint',None)
     if 'ending_depth' in segment:segment['ending_depth']=depth
     if 'depth' in segment:segment['depth']=depth;segment['run_time_at_end_of_segment']=duration
     for ascent in segment.get('ascent_summary',[]):ascent['starting_depth']=depth;ascent.pop('setpoint',None)
    request['settings'].update(Critical_Radius_N2_Microns=.45*scale,Critical_Radius_He_Microns=.55*scale,Crit_Volume_Parameter_Lambda=6500)
    state=module.DiveState(json_input=copy.deepcopy(request));original=state.projected_ascent
    def check(*args):
     global found
     before=state.Deco_Stop_Depth;factor=1.01325/state.Units_Factor
     tissues={'nitrogenBar':[v*factor for v in state.Nitrogen_Pressure],'heliumBar':[v*factor for v in state.Helium_Pressure]}
     n=[v*factor for v in state.Allowable_Gradient_N2];h=[v*factor for v in state.Allowable_Gradient_He]
     result=original(*args)
     if state.Deco_Stop_Depth>before:
      found=dict(schema_version=1,id='vpmb-projected-ascent-deepens',request=request,conservatism=conserv,
       input=dict(from_m=args[0],ascent_m_min=abs(args[1]),step_m=args[2],candidate_m=before,tissues=tissues,
                  nitrogen_gradients_bar=n,helium_gradients_bar=h,surface_bar=state.Barometric_Pressure*factor,
                  vapour_bar=state.Water_Vapor_Pressure*factor,other_gases_bar=state.Constant_Pressure_Other_Gases*factor,
                  oxygen=oxygen,helium=helium),expected=dict(candidate_m=state.Deco_Stop_Depth),
       provenance=dict(kind='independent-real-profile-execution',repository='https://github.com/bwaite/vpmb',commit=PIN,
        source_sha256=hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),numerical_modifications=False,
        command='local/oracles/python-env/bin/python tool/find_projected_ascent_reference.py'))
     raise Captured()
    state.projected_ascent=check
    try:state.main()
    except Captured:pass
    except Exception as error:
     key=type(error).__name__;rejected[key]=rejected.get(key,0)+1
    tested+=1
    if found:break
   if found:break
  if found:break
 if found:break
if not found:
 report={'schema_version':1,'counterexample_found':False,'profiles_tested':tested,'source_errors':rejected,
   'scope':'First projected-ascent call across the declared deterministic grid; not proof for all possible inputs',
   'classification':'Discarded legacy return is statically ineffective; numerical schedule impact unproven on searched grid',
   'provenance':{'repository':'https://github.com/bwaite/vpmb','commit':PIN,'source_sha256':hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),
                 'command':'local/oracles/python-env/bin/python tool/find_projected_ascent_reference.py'}}
 (ROOT/'docs/models/projected-ascent-search.json').write_text(json.dumps(report,indent=2)+'\n')
 print(f'No counterexample in{tested} profiles; source errors{rejected}; classification remains explicit')
 raise SystemExit(0)
path=ROOT/'packages/deco_core/test/fixtures/independent/vpmb-projected-ascent-edge.json'
found['search_summary']={'profiles_tested':tested,'source_errors':rejected}
path.write_text(json.dumps(found,indent=2,allow_nan=False)+'\n')
print('Proven projected deepening after',tested,'profiles:',found['input']['candidate_m'],'→',found['expected']['candidate_m'])
