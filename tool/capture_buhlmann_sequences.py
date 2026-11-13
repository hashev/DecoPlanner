"""Independent B/C altitude/SI schedules, ODE recovery and Baker quadrature.

No product output is read. Barometric pressure comes from the pinned external
US1976 implementation; air recovery uses external DecoTengu. Non-acclimatized
air travel is integrated independently at high precision.
"""
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import mpmath as mp
import decotengu.model as dm
from capture_buhlmann_oc_schedules import ROOT, FIX, normalized, reference as oc_reference
from capture_buhlmann_bailout import reference as breathing_reference, model_for
from reference_vpm_schedule import module as primary, PIN, source as atmosphere_source
from reference_oxygen_quadrature import dose

mp.mp.dps = 55
SEA, VAPOUR = 1.01325, .0627
GASES = [[21, .5, 0], [6, 1., 0]]


def altitude_state(letter, height, acclimatized, travel, wait):
    surface = primary.calc_barometric_pressure(height, False) * .1 * SEA
    model = model_for(letter)
    if acclimatized:
        return surface, [(.79*(surface-VAPOUR), 0.)]*16
    old = mp.mpf('.79') * (mp.mpf(str(SEA))-mp.mpf(str(VAPOUR)))
    initial = []
    for half in model.N2_HALF_LIFE:
        k = mp.log(2)/mp.mpf(str(half))
        t = mp.mpf(travel)
        def forcing(u):
            ambient = mp.mpf(str(SEA)) + (mp.mpf(str(surface))-mp.mpf(str(SEA)))*u/t
            return k*mp.mpf('.79')*(ambient-mp.mpf(str(VAPOUR)))*mp.exp(-k*(t-u))
        final = old*mp.exp(-k*t)+mp.quad(forcing, [0, t])
        equilibrium = mp.mpf('.79')*(mp.mpf(str(surface))-mp.mpf(str(VAPOUR)))
        final = equilibrium+(final-equilibrium)*mp.exp(-k*wait)
        initial.append((float(final), 0.))
    return surface, initial


def run(letter, mode, surface, initial, oxygen):
    if mode == 'oc':
        request = dict(id='oc', model=letter.lower(), levels=[[45, 25, 21, 35, 0]],
                       deco=[[21, 50, 0], [6, 100, 0]])
        context = normalized(dict(request=request))
        context['surface_bar'] = surface
        result = oc_reference(request, context, initial_tissues=initial)
        for seg in result['segments']:
            oxygen = [a+b for a,b in zip(oxygen, dose(seg['start_depth_m'], seg['end_depth_m'],
                seg['duration_min'], [seg['oxygen'], seg['helium']], surface_bar=surface))]
            seg['cns_fraction'], seg['otu'] = map(float, oxygen)
            seg['setpoint_bar'] = None
        return result
    switches = [[21, .18, .45, 1.4], [6, .21, .35, .7]] if mode == 'ccr' else GASES
    result = breathing_reference(letter, 25., switches, ccr=mode == 'ccr',
        surface=surface, vapour=VAPOUR, initial_tissues=initial, initial_oxygen=oxygen)
    segments = []
    start_time = 0.
    for i, seg in enumerate(result['prefix']):
        duration = seg['duration_min']
        segments.append(dict(start_min=start_time, start_depth_m=seg['start_depth_m'],
            end_depth_m=seg['end_depth_m'], duration_min=duration,
            phase='levelTravel' if i == 0 else 'levelHold', oxygen=.21, helium=.35,
            setpoint_bar=.7 if i == 0 else 1.3,
            n2_bar=seg['n2'], he_bar=seg['he'], cns_fraction=seg['cns_fraction'], otu=seg['otu']))
        start_time += duration
    for seg in result['expected']['segments']:
        segments.append(dict(**{k:v for k,v in seg.items() if k not in ['o2', 'he']},
            oxygen=seg['o2'], helium=seg['he']))
    return dict(runtime_min=result['expected']['runtime_min'], segments=segments)


cases = []
for letter in ['B', 'C']:
    for mode in ['oc', 'ccr', 'bailout']:
        for height, acclimatized, travel, wait in [(2000, True, 0, 0), (2000, False, 180, 120), (8848, False, 120, 30)]:
            surface, initial = altitude_state(letter, height, acclimatized, travel, wait)
            result = run(letter, mode, surface, initial, [mp.mpf(0), mp.mpf(0)])
            cases.append(dict(id=f'{letter}-{mode}-alt{height}-'+('acclimatized' if acclimatized else 'travel'),
                model=letter, modes=[mode], altitude=dict(height_m=height, acclimatized=acclimatized,
                    travel_min=travel, wait_min=wait), surface_bar=surface, surface_interval_min=None,
                dives=[dict(initial_tissues=initial, initial_oxygen=[0., 0.], expected=result)]))
            print(cases[-1]['id'], result['runtime_min'], flush=True)
    for modes in [('oc', 'oc'), ('ccr', 'ccr'), ('ccr', 'oc'), ('ccr', 'bailout'), ('bailout', 'ccr')]:
        for interval in [0, 45, 60, 180, 1440]:
            initial = [(.79*(SEA-VAPOUR), 0.)]*16
            oxygen = [mp.mpf(0), mp.mpf(0)]
            dives = []
            model = model_for(letter)
            for i, mode in enumerate(modes):
                if i:
                    data = dm.Data(tuple(initial), .3)
                    if interval:
                        data = model.load(SEA, interval, SimpleNamespace(n2=79, he=0), 0, data)
                    initial = list(data.tissues)
                    oxygen[0] *= mp.power(2, -mp.mpf(interval)/90)
                result = run(letter, mode, SEA, initial, oxygen)
                dives.append(dict(initial_tissues=initial, initial_oxygen=list(map(float, oxygen)), expected=result))
                last = result['segments'][-1]
                initial = list(zip(last['n2_bar'], last['he_bar']))
                oxygen = [mp.mpf(str(last['cns_fraction'])), mp.mpf(str(last['otu']))]
            cases.append(dict(id=f'{letter}-{modes[0]}-to-{modes[1]}-si{interval}', model=letter,
                modes=modes, altitude=None, surface_bar=SEA, surface_interval_min=interval, dives=dives))
            print(cases[-1]['id'], [d['expected']['runtime_min'] for d in dives], flush=True)

out = dict(schema_version=1, provenance=dict(
    kind='independent-normalized-B-C-altitude-SI-full-schedules',
    model_source_sha256=hashlib.sha256(Path(dm.__file__).read_bytes()).hexdigest(),
    atmosphere_source_commit=PIN,
    atmosphere_source_sha256=hashlib.sha256(atmosphere_source.encode()).hexdigest(),
    generator_sha256=hashlib.sha256((ROOT/'tool/capture_buhlmann_sequences.py').read_bytes()).hexdigest(),
    adapters_sha256={name:hashlib.sha256((ROOT/'tool'/name).read_bytes()).hexdigest() for name in
        ['capture_buhlmann_oc_schedules.py', 'capture_buhlmann_bailout.py', 'reference_oxygen_quadrature.py']},
    command='local/oracles/python-env/bin/python tool/capture_buhlmann_sequences.py'),
    scope='Complete OC/CCR/bailout profiles, altitude initial states, air-travel quadrature and SI tissue/oxygen carry. Standard1.3/1.4/.7bar CCR, including dry-pressure clipping; C1b explicitly normalized. No Dart results observed.',
    tolerances=dict(tissue_bar=1e-10, time_min=1e-10, cns_fraction=1e-10, otu=1e-9), cases=cases)
(FIX/'independent/buhlmann-altitude-repetitive.json').write_text(json.dumps(out, indent=2, allow_nan=False)+'\n')
print('Captured', len(cases), 'independent full B/C altitude and SI cases')
