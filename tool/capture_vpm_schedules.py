"""Capture corrected full OC VPM schedules and legacy diagnostic variants."""
import copy
import hashlib
import json
from reference_vpm_schedule import ROOT, FIX, PIN, source, run_reference

base = json.loads((FIX / 'independent/vpmb-physical-states.json').read_text())['cases'][:5]
rows = []
legacy_ids = [f'vpm-oc-c{c}' for c in range(5)] + ['vpm-oc-no-critical-volume', 'vpm-oc-lost-oxygen', 'vpm-oc-no-deco', 'last-stop-double-vpm']
for index in range(8 + len(legacy_ids) + 5):
    swapped = index >= 8 + len(legacy_ids)
    case = copy.deepcopy(base[index if index < 5 else 0])
    inp = case['request']
    dive = inp['input'][0]
    case_id = f'c{case["conservatism"]}-80m30'
    if index == 5:
        inp['settings']['Critical_Volume_Algorithm'] = 'OFF'
        case_id = 'c0-critical-volume-off'
    elif index == 6:
        case_id = 'c0-shallow-no-deco'
        dive['profile_codes'][0]['ending_depth'] = 6
        dive['profile_codes'][1].update(depth=6, run_time_at_end_of_segment=10)
        dive['profile_codes'][2]['ascent_summary'][0]['starting_depth'] = 6
        dive['gasmix_summary'][0].update(fraction_O2=.21, fraction_He=0, fraction_N2=.79)
    elif index == 7:
        case_id = 'c0-deco-gas-switches'
        dive['gasmix_summary'] += [dict(fraction_O2=.5, fraction_He=0, fraction_N2=.5),
                                    dict(fraction_O2=1, fraction_He=0, fraction_N2=0)]
        dive['num_gas_mixes'] = 3
        summary = dive['profile_codes'][2]
        summary['number_of_ascent_parameter_changes'] = 3
        summary['ascent_summary'] += [dict(starting_depth=21, gasmix=2, rate=-10, step_size=3),
                                      dict(starting_depth=6, gasmix=3, rate=-10, step_size=3)]
    sea_bar = 1.0
    baseline = None
    if index >= 8:
        legacy_id = legacy_ids[index-8 if not swapped else index-8-len(legacy_ids)]
        baseline_file = FIX / 'legacy_baseline' / (legacy_id+'.json')
        baseline = json.loads(baseline_file.read_text())
        request = baseline['request']
        conservatism = request.get('conservatism', 2)
        case = copy.deepcopy(base[conservatism])
        inp = case['request']; dive = inp['input'][0]
        case_id = legacy_id + ('-swapped-gradients-diagnostic' if swapped else '')
        sea_bar = 1.01325
        inp['settings']['Critical_Volume_Algorithm'] = 'OFF' if request.get('settings', {}).get('critical_volume') is False else 'ON'
        d, t, o, h, *_ = request['levels'][0]
        dive['gasmix_summary'] = [dict(fraction_O2=o/100, fraction_He=h/100, fraction_N2=1-(o/100+h/100))]
        dive['profile_codes'][0].update(ending_depth=d, rate=10)
        dive['profile_codes'][1].update(depth=d, run_time_at_end_of_segment=t)
        summary = dive['profile_codes'][2]
        summary['ascent_summary'] = [dict(starting_depth=d, gasmix=1, rate=-9, step_size=3)]
        for switch in request.get('deco', []):
            depth, oxygen, helium = switch[:3]
            dive['gasmix_summary'].append(dict(fraction_O2=oxygen/100, fraction_He=helium/100, fraction_N2=1-(oxygen/100+helium/100)))
            summary['ascent_summary'].append(dict(starting_depth=depth, gasmix=len(dive['gasmix_summary']), rate=-9, step_size=3))
        if request.get('settings', {}).get('last_stop_double'):
            summary['ascent_summary'].append(dict(starting_depth=6, gasmix=1, rate=-9, step_size=6))
        summary['number_of_ascent_parameter_changes'] = len(summary['ascent_summary'])
        dive['num_gas_mixes'] = len(dive['gasmix_summary'])
    observed = run_reference(inp, sea_bar=sea_bar, swapped=swapped)[-1]
    segments, bubble = observed['expected_segments'], observed['expected_bubble']
    rows.append(dict(id=case_id, conservatism=case['conservatism'], request=inp,
                     normalization=dict(surface_bar=sea_bar, vapour_bar=.0493, bar_per_metre=.1),
                     baseline_id=baseline['id'] if baseline else None,
                     diagnostic_swapped_gradients=swapped,
                     expected_segments=segments, expected_bubble=bubble))
result = dict(schema_version=1, provenance=dict(kind='independent-execution-normalized-policy-refined-roots',
    repository='https://github.com/bwaite/vpmb', commit=PIN,
    source_sha256=hashlib.sha256(source.encode()).hexdigest(),
    policy_normalization=['Minimum stop round argument +0.501, matches selected planner timing policy.',
                          'Boyle first-stop argument is maximum over trial iterations, selected planner policy.',
                          'Record surface actual gradient also on no-deco ascent; finalize repetitive excitation at SI0 before publishing the state.',
                          'Legacy replacement profiles explicitly calibrate surface pressure to1.01325bar and equilibrium N2 accordingly.'],
    numerical_refinement='mpmath70digit Boyle cubic and deco-zone roots; source equations remain independent of Dart.',
    command='local/oracles/python-env/bin/python tool/capture_vpm_schedules.py'),
    tolerances=dict(time_min=1e-7, tissue_bar=1e-8, gradient_bar=1e-8, radius_m=1e-15, phase_min=1e-7), cases=rows)
(FIX/'independent/vpmb-normalized-schedules.json').write_text(json.dumps(result, indent=2, allow_nan=False)+'\n')
print('Captured', [(r['id'], r['expected_segments'][-1]['end_min'], r['expected_bubble']['criticalVolumeIterations']) for r in rows])
