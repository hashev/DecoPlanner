"""Build untouched private Subsurface numerical sources for CCR tissue checks.
Not a full schedule oracle. Run from the repository root on macOS with Qt6.
"""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / 'local/oracles/subsurface'
LIBDC = ROOT / 'local/oracles/libdivecomputer'
PIN = '7f2610cee4572ebc1795c48d054616a51d457eec'
LIB_PIN = '14f92934c0aedbba7a5aafe8915e8a96d944335c'
BUILD = ROOT / 'local/oracles/subsurface-tissues'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def command(*args):
    return subprocess.check_output(args, text=True).strip()

for path, pin in [(REF, PIN), (LIBDC, LIB_PIN)]:
    if command('git', '-C', str(path), 'rev-parse', 'HEAD') != pin:
        raise SystemExit('Reference commit mismatch: ' + str(path))
BUILD.mkdir(exist_ok=True)
# Only configuration plumbing is supplied by our harness; add_segment,
# fill_pressures, tissue factors and constants are compiled without changes.
HARNESS = r'''
#include "deco.h"
#include "pref.h"
#include <cstdio>
#include <cstdarg>
#include <cstdlib>
preferences::preferences() = default;
preferences::~preferences() = default;
struct preferences prefs;
static deco_mode selected = BUEHLMANN;
enum deco_mode pref_deco_mode(bool) {return selected;}
int report_error(const char *, ...) {std::abort();}
int main(int argc, char **argv) {
 if (argc > 1) selected = VPMB;
 deco_state state;
 clear_deco(&state, 1.01325, true);
 gasmix diluent; diluent.o2.permille=180; diluent.he.permille=450;
 add_segment(&state, 6.01325, diluent, 1200, 1300, CCR, 0, true);
 printf("{\"mode\":\"CCR\",\"n2\":[");
 for (int i=0;i<16;i++) printf("%s%.17g",i?",":"",state.tissue_n2_sat[i]);
 printf("],\"he\":[");
 for (int i=0;i<16;i++) printf("%s%.17g",i?",":"",state.tissue_he_sat[i]);
 printf("]}\n");
}
'''
main = BUILD / 'main.cpp'
main.write_text(HARNESS)
cflags = shlex.split(command('pkg-config', '--cflags', 'Qt6Core', 'Qt6Widgets'))
libs = shlex.split(command('pkg-config', '--libs', 'Qt6Core', 'Qt6Widgets'))
objects = []
for source in [main, REF/'core/deco.cpp', REF/'core/gas.cpp']:
    obj = BUILD/(source.stem+'.o')
    subprocess.run(['c++', '-std=c++20', '-I'+str(REF/'core'),
                    '-I'+str(LIBDC/'include'), *cflags,
                    '-c', str(source), '-o', str(obj)], check=True)
    objects.append(str(obj))
exe = BUILD/'tissues'
subprocess.run(['c++', '-Wl,-dead_strip', *objects, *libs, '-o', str(exe)], check=True)
for mode, vapour in [('buhlmann', .0627), ('vpmb', .0493)]:
    result = json.loads(command(str(exe), *(['vpmb'] if mode == 'vpmb' else [])))
    data = dict(schema_version=1, id='subsurface-'+mode+'-ccr-hold',
                provenance=dict(kind='independent-execution',
                    repository='https://github.com/subsurface/subsurface',
                    commit=PIN, libdivecomputer_headers_commit=LIB_PIN,
                    numerical_source_sha256={name:digest(REF/'core'/name)
                        for name in ['deco.cpp','gas.cpp','units.h']},
                    harness_sha256=digest(main), numerical_modifications=False,
                    command='python3 tool/capture_subsurface_tissues.py'),
                request=dict(mode='ccr', duration_min=20, ambient_bar=6.01325,
                    surface_bar=1.01325, water_vapour_bar=vapour,
                    initial_n2_fraction=.781, o2_fraction=.18, he_fraction=.45,
                    setpoint_bar=1.3), expected=result,
                scope='Constant-pressure CCR tissue propagation only; not a full schedule or VPM bubble oracle',
                comparison_policy='explicit upstream initialization; pending model normalization')
    output=ROOT/'packages/deco_core/test/fixtures/independent'/(data['id']+'.json')
    output.write_text(json.dumps(data, indent=2, allow_nan=False)+'\n')
print('Captured two independent CCR tissue examples (not full schedules)')
