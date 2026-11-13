"""Capture source-native full CCR/bailout profiles; not normalized regressions.
The embedded harness only configures inputs and dumps results. All numerical
operations come from the separately built, untouched optional source oracle.
"""
import hashlib,json,shlex,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];REF=ROOT/'local/oracles/subsurface'
BUILD=ROOT/'local/oracles/subsurface-build';OUT=ROOT/'local/oracles/subsurface-plan'
PIN='7f2610cee4572ebc1795c48d054616a51d457eec';DC_PIN='469f28d17ed05112496f176006eccccc9f8fdc73'
for path,pin in [(REF,PIN),(REF/'libdivecomputer',DC_PIN)]:
    assert subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip()==pin
subprocess.run(['git','-C',str(REF),'diff','--exit-code','--','core/deco.cpp','core/planner.cpp'],check=True)
OUT.mkdir(exist_ok=True)
HARNESS='#include "core/deco.h"\n#include "core/dive.h"\n#include "core/planner.h"\n#include "core/pref.h"\n#include "core/equipment.h"\n#include <QCoreApplication>\n#include <cstdio>\n#include <cstring>\nint main(int argc,char**argv) {\n QCoreApplication app(argc,argv);\n prefs=default_prefs;\n prefs.unit_system=METRIC; prefs.units.length=units::METERS;\n prefs.ascrate50=feet_to_mm(30)/60; prefs.ascrate75=prefs.ascrate50;\n prefs.ascratestops=prefs.ascrate50; prefs.ascratelast6m=feet_to_mm(10)/60;\n prefs.last_stop=true;\n bool vpm=argc>1 && std::strcmp(argv[1],"vpm")==0;\n bool bailout=argc>2 && std::strcmp(argv[2],"bailout")==0;\n prefs.planner_deco_mode=vpm?VPMB:BUEHLMANN;\n prefs.vpmb_conservatism=0; prefs.dobailout=bailout;\n struct dive profile;\n profile.dcs[0].divemode=CCR;\n diveplan request;\n request.salinity=10300; request.surface_pressure=1_atm;\n request.gflow=50; request.gfhigh=70;\n request.bottomsac=prefs.bottomsac; request.decosac=prefs.decosac;\n profile.get_or_create_cylinder(2);\n auto*c0=profile.get_cylinder(0); auto*c1=profile.get_cylinder(1);auto*c2=profile.get_cylinder(2);\n c0->gasmix.o2.permille=200;c0->gasmix.he.permille=210;c0->cylinder_use=DILUENT;\n c0->type.size=3_l;c0->type.workingpressure=200_bar;\n c1->gasmix.o2.permille=530;c1->gasmix.he.permille=0;\n c2->gasmix.o2.permille=190;c2->gasmix.he.permille=330;\n for(int i=0;i<3;i++) {auto*c=profile.get_cylinder(i);c->depth=profile.gas_mod(c->gasmix,1600_mbar,m_or_ft(3,10));}\n reset_cylinders(&profile,true);\n plan_add_segment(request,0,c1->depth,1,0,false,OC);\n plan_add_segment(request,0,c2->depth,2,0,false,OC);\n plan_add_segment(request,20*60,60_m,0,1300,true,CCR);\n deco_state state;deco_state_cache cache;std::vector<decostop>stops;\n auto error=plan(&state,request,&profile,0,60,cache,true,false,&stops);\n if(error!=PLAN_OK) {fprintf(stderr,"Planner error%d\\n",error);return 2;}\n printf("{\\"runtime_seconds\\":%d,\\"bailout\\":%s,\\"points\\":[",profile.dcs[0].duration.seconds,bailout?"true":"false");\n bool first=true;\n for(const auto&p:request.dp) {\n  printf("%s{\\"time_seconds\\":%d,\\"depth_mm\\":%d,\\"cylinder\\":%d,\\"setpoint_mbar\\":%d,\\"mode\\":%d}",first?"":",",p.time,p.depth.mm,p.cylinderid,p.setpoint,int(p.divemode));first=false;\n }\n printf("],\\"n2_bar\\":[");\n for(int i=0;i<16;i++)printf("%s%.17g",i?",":"",state.tissue_n2_sat[i]);\n printf("],\\"he_bar\\":[");\n for(int i=0;i<16;i++)printf("%s%.17g",i?",":"",state.tissue_he_sat[i]);\n printf("]}\\n");\n}\n'
main=OUT/'main.cpp';main.write_text(HARNESS);obj=main.with_suffix('.o');exe=OUT/'planner'
flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','Qt6Core','Qt6Widgets'],text=True))
subprocess.run(['c++','-std=c++20','-I'+str(REF),'-I'+str(ROOT/'local/oracles/subsurface-deps/include'),*flags,'-c',str(main),'-o',str(obj)],check=True)
link=BUILD/'cli/CMakeFiles/subsurface-cli.dir/link.txt'
if not link.exists():raise SystemExit('Build optional source reference first: python3 tool/build_subsurface_reference.py')
args=shlex.split(link.read_text());args=[s for s in args if not s.endswith('.o')]
index=args.index('-o');args[index+1]=str(exe);args.insert(index,str(obj));args.insert(1,'-Wl,-dead_strip')
subprocess.run(args,cwd=BUILD/'cli',check=True)
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for model in ['buhlmann','vpm']:
    for bailout in [False,True]:
        completed=subprocess.run([str(exe),model]+(['bailout'] if bailout else []),capture_output=True,text=True,timeout=30,check=True)
        result=json.loads(completed.stdout)
        if bailout and model=='buhlmann':assert result['runtime_seconds']==3060
        label='subsurface-'+('c1b' if model=='buhlmann' else 'vpmb')+'-'+('bailout' if bailout else 'ccr')
        provenance=dict(kind='independent-full-plan-execution',repository='https://github.com/subsurface/subsurface',
            commit=PIN,libdc_submodule_commit=DC_PIN,
            source_sha256={str(p.relative_to(REF)):digest(p) for p in [REF/'core/deco.cpp',REF/'core/planner.cpp']},
            harness_sha256=digest(main),executable_sha256=digest(exe),numerical_modifications=False,
            command='python3 tool/capture_subsurface_plans.py',
            author_benchmark_check='C1b bailout3060s matches upstream TestPlan::testCcrBailoutGasSelection' if bailout and model=='buhlmann' else 'independent execution; no separate author benchmark claimed')
        output=dict(schema_version=1,id=label,provenance=provenance,
            request=dict(model='C1b' if model=='buhlmann' else 'VPMB',mode='bailout' if bailout else 'ccr',
                depth_m=60,bottom_runtime_min=20,diluent_o2=.20,diluent_he=.21,setpoint_bar=1.3,
                gf_low=.5,gf_high=.7,salinity_source=10300,
                gas_availability=[dict(o2=.53,he=0),dict(o2=.19,he=.33)]),expected=result,
            scope='Full source-native plan. Conventions require normalization before product regression; tissues are the state returned by plan().')
        (ROOT/'packages/deco_core/test/fixtures/independent'/(label+'.json')).write_text(json.dumps(output,indent=2)+'\n')
        print(label,result['runtime_seconds'],'seconds')
