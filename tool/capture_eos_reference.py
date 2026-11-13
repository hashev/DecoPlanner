"""High-precision independent root solving of the declared vdW equation.
Only optional private mpmath is used; no numerical implementation enters Dart.
"""
import hashlib
import json
from pathlib import Path
import mpmath as mp
mp.mp.dps=70
ROOT=Path(__file__).resolve().parents[1]
rows=[]
for o,h in [('.21','0'),('.32','0'),('.18','.45'),('1','0'),('0','1')]:
    f=[mp.mpf(o),1-mp.mpf(o)-mp.mpf(h),mp.mpf(h)]
    a=sum(fi*mp.sqrt(mp.mpf(ai)) for fi,ai in zip(f,['1.382','1.37','.0346']))**2
    b=sum(fi*mp.mpf(bi) for fi,bi in zip(f,['.03186','.0387','.0238']))
    rt=mp.mpf('.083145')*294
    for p in [1,6.89,50,200,300]:
        pressure=mp.mpf(p)
        n=mp.findroot(lambda n:rt*n/(1-b*n)-a*n*n-pressure,
                      (pressure/rt,pressure/rt*mp.mpf('1.1')))
        assert abs(rt*n/(1-b*n)-a*n*n-pressure)<mp.mpf('1e-50')
        rows.append(dict(oxygen=float(o),helium=float(h),temperature_kelvin=294,
                         pressure_bar=p,moles_per_litre=mp.nstr(n,60)))
source=Path(mp.__file__)
output=dict(schema_version=1,provenance=dict(kind='independent-high-precision-equation-solve',
    project='mpmath',version=mp.__version__,source='https://mpmath.org/doc/current/calculus/optimization.html',
    module_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),command='local/oracles/python-env/bin/python tool/capture_eos_reference.py'),
    equation='P=R*T*n/(1-b*n)-a*n^2; a=(sum f*sqrt(ai))^2; b=sum f*bi',
    constants=dict(r_litre_bar_mol_kelvin='.083145',a=['1.382','1.37','.0346'],b=['.03186','.0387','.0238']),
    scope='Independent root solver for declared model; not experimental validation of gas physics',
    tolerance_moles_per_litre=1e-8,cases=rows)
(ROOT/'packages/deco_core/test/fixtures/independent/vdw-mpmath.json').write_text(json.dumps(output,indent=2)+'\n')
print('Captured25 high-precision EOS roots without reading Dart output')
