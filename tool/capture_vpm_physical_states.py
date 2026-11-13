"""Capture independent VPM-B crushing/regeneration states for c0-c4.
Only the optional private pinned oracle executes numerical algorithms.
"""
import copy,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/vpmb'
PIN='bec938d84742e42dd43b574beec49ac26f6863ac'
assert subprocess.check_output(['git','-C',str(REF),'rev-parse','HEAD'],text=True).strip()==PIN
spec=importlib.util.spec_from_file_location('vpmb_physical_reference',REF/'vpmb.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
rows=[]
for conservatism,scale,depth in [(i,s,80) for i,s in enumerate([1,1.1,1.15,1.25,1.35])]+[(0,1,200)]:
    inp=json.loads((REF/'tests/msw_simple/vpm_decompression_input.json').read_text())
    if depth==200:
        inp['input'][0]['gasmix_summary'][0].update(fraction_O2=.08,fraction_He=.77,fraction_N2=.15)
        for segment in inp['input'][0]['profile_codes']:
            if 'ending_depth' in segment:segment['ending_depth']=depth
            if 'depth' in segment:segment['depth']=depth
            for ascent in segment.get('ascent_summary',[]):ascent['starting_depth']=depth
    inp['settings']['Critical_Radius_N2_Microns']=.45*scale
    inp['settings']['Critical_Radius_He_Microns']=.55*scale
    inp['settings']['Crit_Volume_Parameter_Lambda']=6500
    for dive in inp['input']:
        for seg in dive['profile_codes']:
            seg.pop('setpoint',None)
            for ascent in seg.get('ascent_summary',[]):ascent.pop('setpoint',None)
    state=module.DiveState(json_input=copy.deepcopy(inp));trace=[]
    def snapshot(stage,args):
        factor=1.01325/state.Units_Factor
        pressure={label:[v*factor for v in getattr(state,name)] for label,name in {
            'maxCrushingPressureNitrogenBar':'Max_Crushing_Pressure_N2',
            'maxCrushingPressureHeliumBar':'Max_Crushing_Pressure_He',
            'ambientOnsetBar':'Amb_Pressure_Onset_of_Imperm',
            'tensionOnsetBar':'Gas_Tension_Onset_of_Imperm',
            'adjustedCrushingPressureNitrogenBar':'Adjusted_Crushing_Pressure_N2',
            'adjustedCrushingPressureHeliumBar':'Adjusted_Crushing_Pressure_He',
            'initialAllowableGradientNitrogenBar':'Initial_Allowable_Gradient_N2',
            'initialAllowableGradientHeliumBar':'Initial_Allowable_Gradient_He'}.items()}
        radii={label:list(getattr(state,name)) for label,name in {
            'regeneratedRadiusNitrogenMetres':'Regenerated_Radius_N2',
            'regeneratedRadiusHeliumMetres':'Regenerated_Radius_He'}.items()}
        return dict(stage=stage,args=args,runtime_min=state.Run_Time,
                    tissues_bar=dict(n2=[v*factor for v in state.Nitrogen_Pressure],he=[v*factor for v in state.Helium_Pressure]),
                    pressure_state=pressure,radius_state=radii)
    for name in ['calc_crushing_pressure','nuclear_regeneration','calc_initial_allowable_gradient']:
        original=getattr(state,name)
        def wrapper(*args,_name=name,_original=original,**kwargs):
            result=_original(*args,**kwargs);trace.append(snapshot(_name,list(args)));return result
        setattr(state,name,wrapper)
    state.main()
    rows.append(dict(conservatism=conservatism,scale=scale,depth_m=depth,request=inp,
                     normalization=dict(surface_bar=1.0,vapour_bar=.0493,bar_per_metre=.1,initial_nitrogen_fraction=.79),
                     expected_stages=trace))
result=dict(schema_version=1,provenance=dict(kind='independent-execution-instrumented-states',repository='https://github.com/bwaite/vpmb',commit=PIN,
    source_sha256=hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),numerical_modifications=False,
    instrumentation='Wrappers snapshot only after original methods; no inputs or numerical operations replaced',
    command='local/oracles/python-env/bin/python tool/capture_vpm_physical_states.py'),cases=rows)
out=ROOT/'packages/deco_core/test/fixtures/independent/vpmb-physical-states.json'
out.write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
print('Captured6 independent c0-c4 crushing/regeneration/initial-gradient traces')
