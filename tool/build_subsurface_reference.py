"""Build optional pinned external reference, entirely under ignored local/.
Requires CMake, Qt6, pkg-config and Autotools plus the documented native deps.
Does not install packages or enter the Flutter build/runtime.
"""
import os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'local/oracles/subsurface';BUILD=ROOT/'local/oracles/subsurface-build'
PREFIX=ROOT/'local/oracles/subsurface-deps';DC=REF/'libdivecomputer'
PINS={REF:'7f2610cee4572ebc1795c48d054616a51d457eec',DC:'469f28d17ed05112496f176006eccccc9f8fdc73'}
for path,pin in PINS.items():
    if not path.exists():raise SystemExit('Missing optional pinned reference: '+str(path))
    actual=subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip()
    if actual!=pin:raise SystemExit('Reference commit mismatch: '+str(path))
subprocess.run(['git','-C',str(REF),'diff','--exit-code','--','core/deco.cpp','core/planner.cpp'],check=True)
if not (DC/'configure').exists():subprocess.run(['autoreconf','--install'],cwd=DC,check=True)
subprocess.run([str(DC/'configure'),'--prefix='+str(PREFIX),'--disable-examples'],cwd=DC,check=True)
subprocess.run(['make','-j','6'],cwd=DC,check=True)
subprocess.run(['make','install'],cwd=DC,check=True)
env=os.environ.copy();env['PKG_CONFIG_PATH']=str(PREFIX/'lib/pkgconfig')
flags=subprocess.check_output(['pkg-config','--libs','--static','libgit2','libdivecomputer','hidapi'],env=env,text=True).strip()
# Prefix is discovered from the actual dependency tool, not embedded user paths.
native_prefix=subprocess.check_output(['brew','--prefix'],text=True).strip()
qt_prefix=subprocess.check_output(['pkg-config','--variable=prefix','Qt6Core'],text=True).strip()
hid_libdir=subprocess.check_output(['pkg-config','--variable=libdir','hidapi'],text=True).strip()
subprocess.run(['cmake','-S',str(REF),'-B',str(BUILD),
    '-DSUBSURFACE_TARGET_EXECUTABLE=CLI','-DBUILD_WITH_QT6=ON','-DBUILD_TESTS=OFF',
    '-DBTSUPPORT=OFF','-DLIBRAW_SUPPORT=OFF','-DFORCE_LIBSSH=OFF',
    '-DCMAKE_PREFIX_PATH='+native_prefix+';'+qt_prefix,
    '-DHID_LIB='+hid_libdir+'/libhidapi.dylib',
    '-DLIBDIVECOMPUTER_INCLUDE_DIR='+str(PREFIX/'include'),
    '-DLIBDIVECOMPUTER_LIBRARIES='+str(PREFIX/'lib/libdivecomputer.a'),
    '-DCMAKE_EXE_LINKER_FLAGS=-L'+native_prefix+'/lib '+flags],check=True,env=env)
subprocess.run(['cmake','--build',str(BUILD),'--target','subsurface-cli','-j','6'],check=True)
print('Built independent source-native reference. Capture via tool/capture_subsurface_plans.py')
