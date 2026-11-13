"""Independent OC stop enumeration using external DecoTengu kinetics/ceilings.

Reads legacy inputs/context only, never observed schedules or Dart output.
Every physical first-stop node and aligned departure time is enumerated. This
normalizes planner timing/GF/switch policies, not an upstream-native planner.
"""
import copy
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
from types import SimpleNamespace
import decotengu.model as dm

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT/'packages/deco_core/test/fixtures'
NAMES = ['oc-air-30m-20min', 'oc-b-no-deco', 'oc-c-no-deco', 'oc-nitrox-18m-30min',
         'oc-b-gf100', 'oc-c-gf100', 'last-stop-double-b', 'minimum-stop-override-b',
         'oc-b-deco-switch', 'oc-c-deco-switch', 'oc-b-lost-oxygen', 'oc-c-lost-oxygen',
         'oc-b-multilevel', 'oc-c-multilevel', 'imperial-b-oc', 'imperial-c-oc']


def normalized(fixture):
    req = fixture['request']
    options = req.get('settings', {})
    native = fixture.get('normalization', {}) if req.get('units') == 'imperial' else {}
    return dict(surface_bar=native.get('surface_bar', 1.01325),
                vapour_bar=native.get('water_vapour_bar', .0627),
                initial_n2_bar=native.get('initial_n2_bar', (1.01325-.0627)*.79),
                bar_per_metre=native.get('bar_per_metre', .1),
                depth_factor=native.get('depth_to_metres', 1),
                descent_m_min=native.get('descent_m_min', 10),
                ascent_m_min=native.get('ascent_m_min', 9),
                step_m=native.get('step_m', 3),
                last_stop_m=native.get('step_m', 3)*(2 if options.get('last_stop_double') else 1),
                gf_low=native.get('gf_low', options.get('gf_low', .3)),
                gf_high=native.get('gf_high', options.get('gf_high', .85)),
                minimum_stop_min=options.get('minimum_stop_min', 1),
                include_descent=options.get('include_descent', True))


def reference(req, ctx, *, initial_tissues=None):
    model = getattr(dm, 'ZH_L16'+req['model'].upper()+'_GF')()
    first = dm.ZH_L16B_GF()
    for attr in ['N2_HALF_LIFE', 'HE_HALF_LIFE', 'N2_A', 'N2_B', 'HE_A', 'HE_B']:
        setattr(model, attr, (getattr(first, attr)[0],)+getattr(model, attr)[1:])
    model.n2_k_const = model._k_const(model.N2_HALF_LIFE)
    model.he_k_const = model._k_const(model.HE_HALF_LIFE)
    model.water_vapour_pressure = ctx['vapour_bar']
    state = dm.Data(tuple([(ctx['initial_n2_bar'], 0)]*16) if initial_tissues is None else tuple(map(tuple, initial_tissues)), ctx['gf_low'])
    depth, time, anchor, maximum, ascent, deco = 0., 0., 0., 0., 0., 0.
    gas = None
    selected = None
    segments = []
    switches = [dict(depth=row[0]*ctx['depth_factor'], gas=[row[1]/100, row[2]/100],
                     minimum=row[4] if len(row)>4 else ctx['minimum_stop_min'])
                for i, row in enumerate(req.get('deco', [])) if i not in req.get('lost_deco_indices', [])]

    def load(initial, start, end, duration):
        if duration == 0:
            return initial
        mixture = SimpleNamespace(n2=100*(1-(gas[0]+gas[1])), he=100*gas[1])
        return model.load(ctx['surface_bar']+start*ctx['bar_per_metre'], duration, mixture,
                          (end-start)*ctx['bar_per_metre']/duration, initial)

    def safe(initial, target, gf):
        return max(model.gf_limit(gf, initial)) <= ctx['surface_bar']+target*ctx['bar_per_metre']

    def append(target, minutes, phase):
        nonlocal state, depth, time, ascent, deco
        if minutes == 0:
            return
        state = load(state, depth, target, minutes)
        segments.append(dict(start_min=time, duration_min=minutes, start_depth_m=depth,
            end_depth_m=target, phase=phase, oxygen=gas[0], helium=gas[1],
            n2_bar=[p[0] for p in state.tissues], he_bar=[p[1] for p in state.tissues]))
        depth, time = target, time+minutes
        if phase in ['ascent', 'decompression']:
            ascent += minutes
        if phase == 'decompression':
            deco += minutes

    def same(a, b):
        return abs(a-b) <= 16*math.ulp(max(1, abs(a), abs(b)))

    def available(s):
        return selected is None or s['depth'] < selected['depth']

    def intercept(target):
        return max([target]+[s['depth'] for s in switches if target < s['depth'] < depth
                               and not same(s['depth'], target) and available(s)])

    def select():
        nonlocal selected, gas
        for s in switches:
            if (s['depth'] >= depth or same(s['depth'], depth)) and available(s):
                selected, gas = s, s['gas']

    def ascend_to(target):
        nonlocal anchor, maximum, deco
        nodes = [0]+[ctx['last_stop_m']+i*ctx['step_m'] for i in range(
            max(0, math.floor((depth-ctx['last_stop_m'])/ctx['step_m'])+1))]
        stop = max(target, next(d for d in nodes if safe(load(state, depth, d,
            (depth-d)/ctx['ascent_m_min']), d, ctx['gf_low'])))
        maximum = max(maximum, stop)
        if anchor == 0 and stop > target:
            anchor = stop
        reached = False
        while depth > target:
            next_depth = intercept(stop)
            if depth > next_depth:
                duration = (depth-next_depth)/ctx['ascent_m_min']
                append(next_depth, duration, 'ascent')
                if reached:
                    deco += duration
            select()
            if depth <= target:
                break
            if depth > stop:
                continue
            reached = True
            next_stop = 0 if depth <= ctx['last_stop_m'] else max(ctx['last_stop_m'], depth-ctx['step_m'])
            next_stop = intercept(max(target, next_stop))
            gf = ctx['gf_high'] if anchor == 0 else ctx['gf_high']+(ctx['gf_low']-ctx['gf_high'])*min(1, next_stop/anchor)
            minimum = selected['minimum'] if selected else ctx['minimum_stop_min']
            departure = math.floor(time)+minimum
            while departure <= time:
                departure += minimum
            while not safe(load(state, depth, depth, departure-time), next_stop, gf):
                departure += minimum
                assert departure < 10000, 'Reference departure enumeration did not converge'
            append(depth, departure-time, 'decompression')
            stop = next_stop

    for row in req['levels']:
        target, duration, o, h = row[:4]
        target *= ctx['depth_factor']
        if target < depth:
            ascend_to(target)
            gas = [o/100, h/100]
            append(depth, duration+math.ceil(time)-time, 'levelHold')
        elif target > depth:
            selected, anchor, gas = None, 0., [o/100, h/100]
            down = (target-depth)/ctx['descent_m_min']
            append(target, down, 'levelTravel')
            hold = duration-down if ctx['include_descent'] else duration
            assert hold >= 0
            append(target, hold, 'levelHold')
        else:
            gas = [o/100, h/100]
            append(depth, duration, 'levelHold')
    ascend_to(0)
    return dict(segments=segments, runtime_min=time, ascent_min=ascent,
                decompression_min=deco, first_stop_m=maximum)


def main():
    rows = []
    for name in NAMES:
        path = FIX/'legacy_baseline'/(name+'.json')
        fixture = json.loads(path.read_text())
        request, context = fixture['request'], normalized(fixture)
        rows.append(dict(id=name, request=request, normalization=context,
            source_input_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            expected=reference(request, context)))
    for name, options, lost in [('explicit-lost-oxygen', {}, [1]),
                                ('descent-added', {'include_descent': False}, []),
                                ('half-minute-minimum', {'minimum_stop_min': .5}, [])]:
        request = copy.deepcopy(next(r['request'] for r in rows if r['id'] == 'oc-b-deco-switch'))
        request.update(id=name, settings=options, lost_deco_indices=lost)
        context = normalized(dict(request=request))
        rows.append(dict(id=name, request=request, normalization=context, expected=reference(request, context)))

    result = dict(schema_version=1, provenance=dict(
        kind='independent-normalized-OC-stop-enumeration-with-external-kinetics-and-ceilings',
        decotengu_version=importlib.metadata.version('decotengu'),
        model_source_sha256=hashlib.sha256(Path(dm.__file__).read_bytes()).hexdigest(),
        generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        command='local/oracles/python-env/bin/python tool/capture_buhlmann_oc_schedules.py'),
        scope='Complete stop search, travel/hold timing, gas selection, all segment tissues and duration metrics. Inputs/context only are read from legacy records. C normalized to1b. No Dart outputs, no observed schedules. Oxygen remains a separate quadrature reference.',
        tolerances=dict(tissue_bar=1e-10, time_min=1e-10), cases=rows)
    (FIX/'independent/buhlmann-oc-normalized-schedules.json').write_text(json.dumps(result, indent=2, allow_nan=False)+'\n')
    print('Captured', [(r['id'], r['expected']['runtime_min']) for r in rows])


if __name__ == "__main__":
    main()
