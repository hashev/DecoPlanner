"""Capture independent multilevel descending VPM profiles before Dart comparison.

Imperial inputs are converted exactly to canonical metres; the external source
runs MSW equations with a 10ft=3.048m physical grid, not its rounded FSW presets.
No product module or actual product output is read by this generator.
"""
import copy
import hashlib
import json
import subprocess
from pathlib import Path
import mpmath as mp
from reference_vpm_schedule import ROOT, FIX, PIN, source, run_reference
from reference_oxygen_quadrature import dose

assert source.encode() == subprocess.check_output(['git','-C',str(ROOT/'local/oracles/vpmb'),'show',f'{PIN}:vpmb.py'])
mp.mp.dps = 70
base = json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases'][:5]
rows = []
for c in range(5):
    for units in ['metric', 'imperial']:
        step = 3 if units == 'metric' else 3.048
        depths = [30, 45, 54, 60] if units == 'metric' else [100*.3048,150*.3048,180*.3048,200*.3048]
        for mode in ['oc', 'ccr', 'bailout']:
            inp = copy.deepcopy(base[c]['request'])
            dive = inp['input'][0]
            def mix(o, h): return dict(fraction_O2=o, fraction_He=h, fraction_N2=1-o-h)
            if mode == 'oc':
                gases = [mix(.18,.45), mix(.5,0), mix(.8,0)]
                sp = [None]*3
                initial, stop_gases = 1, [2,3]
            elif mode == 'ccr':
                gases = [mix(.18,.45),mix(.18,.45),mix(.21,.35),mix(.21,.35)]
                sp = [.7,1.3,1.4,.7]
                initial, stop_gases = 2,[3,4]
            else:
                gases = [mix(.18,.45),mix(.18,.45),mix(.18,.45),mix(.5,0),mix(.8,0)]
                sp = [.7,1.3,None,None,None]
                initial, stop_gases = 3,[4,5]
            dive['gasmix_summary'], dive['num_gas_mixes'] = gases, len(gases)
            profile = []
            previous, runtime = 0., 0.
            product_levels = []
            for depth, duration in zip(depths,[18,8,8,6]):
                descending = depth > previous
                rate = 10 if descending else -9
                movement = 1 if mode == 'oc' or descending else 2
                hold = 1 if mode == 'oc' else 2
                profile += [dict(profile_code=1, starting_depth=previous, ending_depth=depth, rate=rate, gasmix=movement)]
                runtime += duration
                profile += [dict(profile_code=2, depth=depth, run_time_at_end_of_segment=runtime, gasmix=hold)]
                product_levels.append(dict(depth_metres=depth,duration_min=duration))
                previous = depth
            summary = [dict(starting_depth=depths[-1],gasmix=initial,rate=-9,step_size=step)]
            summary += [dict(starting_depth=k*step,gasmix=g,rate=-9,step_size=step) for k,g in zip([7,2],stop_gases)]
            dive['profile_codes'] = profile+[dict(profile_code=99,number_of_ascent_parameter_changes=len(summary),ascent_summary=summary)]
            observed = run_reference(inp,sea_bar=1.01325,ccr_setpoints_bar=sp)[-1]
            oxygen = [mp.mpf(0),mp.mpf(0)]
            last_time,last_depth = 0.,0.
            def expose(row,end_depth,duration,index):
                gas = gases[index]
                inc = dose(last_depth,end_depth,duration,[gas['fraction_O2'],gas['fraction_He']],sp[index])
                oxygen[:] = [a+b for a,b in zip(oxygen,inc)]
                row['oxygen'] = dict(cns_fraction=float(oxygen[0]),otu=float(oxygen[1]))
            assert len(profile)==len(observed['expected_profile_segments'])
            for row,p in zip(observed['expected_profile_segments'],profile):
                end = p.get('ending_depth',p.get('depth'))
                expose(row,end,row['end_min']-last_time,p['gasmix']-1)
                row.update(end_depth_m=end,gas_index=p['gasmix']-1)
                last_time,last_depth = row['end_min'],end
            for row in observed['expected_segments']:
                # Upstream casts displayed stop depth to int when minimum time
                # is integral. The physical hold is at the preceding raw ascent
                # endpoint; preserve both instead of treating display as input.
                if row['kind'] == 'decompression':
                    row['reported_end_depth_m'] = row['end_depth_m']
                    row['end_depth_m'] = last_depth
                expose(row,row['end_depth_m'],row['duration_min'],row['gas_index'])
                last_time,last_depth = row['end_min'],row['end_depth_m']
            rows.append(dict(id=f'vpm-multilevel-descending-{mode}-{units}-c{c}',mode=mode,units=units,conservatism=c,
                step_metres=step,levels=product_levels,bailout_runtime_min=runtime if mode=='bailout' else None,
                request=inp,setpoints_bar=sp,**observed))
            print(rows[-1]['id'],last_time,flush=True)
out = dict(schema_version=1,provenance=dict(kind='independent-execution-normalized-policy-refined-roots',repository='https://github.com/bwaite/vpmb',commit=PIN,
    source_sha256=hashlib.sha256(source.encode()).hexdigest(),generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    adapter_sha256=hashlib.sha256((ROOT/'tool/reference_vpm_schedule.py').read_bytes()).hexdigest(),oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),
    command='local/oracles/python-env/bin/python tool/capture_vpm_multilevel_descending.py'),
    normalization=dict(surface_bar=1.01325,vapour_bar=.0493,bar_per_metre=.1,travel='Level duration includes travel. Down10m/min low SP.7; up9m/min target level gas/SP.',
        imperial='Exact feet*.3048 canonical metres and10ft stop grid; MSW oracle, not native FSW defaults.',
        physical_depth='Integral minimum-stop time makes upstream truncate displayed stop depth; physical hold uses preceding raw ascent endpoint. Reported display remains separate.',
        policy='Existing +.501 stop alignment, maximum trial first-stop Boyle argument, refined roots and SI0 finalization; CCR inspiration extension rejects dry-pressure clipping.'),
    tolerances=dict(time_min=1e-7,tissue_bar=1e-8,gradient_bar=1e-8,radius_m=1e-15,phase_min=1e-7,cns_fraction=1e-10,otu=1e-9),cases=rows)
(FIX/'independent/vpmb-multilevel-descending-units.json').write_text(json.dumps(out,indent=2,allow_nan=False)+'\n')
