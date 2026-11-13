"""Independent successful altitude and surface/repetitive state transitions.
Capture post-dive radius excitation at SI0 as an explicit model boundary, then
verify time evolution from that boundary; never read product outputs.
"""
import copy,hashlib,importlib.util,json,subprocess
from pathlib import Path
import mpmath as mp
from reference_vpm_state import snapshot
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/vpmb';FIX=ROOT/'packages/deco_core/test/fixtures'
PIN='bec938d84742e42dd43b574beec49ac26f6863ac'
assert subprocess.check_output(['git','-C',str(REF),'rev-parse','HEAD'],text=True).strip()==PIN
spec=importlib.util.spec_from_file_location('surface_reference',REF/'vpmb.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
physical=json.loads((FIX/'independent/vpmb-physical-states.json').read_text())['cases']
base=copy.deepcopy(physical[0]['request'])
def tissues(state):
    f=1.01325/state.Units_Factor
    return dict(nitrogenBar=[v*f for v in state.Nitrogen_Pressure],heliumBar=[v*f for v in state.Helium_Pressure])
altitudes=[]
for conserv,height,acclimatized,travel,wait in [(0,2000,True,180,120),(0,2000,False,180,120),
        (4,8848,False,1,120),(0,0,True,180,120),(0,8848,True,180,120),(4,2000,False,60,0)]:
    request=copy.deepcopy(physical[conserv]['request'])
    request['settings']['Altitude_Dive_Algorithm']='ON'
    request['altitude'].update(Altitude_of_Dive=height,Diver_Acclimatized_at_Altitude='yes' if acclimatized else 'no',
        Starting_Acclimatized_Altitude=0,Ascent_to_Altitude_Hours=travel/60,Hours_at_Altitude_Before_Dive=wait/60)
    state=module.DiveState(json_input=request);state.validate_data();state.initialize_data()
    f=1.01325/state.Units_Factor
    altitudes.append(dict(conservatism=conserv,dive_altitude_m=height,acclimatized=acclimatized,
        initial_altitude_m=0,travel_min=travel,wait_min=wait,sea_level_bar=1,
        expected=dict(surface_bar=state.Barometric_Pressure*f,tissues=tissues(state),
          initialRadiusNitrogenMetres=state.Initial_Critical_Radius_N2,
          initialRadiusHeliumMetres=state.Initial_Critical_Radius_He,
          adjustedInitialRadiusNitrogenMetres=state.Adjusted_Critical_Radius_N2,
          adjustedInitialRadiusHeliumMetres=state.Adjusted_Critical_Radius_He)))
state=module.DiveState(json_input=copy.deepcopy(base));state.main()
raw_bubble=snapshot(state);initial_tissues=tissues(state)
finalized=copy.deepcopy(state);finalized.vpm_repetitive_algorithm(0)
finalized_bubble=snapshot(finalized)
mp.mp.dps=60;intervals=[]
for minutes in [0,45,60,180,1440]:
    next_state=copy.deepcopy(state)
    next_state.gas_loadings_surface_interval(minutes);next_state.vpm_repetitive_algorithm(minutes)
    intervals.append(dict(minutes=minutes,expected_tissues=tissues(next_state),
       expected_adjusted_n2_radius_m=next_state.Adjusted_Critical_Radius_N2,
       expected_adjusted_he_radius_m=next_state.Adjusted_Critical_Radius_He,
       expected_cns_from_point6=mp.nstr(mp.mpf('.6')*mp.power(2,-mp.mpf(minutes)/90),50),expected_otu=100))
output=dict(schema_version=1,provenance=dict(kind='independent-successful-altitude-and-repetitive-transitions',
    repository='https://github.com/bwaite/vpmb',commit=PIN,source_sha256=hashlib.sha256((REF/'vpmb.py').read_bytes()).hexdigest(),
    numerical_modifications=False,oxygen_recovery_source='Baker90min convention, independently evaluated by mpmath',
    command='local/oracles/python-env/bin/python tool/capture_vpm_surface_reference.py'),
    boundary_policy='Commit source repetitive(radius update,SI0) at completed-dive boundary. Public SI0 is then identity.',
    altitude_cases=altitudes,post_dive=dict(pressure_bar=state.Barometric_Pressure*.1,vapour_bar=.0493,
        raw_bubble=raw_bubble,finalized_bubble=finalized_bubble,tissues=initial_tissues),surface_intervals=intervals)
(FIX/'independent/vpmb-altitude-surface-transitions.json').write_text(json.dumps(output,indent=2,allow_nan=False)+'\n')
print('Captured6 successful altitude preparations and SI0/45/60/180/1440 with full influencing bubble state')
