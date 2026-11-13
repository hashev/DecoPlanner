"""Export numeric research observations; never include Java source or raw dumps."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--reference-root',type=Path,default=ROOT/'local/reference');args=p.parse_args();ref=args.reference_root
out=ROOT/'packages/deco_core/test/fixtures'
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
archive=json.loads((ref/'analysis/manifest.json').read_text())['archives'][0]
coeff=ref/'analysis/coefficients/buhlmann.json'
x=json.loads(coeff.read_text());tables={k:{n:v for n,v in table.items() if n in ['n2_half','he_half','n2_a_bar','he_a_bar','n2_b','he_b']} for k,table in x['tables'].items()}
write(out/'parameters/buhlmann-observed.json',{'schema_version':1,'purpose':'Observed numeric parameters, pending independent model cross-check','provenance':{'archive_sha256':archive['sha256'],'source_sha256':hashlib.sha256(coeff.read_bytes()).hexdigest(),'source':'analysis/coefficients/buhlmann.json'},'units':{'half':'minute','a':'bar','b':'dimensionless'},'tables':tables})
count=0
for path in sorted((ref/'analysis/fixtures/results').glob('*.json')):
 d=json.loads(path.read_text());req=d['request']
 if req.get('op','plan')!='plan':continue
 imperial=req.get('units','metric')=='imperial'
 depth_factor=.3048 if imperial else 1
 pressure_factor=1.01325/33 if imperial else .1
 record={'schema_version':1,'id':d['id'],'provenance':{'kind':'original-runtime-observation','archive_sha256':d['archive_sha256'],'original_result_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':f'analysis/fixtures/results/{path.name}'},'request':req,'outcome':'legacy-error' if d.get('error') else 'legacy-result','role':'baseline observation, not an independent corrected-model expectation'}
 if not d.get('error') and isinstance(d.get('actual'),list):
  results=[]
  for dive in d['actual']:
   r=dive.get('result')
   if not isinstance(r,dict):break
   results.append({'runtime_display_min':r['T'],'ascent_min':r['l'],'deco_min':r['E'],'offgassing_depth_m':r['Z']*depth_factor,'cns_fraction':r['Y'],'otu':r['A'],'final_tissues_bar':{'n2':[v*pressure_factor if imperial else v/10 for v in r['V']],'he':[v*pressure_factor if imperial else v/10 for v in r['e']]},'segments':[{'start_depth_m':a['V']*depth_factor,'end_depth_m':a['S']*depth_factor,'duration_min':a['B'],'start_min':a['U'],'end_min':a['I'],'gas_index':a['A'],'o2_fraction':a['D'],'he_fraction':a['X'],'setpoint_ata':a['O']} for a in r['n']]})
  if len(results)!=len(d['actual']):continue
  record['observed']=results
 elif not d.get('error'):continue
 if imperial:
  settings=d['settings']
  record['normalization']={'depth_to_metres':depth_factor,'pressure_depth_to_bar':pressure_factor,
    'surface_bar':settings['Ñ']*pressure_factor,'water_vapour_bar':settings['p']*pressure_factor,
    'initial_n2_bar':settings['À']*pressure_factor,'bar_per_metre':pressure_factor/depth_factor,
    'descent_m_min':settings['D']*depth_factor,'ascent_m_min':settings['e']*depth_factor,
    'step_m':settings['s']*depth_factor,'gf_low':settings['G'],'gf_high':settings['a']}
 write(out/'legacy_baseline'/path.name,record);count+=1
print('Exported',count,'semantic baseline cases and 4 coefficient sets')
