"""Independent CCR/bailout altitude and repetitive-state reference capture.

Runs pinned external VPM altitude/repetitive routines with the declared CCR
inspiration extension. Does not read or execute any Dart product output.
"""
import copy
import hashlib
import json
import mpmath as mp
from reference_vpm_schedule import ROOT, FIX, PIN, source, run_reference
from reference_oxygen_quadrature import dose

base = json.loads((FIX/'independent/vpmb-ccr-bailout-normalized.json').read_text())['cases']
templates = {mode: next(r for r in base if r['id'] == f'vpm-{mode}-c2') for mode in ['ccr', 'bailout']}


def prepare(mode):
    template = templates['ccr' if mode == 'ccr' else 'bailout']
    dive = copy.deepcopy(template['request']['input'][0])
    sp = list(template['setpoints_bar'])
    if mode == 'oc':
        sp = [None] * len(sp)
    return dive, sp


cases = []
for mode in ['ccr', 'bailout']:
    for height, acclimatized, travel, wait in [(2000, True, 0, 0), (2000, False, 180, 120), (8848, False, 120, 30)]:
        inp = copy.deepcopy(templates[mode]['request'])
        dive, sp = prepare(mode)
        # These altitude/state-overwrite references stay entirely inside the
        # external inspiration adapter's declared domain, including discarded
        # trial ascents. Standard1.3/1.4bar profiles are covered by the SI matrix.
        low = .2 if height == 8848 else .7
        sp = [low if value is not None else None for value in sp]
        inp['input'] = [dive]
        inp['settings']['Altitude_Dive_Algorithm'] = 'ON'
        inp['altitude'].update(Altitude_of_Dive=height,
            Diver_Acclimatized_at_Altitude='yes' if acclimatized else 'no',
            Starting_Acclimatized_Altitude=0, Ascent_to_Altitude_Hours=travel/60,
            Hours_at_Altitude_Before_Dive=wait/60)
        cases.append(dict(id=f'{mode}-altitude-{height}-'+('acclimatized' if acclimatized else 'travel'),
            modes=[mode], request=inp, setpoints_by_dive=[sp], surface_interval_min=None))

for first_mode, second_mode in [('ccr', 'ccr'), ('ccr', 'oc'), ('ccr', 'bailout'), ('bailout', 'ccr')]:
    for interval in [0, 45, 60, 180, 1440]:
        inp = copy.deepcopy(templates['ccr']['request'])
        first, first_sp = prepare(first_mode)
        second, second_sp = prepare(second_mode)
        first.update(repetitive_code=1, surface_interval_time_minutes=interval)
        inp['input'] = [first, second]
        cases.append(dict(id=f'{first_mode}-to-{second_mode}-si{interval}',
            modes=[first_mode, second_mode], request=inp,
            setpoints_by_dive=[first_sp, second_sp], surface_interval_min=interval))

for case in cases:
    inp = case['request']
    altitude = inp['settings']['Altitude_Dive_Algorithm'] == 'ON'
    results = run_reference(inp, sea_bar=None if altitude else 1.01325,
        ccr_setpoints_bar=case['setpoints_by_dive'])
    oxygen = [mp.mpf(0), mp.mpf(0)]
    for index, (dive, result, sp) in enumerate(zip(inp['input'], results, case['setpoints_by_dive'])):
        if index:
            oxygen[0] *= mp.power(2, -mp.mpf(case['surface_interval_min'])/90)
        result['initial']['oxygen'] = dict(cns_fraction=float(oxygen[0]), otu=float(oxygen[1]))
        surface = result['initial']['pressure_bar']
        last_time, last_depth = 0., 0.
        def expose(row, end_depth, duration, mix):
            gas = dive['gasmix_summary'][mix]
            increment = dose(last_depth, end_depth, duration,
                [gas['fraction_O2'], gas['fraction_He']], sp[mix], surface_bar=surface)
            oxygen[:] = [a+b for a, b in zip(oxygen, increment)]
            row['oxygen'] = dict(cns_fraction=float(oxygen[0]), otu=float(oxygen[1]))
        profiles = [p for p in dive['profile_codes'] if p['profile_code'] != 99]
        for row, profile in zip(result['expected_profile_segments'], profiles):
            end_depth = profile.get('ending_depth', profile.get('depth'))
            expose(row, end_depth, row['end_min']-last_time, profile['gasmix']-1)
            last_time, last_depth = row['end_min'], end_depth
        for row in result['expected_segments']:
            expose(row, row['end_depth_m'], row['duration_min'], row['gas_index'])
            last_time, last_depth = row['end_min'], row['end_depth_m']
    case['dives'] = results
    print(case['id'], [r['expected_segments'][-1]['end_min'] for r in results], flush=True)

out = dict(schema_version=1, provenance=dict(
    kind='independent-normalized-full-CCR-bailout-altitude-repetitive-execution',
    repository='https://github.com/bwaite/vpmb', commit=PIN,
    source_sha256=hashlib.sha256(source.encode()).hexdigest(),
    adapter_sha256=hashlib.sha256((ROOT/'tool/reference_vpm_schedule.py').read_bytes()).hexdigest(),
    oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),
    generator_sha256=hashlib.sha256((ROOT/'tool/capture_vpm_ccr_sequences.py').read_bytes()).hexdigest(),
    command='local/oracles/python-env/bin/python tool/capture_vpm_ccr_sequences.py'),
    scope='External VPM altitude/repetitive initialization and full schedules with explicit constant-SP inspiration extension and independent Baker quadrature. Altitude cases use SP.7bar at2000m and SP.2bar at8848m to keep every trial ascent inside the non-clipped adapter domain; SI cases use standard1.3/1.4/.7bar profiles. Clipping remains a separate kinetic reference. No Dart outputs observed.',
    tolerances=dict(time_min=1e-7, tissue_bar=1e-8, gradient_bar=1e-8, radius_m=1e-15, phase_min=1e-7, cns_fraction=1e-10, otu=1e-9), cases=cases)
(FIX/'independent/vpmb-ccr-altitude-repetitive.json').write_text(json.dumps(out, indent=2, allow_nan=False)+'\n')
print('Captured', len(cases), 'independent CCR/bailout altitude and SI sequences')
