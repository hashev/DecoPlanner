"""Capture source-driven intermediate ascent + redescent before Dart comparison."""
import copy
import hashlib
import json
import itertools
import subprocess
from pathlib import Path
import mpmath as mp
from reference_vpm_schedule import ROOT,FIX,PIN,source
from reference_vpm_multilevel import run_multilevel
from reference_oxygen_quadrature import dose

assert source.encode() == subprocess.check_output(['git','-C',str(ROOT/'local/oracles/vpmb'),'show',f'{PIN}:vpmb.py'])
mp.mp.dps=70
base=json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases'][:5]
rows=[]
for c,units,mode,variant in itertools.product(range(5),['metric','imperial'],['oc','ccr','bailout'],['above-zone','with-stops']):
    step=3 if units=='metric' else 3.048
    depths=([45,36,42] if units=='metric' else [150*.3048,120*.3048,140*.3048]) if variant=='above-zone' else ([45,12,30] if units=='metric' else [150*.3048,40*.3048,100*.3048])
    inp=copy.deepcopy(base[c]['request']); dive=inp['input'][0]
    def mix(o,h): return dict(fraction_O2=o,fraction_He=h,fraction_N2=1-o-h)
    gases=[mix(.18,.45),mix(.5,0),mix(.8,0)] if mode=='oc' else [mix(.18,.45),mix(.18,.45),mix(.21,.35),mix(.21,.35)]
    sp=[None]*3 if mode=='oc' else [.7,1.3,1.4,.7]
    if mode!='oc' and variant=='with-stops': sp=[.7]*4
    main=1 if mode=='oc' else 2
    inter=[dict(starting_depth=depths[0],gasmix=main,rate=-9,step_size=step)]
    inter += [dict(starting_depth=k*step,gasmix=g,rate=-9,step_size=step) for k,g in zip([7,2],[2,3] if mode=='oc' else [3,4])]
    final=copy.deepcopy(inter); final[0]['starting_depth']=depths[-1]
    if mode=='bailout':
        gases += [mix(.18,.45),mix(.5,0),mix(.8,0)]; sp += [None]*3
        for row,g in zip(final,[5,6,7]): row['gasmix']=g
    dive['gasmix_summary']=gases; dive['num_gas_mixes']=len(gases)
    dive['profile_codes']=[dict(profile_code=99,number_of_ascent_parameter_changes=len(final),ascent_summary=final)]
    levels=[[d,t,1 if mode=='oc' or i!=1 else 2,main] for i,(d,t) in enumerate(zip(depths,[12,4,4]))]
    observed=run_multilevel(inp,levels,sp,inter)
    oxygen=[mp.mpf(0),mp.mpf(0)]
    for segment in observed['expected_timeline']:
        gas=gases[segment['gas_index']]
        inc=dose(segment['start_depth_m'],segment['end_depth_m'],segment['duration_min'],[gas['fraction_O2'],gas['fraction_He']],sp[segment['gas_index']])
        oxygen=[a+b for a,b in zip(oxygen,inc)]
        segment['oxygen']=dict(cns_fraction=float(oxygen[0]),otu=float(oxygen[1]))
    ascent=deco=0.
    reached_stop=False
    for segment in observed['expected_timeline']:
        if segment['kind'].startswith('level'):
            reached_stop=False
        else:
            ascent+=segment['duration_min']
            reached_stop=reached_stop or segment['kind']=='decompression'
            if reached_stop: deco+=segment['duration_min']
    observed['metrics']=dict(runtime_min=observed['expected_timeline'][-1]['end_min'],ascent_min=ascent,decompression_min=deco)
    rows.append(dict(id=f'vpm-redescent{"-stops" if variant=="with-stops" else ""}-{mode}-{units}-c{c}',mode=mode,variant=variant,units=units,conservatism=c,step_metres=step,levels=levels,request=inp,setpoints_bar=sp,intermediate_summary=inter,**observed))
    print(rows[-1]['id'],observed['expected_timeline'][-1]['end_min'],flush=True)
out=dict(schema_version=1,provenance=dict(kind='independent-execution-with-explicit-partial-ascent-orchestration',repository='https://github.com/bwaite/vpmb',commit=PIN,source_sha256=hashlib.sha256(source.encode()).hexdigest(),generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),adapter_sha256=hashlib.sha256((ROOT/'tool/reference_vpm_multilevel.py').read_bytes()).hexdigest(),base_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_vpm_schedule.py').read_bytes()).hexdigest(),oxygen_adapter_sha256=hashlib.sha256((ROOT/'tool/reference_oxygen_quadrature.py').read_bytes()).hexdigest(),command='local/oracles/python-env/bin/python tool/capture_vpm_redescent.py'),normalization='Intermediate ascent runs full source CV-to-surface trials, clips only final physical pass at entered level; hold ends at ceil(arrival runtime)+entered duration. New descent includes travel. Physical maximum-gradient history is accumulated across partial ascents within one dive; final segment publishes independent SI0 finalized state and raw surface output is retained. Same MSW/10ft canonical normalization as descending matrix.',tolerances=dict(time_min=1e-7,tissue_bar=1e-8,gradient_bar=1e-8,radius_m=1e-15,cns_fraction=1e-10,otu=1e-9),cases=rows)
name='vpmb-redescent-normalized.json'
(FIX/'independent'/name).write_text(json.dumps(out,indent=2,allow_nan=False)+'\n')
