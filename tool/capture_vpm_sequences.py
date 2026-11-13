"""Independent full OC altitude/repetitive schedules and oxygen quadrature.
No Dart execution, no product outputs used as expected values.
"""
import copy
import hashlib
import json
import mpmath as mp
from reference_vpm_schedule import FIX, PIN, source, run_reference

mp.mp.dps = 70
BANDS = [('.5','.6',-1800,1800),('.6','.7',-1500,1620),('.7','.8',-1200,1410),
         ('.8','.9',-900,1170),('.9','1.1',-600,900),('1.1','1.5',-300,570),('1.5','1.6',-750,1245)]
bands = [(mp.mpf(a),mp.mpf(b),m,c) for a,b,m,c in BANDS]

def exposure(a, b, minutes):
    a,b,t = mp.mpf(str(a)),mp.mpf(str(b)),mp.mpf(str(minutes))
    assert max(a,b) <= mp.mpf('1.6')
    def cns(p):
        if p <= mp.mpf('.5'): return mp.mpf(0)
        for lo,hi,m,c in bands:
            if lo < p <= hi: return 1/(m*p+c)
        raise ValueError(p)
    def otu(p): return max(mp.mpf(0),2*(p-mp.mpf('.5')))**(mp.mpf(5)/6)
    if a==b: return t*cns(a),t*otu(a)
    lo,hi=sorted([a,b])
    cuts=sorted(set([lo,hi]+[p for band in bands for p in band[:2] if lo<p<hi]))
    return tuple(mp.fsum(mp.quad(f,[u,v]) for u,v in zip(cuts,cuts[1:]))*t/(hi-lo) for f in [cns,otu])

base_file = FIX/'independent/vpmb-normalized-schedules.json'
base = next(r for r in json.loads(base_file.read_text())['cases'] if r['id']=='vpm-oc-c2')['request']
rows=[]
for description, altitude, interval in [
    ('altitude-2000-acclimatized', (2000, True, 0, 0), None),
    ('altitude-2000-travel', (2000, False, 180, 120), None),
    ('altitude-8848-travel', (8848, False, 120, 30), None),
] + [(f'repetitive-si{t}', None, t) for t in [0,45,60,180,1440]]:
    inp=copy.deepcopy(base)
    if altitude:
        height,acclimatized,travel,wait=altitude
        inp['settings']['Altitude_Dive_Algorithm']='ON'
        inp['altitude'].update(Altitude_of_Dive=height,Diver_Acclimatized_at_Altitude='yes' if acclimatized else 'no',
            Starting_Acclimatized_Altitude=0,Ascent_to_Altitude_Hours=travel/60,Hours_at_Altitude_Before_Dive=wait/60)
    if interval is not None:
        inp['input'].append(copy.deepcopy(inp['input'][0]))
        inp['input'][0].update(repetitive_code=1,surface_interval_time_minutes=interval)
    results=run_reference(inp,sea_bar=None if altitude else 1.01325)
    cns=mp.mpf(0);otu=mp.mpf(0)
    for index,(dive,result) in enumerate(zip(inp['input'],results)):
        if index:
            cns*=mp.power(2,-mp.mpf(interval)/90)
        result['initial']['oxygen']=dict(cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55))
        surface=mp.mpf(str(result['initial']['pressure_bar']))
        profile=dive['profile_codes']; depth=mp.mpf(str(profile[0]['ending_depth']))
        down=depth/mp.mpf(str(profile[0]['rate']));runtime=mp.mpf(str(profile[1]['run_time_at_end_of_segment']))
        gas=dive['gasmix_summary'][0];oxygen=mp.mpf(str(gas['fraction_O2']))
        def add(a,b,t):
            global cns,otu
            dc,do=exposure((surface+a/10)*oxygen/mp.mpf('1.01325'),(surface+b/10)*oxygen/mp.mpf('1.01325'),t)
            cns+=dc;otu+=do
        add(0,depth,down);add(depth,depth,runtime-down)
        previous=depth
        for segment in result['expected_segments']:
            oxygen=mp.mpf(str(dive['gasmix_summary'][segment['gas_index']]['fraction_O2']))
            end=mp.mpf(str(segment['end_depth_m']))
            add(previous,end,segment['duration_min'])
            segment['expected_oxygen']=dict(cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55))
            previous=end
        result['expected_oxygen']=dict(cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55))
    rows.append(dict(id=description,conservatism=2,request=inp,surface_interval_min=interval,dives=results))
output=dict(schema_version=1,provenance=dict(kind='independent-normalized-full-OC-altitude-repetitive-execution',
    repository='https://github.com/bwaite/vpmb',commit=PIN,source_sha256=hashlib.sha256(source.encode()).hexdigest(),
    policy_adapter='reference_vpm_schedule.py: same declared timing/max-first-stop/MP precision as normalized schedules; untouched primary altitude/repetitive routines.',
    oxygen='Independent mpmath quadrature of published Baker7band rates,90minute CNS recovery, OTU carried unchanged on SI.',
    command='local/oracles/python-env/bin/python tool/capture_vpm_sequences.py'),
    tolerances=dict(time_min=1e-7,tissue_bar=1e-8,gradient_bar=1e-8,radius_m=1e-15,phase_min=1e-7,cns=1e-12,otu=1e-10),
    cases=rows)
(FIX/'independent/vpmb-full-altitude-repetitive.json').write_text(json.dumps(output,indent=2,allow_nan=False)+'\n')
print('Captured independent full OC altitude/SI sequences:',[(r['id'],[d['expected_segments'][-1]['end_min'] for d in r['dives']]) for r in rows])
