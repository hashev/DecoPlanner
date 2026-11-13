"""Independent HiGHS LP with explicit prefill/stream variables and three balances.
No Dart outputs, legacy answers, or production allocation implementation are read.
"""
import hashlib
import inspect
import json
from pathlib import Path
import numpy as np
import scipy
from scipy.optimize import linprog
import scipy.optimize._highspy._core as highs_core
import mpmath as mp

ROOT = Path(__file__).resolve().parents[1]
mp.mp.dps = 70
RT = mp.mpf('.083145') * 294

def density(pressure, gas, real):
    if not pressure:
        return mp.mpf(0)
    if not real:
        return mp.mpf(str(pressure)) / RT
    o, h = map(lambda x: mp.mpf(str(x)), gas)
    fs = [o, 1-o-h, h]
    a = sum(f*mp.sqrt(mp.mpf(c)) for f, c in zip(fs, ['1.382','1.37','.0346']))**2
    b = sum(f*mp.mpf(c) for f, c in zip(fs, ['.03186','.0387','.0238']))
    p = mp.mpf(str(pressure))
    return mp.findroot(lambda n: RT*n/(1-b*n)-a*n*n-p, (p/RT, p/RT*mp.mpf('1.1')))

def reference(req):
    initial, target = req['initial'], req['target']
    target_n = density(req['target_bar'], target, req['real'])
    start_n = density(req['initial_bar'], initial, req['real'])
    max_o, max_h = req['limits']
    variant, path = req['variant'], req['path']
    # Every stream has explicit source amounts, unlike production's eliminated balances.
    families = [['oxygen','helium','air']] if variant == 'singleStream' else (
        [['oxygen','helium'], ['oxygen','air']] if path == 'oxygenHeliumThenNitrox'
        else [['oxygen','air'], ['helium','air']])
    columns = [('retained',None), ('oxygen',None), ('helium',None)]
    for stage, family in enumerate(families):
        columns.extend((component,stage) for component in family)
    size = len(columns)
    component = {'oxygen': [1.,0.,0.], 'helium': [0.,1.,0.], 'air':[.21,0.,.79],
        'retained':[initial[0], initial[1], 1-initial[0]-initial[1]]}
    eq = np.array([component[c] for c,_ in columns]).T.tolist()
    rhs = [target[0], target[1], 1-target[0]-target[1]]
    ub, bounds = [], [(0.,float(start_n/target_n))] + [(0.,None)]*(size-1)
    for stage in range(len(families)):
        for species, cap in [(0,max_o),(1,max_h)]:
            ub.append([component[c][species]-cap if s == stage else 0. for c,s in columns])
    objectives = [[1.]+[0.]*(size-1),
        [float(s is not None) for _,s in columns],
        [float(s == 0) for _,s in columns],
        [float(c == 'oxygen' and s == 0) for c,s in columns]]
    x = None
    for objective in objectives:
        result = linprog(-np.array(objective), A_ub=ub, b_ub=np.zeros(len(ub)),
            A_eq=eq, b_eq=rhs, bounds=bounds, method='highs-ds',
            options={'primal_feasibility_tolerance':1e-9,'dual_feasibility_tolerance':1e-9})
        if not result.success:
            assert result.status == 2, result.message
            return {'failure': 'impossibleMixture'}
        x = result.x
        eq.append(objective)
        rhs.append(float(np.dot(objective,x)))
    assert max(abs(np.array(eq)@x-np.array(rhs))) < 1e-8
    streams = []
    for stage in range(len(families)):
        amounts = {c: sum(float(x[i]) for i,(name,s) in enumerate(columns) if name == c and s == stage)
            for c in ['oxygen','helium','air']}
        total = sum(amounts.values())
        if total > 1e-10:
            streams.append({'amount':total, 'oxygen':(amounts['oxygen']+.21*amounts['air'])/total,
                'helium':amounts['helium']/total,
                'source_fractions': {k:v/total for k,v in amounts.items()}})
    return {'target_moles_per_litre':float(target_n), 'retained':float(x[0]),
        'prefill_oxygen':float(x[1]),'prefill_helium':float(x[2]), 'streams':streams}


def main():
    cases = []
    profiles = [
        ('empty-trimix',[.21,0],0,[.21,.35],232),
        ('air-to-trimix-drain',[.21,0],200,[.18,.45],200),
        ('helium-drain-for-feed-limit',[0,1],120,[.21,.35],200),
        ('nitrox',[.21,0],50,[.5,0],200),
        ('hypoxic-impossible',[.21,0],0,[.1,0],200),
        ('heliox',[1,0],30,[.3,.7],200),
        ('pure-oxygen',[.21,0],0,[1,0],200),
        ('pure-helium',[.21,0],0,[0,1],200),
        ('identity',[.21,.35],200,[.21,.35],200),
    ]
    limits = [(1,1),(.4,.6),(.21,.35),(.19,.9),(0,0),(1,0),(.4,1),(.4,0),(.21,1)]
    for real in [False,True]:
        for variant, path in [('singleStream','oxygenHeliumThenNitrox'),
            ('twoStreams','oxygenHeliumThenNitrox'),('twoStreams','nitroxThenHeliair')]:
            for name,initial,pi,target,pt in profiles:
                for caps in limits:
                    req = dict(initial=initial, initial_bar=pi, target=target,
                        target_bar=pt, real=real, variant=variant,path=path,limits=caps)
                    cases.append(dict(id=f'{name}-{variant}-{path}-{caps}-{real}',
                        request=req, expected=reference(req)))
    provenance = dict(kind='independent-linear-programming', scipy=scipy.__version__,
        numpy=np.__version__, mpmath=mp.__version__,method='highs-ds',
        highs_version='.'.join(str(getattr(highs_core, 'HIGHS_VERSION_'+part)) for part in ['MAJOR','MINOR','PATCH']),
        highs_binary_sha256=hashlib.sha256(Path(highs_core.__file__).read_bytes()).hexdigest(),
        linprog_module_sha256=hashlib.sha256(Path(inspect.getfile(linprog)).read_bytes()).hexdigest(),
        generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        source='https://docs.scipy.org/doc/scipy/reference/optimize.linprog-highs-ds.html',
        command='local/oracles/python-env/bin/python tool/capture_continuous_reference.py')
    out = dict(schema_version=1, provenance=provenance,
        policy='Max retained gas; then continuous addition; then first stream; then added O2 in first stream.',
        normalized_amount_tolerance=2e-8, pressure_tolerance_bar=1e-7, cases=cases)
    dest=ROOT/'packages/deco_core/test/fixtures/independent/continuous-highs.json'
    dest.write_text(json.dumps(out,indent=2)+'\n')
    print(f'Captured {len(cases)} independent LP cases')

if __name__ == '__main__':
    main()
