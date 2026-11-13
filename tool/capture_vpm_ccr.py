"""Independent VPM source execution with explicit constant-SP inspiration adapter.

References are captured before comparison with Dart. The oracle's original VPM
equations and iterative search execute in a private checkout; no product output
is read. Profiles avoid dry-pressure clipping, which this adapter rejects.
"""
import copy
import hashlib
import json
from pathlib import Path
from reference_vpm_schedule import ROOT, FIX, PIN, source, run_reference
from reference_oxygen_quadrature import dose
import mpmath as mp

base = json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases']
rows = []
for conservatism in range(5):
    for variant in ['ccr', 'ccr-no-switch', 'bailout', 'bailout-descent', 'bailout-boundary', 'bailout-hold']:
        mode = 'ccr' if variant.startswith('ccr') else 'bailout'
        point = {'bailout-descent': 2.25, 'bailout-boundary': 4.5, 'bailout-hold': 12.5}.get(variant, 25.)
        depth = min(45, point*10)
        inp = copy.deepcopy(base[conservatism]['request'])
        dive = inp['input'][0]
        gas = dict(fraction_O2=.21, fraction_He=.35, fraction_N2=.44)
        dive['gasmix_summary'] = [gas.copy(), gas.copy(), gas.copy(),
            dict(fraction_O2=.18 if mode == 'ccr' else .5,
                 fraction_He=.45 if mode == 'ccr' else 0,
                 fraction_N2=.37 if mode == 'ccr' else .5),
            dict(fraction_O2=.21 if mode == 'ccr' else 1,
                 fraction_He=.35 if mode == 'ccr' else 0,
                 fraction_N2=.44 if mode == 'ccr' else 0)]
        dive['num_gas_mixes'] = 5
        dive['profile_codes'][0].update(ending_depth=depth, rate=10, gasmix=1)
        dive['profile_codes'][1].update(depth=depth, run_time_at_end_of_segment=point, gasmix=2)
        summary = dive['profile_codes'][2]
        summary['ascent_summary'] = [dict(starting_depth=depth, gasmix=3, rate=-9, step_size=3),
            dict(starting_depth=21, gasmix=4, rate=-9, step_size=3),
            dict(starting_depth=6, gasmix=5, rate=-9, step_size=3)]
        summary['number_of_ascent_parameter_changes'] = 3
        setpoints = [.7, 1.3, 1.3 if mode == 'ccr' else None,
                     1.4 if mode == 'ccr' else None, .7 if mode == 'ccr' else None]
        if variant == 'ccr-no-switch':
            setpoints = [.7, .7, .7, .7, .7]
            summary['ascent_summary'] = summary['ascent_summary'][:1]
            summary['number_of_ascent_parameter_changes'] = 1
        if point <= 4.5:
            dive['profile_codes'].pop(1)
        observed = run_reference(inp, sea_bar=1.01325, ccr_setpoints_bar=setpoints)[-1]
        oxygen = [mp.mpf(0), mp.mpf(0)]
        last_time, last_depth = 0., 0.
        profiles = [p for p in dive['profile_codes'] if p['profile_code'] != 99]
        def expose(row, end_depth, duration, index):
            gas = dive['gasmix_summary'][index]
            increment = dose(last_depth, end_depth, duration,
                [gas['fraction_O2'], gas['fraction_He']], setpoints[index])
            oxygen[:] = [a+b for a, b in zip(oxygen, increment)]
            row.update(oxygen=dict(cns_fraction=float(oxygen[0]), otu=float(oxygen[1])))
        for row, profile in zip(observed['expected_profile_segments'], profiles):
            end_depth = profile.get('ending_depth', profile.get('depth'))
            expose(row, end_depth, row['end_min']-last_time, profile['gasmix']-1)
            last_time, last_depth = row['end_min'], end_depth
        for row in observed['expected_segments']:
            expose(row, row['end_depth_m'], row['duration_min'], row['gas_index'])
            last_time, last_depth = row['end_min'], row['end_depth_m']
        rows.append(dict(id=f'vpm-{variant}-c{conservatism}', mode=mode,
            runtime_point_min=point, no_switches=variant == 'ccr-no-switch',
            conservatism=conservatism, request=inp, setpoints_bar=setpoints,
            normalization=dict(surface_bar=1.01325, vapour_bar=.0493, bar_per_metre=.1),
            **observed))
out = dict(schema_version=1, provenance=dict(
    kind='independent-VPM-execution-with-explicit-CCR-inspiration-extension',
    repository='https://github.com/bwaite/vpmb', commit=PIN,
    original_source_sha256=hashlib.sha256(source.encode()).hexdigest(),
    adapter_sha256=hashlib.sha256((ROOT/'tool/reference_vpm_schedule.py').read_bytes()).hexdigest(),
    oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),
    generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    command='local/oracles/python-env/bin/python tool/capture_vpm_ccr.py'),
    scope='Full VPM gradient/crushing/regeneration/CV/Boyle/search remains external; explicit CCR inspired pressure extension, not upstream-native CCR support. Crossing dry ambient=SP is rejected by this adapter. Existing stop alignment/Boyle/root normalization applies.',
    tolerances=dict(time_min=1e-7, tissue_bar=1e-8, gradient_bar=1e-8, radius_m=1e-15, phase_min=1e-7, cns_fraction=1e-10, otu=1e-9), cases=rows)
(FIX/'independent/vpmb-ccr-bailout-normalized.json').write_text(json.dumps(out, indent=2, allow_nan=False)+'\n')
print('Captured', [(r['id'], r['expected_segments'][-1]['end_min']) for r in rows])
