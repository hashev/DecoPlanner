"""Independent normalized CCR-prefix/OC-escape reference, without Dart outputs.

CCR states use numerical convolution quadrature of the tissue ODE (mpmath).
OC loading and ceilings use external DecoTengu. Stop search enumerates every
physical grid candidate and every aligned dwell, rather than using its engine
or the product's projected-first-stop search. This is a policy-normalized
reference orchestration, not an untouched external full CCR planner.
"""
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
from types import SimpleNamespace

import decotengu.model as dm
import mpmath as mp
from reference_oxygen_quadrature import dose

mp.mp.dps = 55
ROOT = Path(__file__).resolve().parents[1]
SURFACE, VAPOUR = 1.01325, .0627


def model_for(letter):
    model = getattr(dm, 'ZH_L16' + letter + '_GF')()
    first = dm.ZH_L16B_GF()
    for attr in ['N2_HALF_LIFE', 'HE_HALF_LIFE', 'N2_A', 'N2_B', 'HE_A', 'HE_B']:
        setattr(model, attr, (getattr(first, attr)[0],) + getattr(model, attr)[1:])
    model.n2_k_const = model._k_const(model.N2_HALF_LIFE)
    model.he_k_const = model._k_const(model.HE_HALF_LIFE)
    model.START_P_N2 = .79
    model.water_vapour_pressure = VAPOUR
    return model


def ccr_load(model, state, start, end, duration, gas, sp, *, surface=SURFACE, vapour=VAPOUR):
    t, a, b, oxygen, helium, sp = map(mp.mpf, map(str, [
        duration, surface + start / 10, surface + end / 10,
        gas[0], gas[1], sp]))
    ratios = [(1 - oxygen - helium) / (1 - oxygen), helium / (1 - oxygen)]
    cuts = [mp.mpf(0), t]
    if a != b:
        kink = t * (sp + mp.mpf(str(vapour)) - a) / (b - a)
        if 0 < kink < t:
            cuts.insert(1, kink)
    tissues = []
    for i, old in enumerate(state.tissues):
        row = []
        for j, half in enumerate([model.N2_HALF_LIFE[i], model.HE_HALF_LIFE[i]]):
            k = mp.log(2) / mp.mpf(str(half))
            def integrand(u):
                inspired = max(mp.mpf(0), a + (b - a) * u / t - mp.mpf(str(vapour)) - sp)
                return k * ratios[j] * inspired * mp.exp(-k * (t - u))
            row.append(float(mp.mpf(str(old[j])) * mp.exp(-k * t) + mp.quad(integrand, cuts)))
        tissues.append(tuple(row))
    return dm.Data(tuple(tissues), .3)


def reference(letter, point, switches, changed=False, ccr=False, *, surface=SURFACE, vapour=VAPOUR, initial_tissues=None, initial_oxygen=(0, 0)):
    model = model_for(letter)
    model.water_vapour_pressure = vapour
    state = model.init(surface) if initial_tissues is None else dm.Data(tuple(map(tuple, initial_tissues)), .3)
    gas = [.21, .35]
    stages = [(0, 45, 4.5, gas, .7), (45, 45, 20.5, gas, 1.3)]
    if changed:
        stages.append((45, 45, 10, [.18, .45], 1.4))
    time, depth = 0., 0.
    prefix = []
    oxygen = [mp.mpf(str(v)) for v in initial_oxygen]
    for start, end, duration, diluent, sp in stages:
        dt = min(duration, point - time)
        if dt <= 0:
            break
        depth = start + (end - start) * dt / duration
        state = ccr_load(model, state, start, depth, dt, diluent, sp, surface=surface, vapour=vapour)
        oxygen = [a+b for a, b in zip(oxygen, dose(start, depth, dt, diluent, sp, surface_bar=surface))]
        time += dt
        prefix.append(dict(start_depth_m=start, end_depth_m=depth, duration_min=dt,
                           n2=[p[0] for p in state.tissues], he=[p[1] for p in state.tissues],
                           cns_fraction=float(oxygen[0]), otu=float(oxygen[1])))
        if time >= point:
            break
    assert time == point
    initial_oc = [.21, .35]
    active = ([.18, .45, 1.4] if changed else [.21, .35, 1.3]) if ccr else initial_oc
    segments = []

    def load(s, start, end, dt, mixture):
        if dt == 0:
            return s
        if len(mixture) == 3:
            return ccr_load(model, s, start, end, dt, mixture[:2], mixture[2], surface=surface, vapour=vapour)
        g = SimpleNamespace(n2=100 * (1 - mixture[0] - mixture[1]), he=100 * mixture[1])
        return model.load(surface + start / 10, dt, g, (end - start) / 10 / dt, s)

    def safe(s, d, gf):
        return max(model.gf_limit(gf, s)) <= surface + d / 10

    def append(target, dt, phase):
        nonlocal state, time, depth, oxygen
        state = load(state, depth, target, dt, active)
        oxygen = [a+b for a, b in zip(oxygen, dose(depth, target, dt, active[:2], active[2] if len(active) == 3 else None, surface_bar=surface))]
        segments.append(dict(start_min=time, start_depth_m=depth, end_depth_m=target,
                             duration_min=dt, phase=phase, o2=active[0], he=active[1],
                             setpoint_bar=active[2] if len(active) == 3 else None,
                             cns_fraction=float(oxygen[0]), otu=float(oxygen[1]),
                             n2_bar=[p[0] for p in state.tissues], he_bar=[p[1] for p in state.tissues]))
        depth, time = target, time + dt

    def select():
        nonlocal active
        available = [s for s in switches if s[0] >= depth]
        if available:
            active = min(available, key=lambda s: s[0])[1:]

    select()
    candidates = [0] + list(range(3, int(depth) + 1, 3))
    first = next(d for d in candidates if safe(load(state, depth, d, (depth-d)/9, active), d, .3))
    stop = first
    while depth > 0:
        boundaries = [s[0] for s in switches if stop < s[0] < depth]
        target = max([stop] + boundaries)
        if target < depth:
            append(target, (depth-target)/9, 'ascent')
        select()
        if depth == 0:
            break
        if depth > stop:
            continue
        next_stop = max(0, depth - 3)
        next_stop = max([next_stop] + [s[0] for s in switches if next_stop < s[0] < depth])
        gf = .85 + (.3 - .85) * next_stop / first if first else .85
        # Enumerate absolute integer departure times, preserving unrounded travel.
        departure = math.floor(time) + 1
        while not safe(load(state, depth, depth, departure-time, active), next_stop, gf):
            departure += 1
            assert departure < 2000
        append(depth, departure-time, 'decompression')
        stop = next_stop
    return dict(model=letter, mode='ccr' if ccr else 'bailout', runtime_point_min=point, changed_diluent=changed,
                initial_oc=initial_oc, switches=switches, prefix=prefix,
                expected=dict(first_stop_m=first, runtime_min=time, segments=segments))


def main():
    cases = []
    for letter in ['B', 'C']:
        for point in [2.25, 4.5, 12.5, 25.]:
            cases.append(reference(letter, point, [[21, .5, 0], [6, 1., 0]]))
        cases.append(reference(letter, 25., []))
        cases.append(reference(letter, 35., [[21, .5, 0], [6, 1., 0]], changed=True))
        cases.append(reference(letter, 25., [], ccr=True))
        cases.append(reference(letter, 25., [[21, .18, .45, 1.4], [6, .21, .35, .7]], ccr=True))
        cases.append(reference(letter, 35., [[21, .18, .45, 1.4], [6, .21, .35, .7]], changed=True, ccr=True))
    out = dict(schema_version=1,
               provenance=dict(kind='normalized-independent-CCR-quadrature-and-OC-stop-enumeration',
                               decotengu_version=importlib.metadata.version('decotengu'),
                               model_source_sha256=hashlib.sha256(Path(dm.__file__).read_bytes()).hexdigest(),
                               oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),
                               generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                               mpmath_version=mp.__version__, precision_decimal_digits=55,
                               command='local/oracles/python-env/bin/python tool/capture_buhlmann_bailout.py'),
               normalization='B/C compartment1b; surface1.01325bar/vapour.0627bar/N2.79; GF30/85; grid3m; ascent9m/min; aligned1min dwell; lowSP.7bar then1.3bar; instantaneous switch without delay',
               scope='Complete normalized CCR ascent and OC escape search with all segment tissues and independent Baker oxygen quadrature; CCR by high precision ODE convolution. No source-native full CCR schedule, altitude, SI or VPM validation claimed.',
               tolerances=dict(tissue_bar=1e-10, time_min=1e-10, cns_fraction=1e-10, otu=1e-9), cases=cases)
    path = ROOT / 'packages/deco_core/test/fixtures/independent/buhlmann-bailout-normalized.json'
    path.write_text(json.dumps(out, indent=2, allow_nan=False) + '\n')
    print('Captured', len(cases), 'independent normalized bailout profiles')


if __name__ == "__main__":
    main()
