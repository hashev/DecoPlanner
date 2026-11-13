"""Independent70-digit primitive checks from published VPM equations.
Uses mpmath bisection, not the Dart solver or legacy outputs. The separate
untouched bwaite oracle supplies realistic c0-c4 input configurations.
"""
import hashlib,json
from pathlib import Path
import mpmath as mp
mp.mp.dps=70
ROOT=Path(__file__).resolve().parents[1];FIX=ROOT/'packages/deco_core/test/fixtures'
inputs=json.loads((FIX/'independent/vpmb-physical-states.json').read_text())
coeff=json.loads((FIX/'independent/buhlmann-1b-parameters-and-ceilings.json').read_text())['models'][0]['tables']
M=lambda value:mp.mpf(str(value))
rows=[]
for case in inputs['cases']:
    request=case['request'];settings=request['settings'];mix=request['input'][0]['gasmix_summary'][0]
    n2f=M(mix['fraction_N2']);hef=M(mix['fraction_He'])
    surface=M(1);vapour=M('.0493');rate=M('2.3');depth=M(case['depth_m']);dt=depth/23
    onset=M('8.2')*M('1.01325');gamma=M('.0179');gc=M('.257');other=M(102)/760*M('1.01325')
    tau=M(20160);diveTime=M(30);decay=mp.exp(-diveTime/tau)
    nRadius=M(settings['Critical_Radius_N2_Microns'])*M('1e-6')
    heRadius=M(settings['Critical_Radius_He_Microns'])*M('1e-6')
    result={key:[] for key in ['maxCrushingPressureNitrogenBar','maxCrushingPressureHeliumBar',
        'ambientOnsetBar','tensionOnsetBar','regeneratedRadiusNitrogenMetres','regeneratedRadiusHeliumMetres',
        'adjustedCrushingPressureNitrogenBar','adjustedCrushingPressureHeliumBar',
        'initialAllowableGradientNitrogenBar','initialAllowableGradientHeliumBar']}
    for i in range(16):
        kn=mp.log(2)/M(coeff['n2_half'][i]);kh=mp.log(2)/M(coeff['he_half'][i])
        def tissue(t,f,k,initial):
            pi=(surface-vapour)*f;r=rate*f
            return pi+r*(t-1/k)-(pi-initial-r/k)*mp.exp(-k*t)
        def tension(t):return tissue(t,n2f,kn,(surface-vapour)*M('.79'))+tissue(t,hef,kh,0)+other
        grad=surface+rate*dt-tension(dt);amb=M(0);ten=M(0)
        if grad>onset:
            time=mp.findroot(lambda t:surface+rate*t-tension(t)-onset,(0,dt),solver='bisect',tol=M('1e-55'),maxsteps=300)
            amb=surface+rate*time;ten=tension(time)
        result['ambientOnsetBar'].append(amb);result['tensionOnsetBar'].append(ten)
        for label,r0 in [('Nitrogen',nRadius),('Helium',heRadius)]:
            crush=grad
            if grad>onset:
                ron=1/(onset*100000/(2*(gc-gamma))+1/r0)
                diff=(surface+rate*dt-amb)*100000;tp=ten*100000
                a=diff+tp+2*(gc-gamma)/ron;beta=2*(gc-gamma)/(a*ron);delta=tp/a
                x=mp.findroot(lambda x:x**3-beta*x*x-delta,(beta,1),solver='bisect',tol=M('1e-55'),maxsteps=300)
                crush=(onset*100000+diff+tp*(1-x**-3))/100000
            crush=max(0,crush)
            rc=1/(crush*100000/(2*(gc-gamma))+1/r0)
            rr=r0+(rc-r0)*decay
            adjusted=crush*(rc/rr)*decay
            gradient=2*gamma*(gc-gamma)/(rr*gc)/100000
            for key,value in [(f'maxCrushingPressure{label}Bar',crush),
                (f'regeneratedRadius{label}Metres',rr),(f'adjustedCrushingPressure{label}Bar',adjusted),
                (f'initialAllowableGradient{label}Bar',gradient)]:result[key].append(value)
    rows.append(dict(conservatism=case['conservatism'],depth_m=case['depth_m'],
                     expected={k:[mp.nstr(v,60) for v in values] for k,values in result.items()}))
result=dict(schema_version=1,provenance=dict(kind='independent-high-precision-equation-solve',solver='mpmath '+mp.__version__,precision_decimal_digits=70,
    primary_model='https://github.com/bwaite/vpmb/blob/bec938d84742e42dd43b574beec49ac26f6863ac/vpmb.py',
    input_fixture_sha256=hashlib.sha256((FIX/'independent/vpmb-physical-states.json').read_bytes()).hexdigest(),
    command='local/oracles/python-env/bin/python tool/capture_vpm_high_precision.py'),
    tolerances=dict(pressure_bar=1e-8,radius_metres=1e-15),cases=rows)
(FIX/'independent/vpmb-physical-high-precision.json').write_text(json.dumps(result,indent=2)+'\n')
print('Captured6 high-precision VPM primitive cases including impermeability onset/cubic roots')
