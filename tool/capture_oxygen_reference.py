"""Independent quadrature of Baker's published oxygen policy, before Dart gates.
The reference uses high-precision numerical integration, not the analytic
logarithmic/power integration implemented by the product.
"""
import hashlib
import json
from pathlib import Path
import mpmath as mp
mp.mp.dps=65
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'local/oracles/oxygen-sources/baker-oxygen.pdf'
BANDS=[('.5','.6',-1800,1800),('.6','.7',-1500,1620),('.7','.8',-1200,1410),
       ('.8','.9',-900,1170),('.9','1.1',-600,900),('1.1','1.5',-300,570),('1.5','1.6',-750,1245)]
bands=[(mp.mpf(a),mp.mpf(b),m,c) for a,b,m,c in BANDS]

def exposure(a,b,t):
    a,b,t=mp.mpf(a),mp.mpf(b),mp.mpf(t)
    assert 0<=a<=mp.mpf('1.6') and 0<=b<=mp.mpf('1.6')
    def cns_rate(p):
        if p<=mp.mpf('.5'):return mp.mpf(0)
        for lo,hi,m,c in bands:
            if lo<p<=hi:return 1/(m*p+c)
        raise ValueError(p)
    def otu_rate(p):return max(mp.mpf(0),2*(p-mp.mpf('.5')))**(mp.mpf(5)/6)
    if a==b:return t*cns_rate(a),t*otu_rate(a)
    lo,hi=sorted([a,b]);cuts=sorted(set([lo,hi]+[x for band in bands for x in band[:2] if lo<x<hi]))
    cns=mp.fsum(mp.quad(cns_rate,[u,v]) for u,v in zip(cuts,cuts[1:]))*t/(hi-lo)
    otu=mp.fsum(mp.quad(otu_rate,[u,v]) for u,v in zip(cuts,cuts[1:]))*t/(hi-lo)
    return cns,otu

def record(name,a,b,t):
    cns,otu=exposure(a,b,t)
    return dict(id=name,start_ata=str(a),end_ata=str(b),duration_min=str(t),
                cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55))
cases=[]
for i,(lo,hi,m,c) in enumerate(bands):
    for name,p in [('low',lo),('mid',(lo+hi)/2),('high',hi)]:
        cases.append(record(f'band{i+1}-{name}',p,p,10))
    cases.append(record(f'band{i+1}-movement',lo,hi,10))
    cases.append(record(f'band{i+1}-reverse',hi,lo,10))
for p in ['0','.5','.50000001','.59999999','.60000001','1.59999999']:
    cases.append(record('boundary-'+p,p,p,10))
cases.append(record('full-movement','.21','1.6',5))
cases.append(record('full-reverse','1.6','.21',5))
pmax=mp.mpf(153)/33*mp.mpf('.32')
worked=[record('baker-worked-descent','.32',pmax,3),record('baker-worked-hold',pmax,pmax,22),record('baker-worked-ascent',pmax,'.32',30)]
recovery=[dict(surface_interval_min=t,cns_from_one=mp.nstr(mp.power(2,-mp.mpf(t)/90),55),otu_from_100='100') for t in [0,45,60,180,1440]]
output=dict(schema_version=1,policy='baker-seven-bands-si90-v1',
    provenance=dict(kind='primary-policy-independent-quadrature',author='Erik C. Baker, P.E.',
        title='Oxygen Toxicity Calculations,12pages',source='https://cdn.shopify.com/s/files/1/0838/3732/1530/files/Oxygen_Toxicity_Calculations.pdf?v=1710181583',
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),solver='mpmath '+mp.__version__,precision_decimal_digits=65,
        command='local/oracles/python-env/bin/python tool/capture_oxygen_reference.py'),
    domain=dict(oxygen_ata=[0,1.6],zero_dose_at_or_below_ata=.5,coefficient_pages=[8],cns_recovery_half_time_min=90,
        otu_policy='Accumulated exposure dose, no unvalidated surface decay or24h reset; not a rolling daily limit'),
    bands=[dict(low_ata=a,high_ata=b,slope=m,intercept=c) for a,b,m,c in BANDS],
    tolerances=dict(cns_absolute=1e-12,otu_absolute=1e-10),cases=cases,worked_example_exact_depth=worked,recovery=recovery)
(ROOT/'packages/deco_core/test/fixtures/independent/oxygen-baker-mpmath.json').write_text(json.dumps(output,indent=2)+'\n')
print('Captured',len(cases),'band/boundary/movement cases,3worked segments,5SI cases')
print('Unrounded worked CNS:',mp.fsum(mp.mpf(r['cns_fraction']) for r in worked))
