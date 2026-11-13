"""Independent VPM kernel snapshots. First Boyle call uses mpmath radius root.
External source flow/formulas stay separate from Dart. Numerical refinement is
explicitly recorded and is not called an untouched full-schedule benchmark.
"""
import copy,hashlib,importlib.util,json,subprocess
from pathlib import Path
import mpmath as mp
from reference_vpm_state import snapshot
mp.mp.dps=70
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/vpmb';FIX=ROOT/'packages/deco_core/test/fixtures'
PIN='bec938d84742e42dd43b574beec49ac26f6863ac'
assert subprocess.check_output(['git','-C',str(REF),'rev-parse','HEAD'],text=True).strip()==PIN
spec=importlib.util.spec_from_file_location('vpm_kernel_ref',REF/'vpmb.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
sourceCases=json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases'][:5]
rows=[]
for case in sourceCases:
    state=module.DiveState(json_input=copy.deepcopy(case['request']));trace=[];seen=set()
    original_root=module.radius_root_finder
    def refined_root(a,b,c,lo,hi):
        if lo==hi:return lo
        a,b,c,lo,hi=map(lambda x:mp.mpf(str(x)),[a,b,c,lo,hi]);scale=hi
        normal=max(abs(a*scale**3),abs(b*scale**2),abs(c))
        return float(scale*mp.findroot(lambda x:(a*(scale*x)**3-b*(scale*x)**2-c)/normal,
                     (lo/scale,1),solver='bisect',tol=mp.mpf('1e-50'),maxsteps=250))
    for name in ['boyles_law_compensation','calc_surface_phase_volume_time','critical_volume']:
        original=getattr(state,name)
        def wrapper(*args,_name=name,_original=original,**kwargs):
            first=_name not in seen
            before=snapshot(state) if first else None
            tissues=dict(nitrogenBar=[v*.1 for v in state.Nitrogen_Pressure],heliumBar=[v*.1 for v in state.Helium_Pressure])
            if first and _name=='boyles_law_compensation':module.radius_root_finder=refined_root
            try:result=_original(*args,**kwargs)
            finally:module.radius_root_finder=original_root
            if first:
                seen.add(_name)
                trace.append(dict(method=_name,args=list(args),input_bubble=before,input_tissues=tissues,
                                  expected_bubble=snapshot(state)))
            return result
        setattr(state,name,wrapper)
    state.main();rows.append(dict(conservatism=case['conservatism'],stages=trace))
result=dict(schema_version=1,provenance=dict(kind='independent-source-kernel-execution-with-refined-root',
    repository='https://github.com/bwaite/vpmb',commit=PIN,source_sha256=hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),
    numerical_override='First captured Boyle call only: mpmath70digit cubic bisection replaces1e-12m stopping rule',
    command='local/oracles/python-env/bin/python tool/capture_vpm_gradient_kernels.py'),
    tolerances=dict(gradient_bar=1e-8,surface_phase_min=1e-9),cases=rows)
(FIX/'independent/vpmb-gradient-kernels.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
print('Captured first Boyle/surface-phase/critical-volume kernels for c0–c4')
