"""Build the independent VPM-B reference in ignored local storage.

The only source adjustment namespaces the bundled strlcpy portability helper
so it cannot collide with modern macOS SDK macros. No numerical code changes.
"""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPOSITORY='https://github.com/bwaite/vpmb.git'
COMMIT='bec938d84742e42dd43b574beec49ac26f6863ac'
base=ROOT/'local/oracles';source=base/'vpmb';portable=base/'vpmb-portable';build=base/'vpmb-portable-build'
base.mkdir(parents=True,exist_ok=True)
if not source.exists():subprocess.run(['git','clone',REPOSITORY,str(source)],check=True)
actual=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
if actual!=COMMIT:raise SystemExit('Reference checkout differs from pinned commit; use a separate pinned checkout')
shutil.copytree(source/'c',portable,dirs_exist_ok=True)
patches=[]
for p in sorted(portable.glob('*')):
 if p.suffix not in ['.c','.h']:continue
 old=p.read_text();new=re.sub(r'\bstrlcpy\b','vpmb_reference_strlcpy',old).replace('"vpmb_reference_strlcpy.h"','"strlcpy.h"')
 if new!=old:
  p.write_text(new);patches.append({'file':p.name,'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(new.encode()).hexdigest(),'change':'namespace portability helper only'})
subprocess.run(['cmake','-S',str(portable),'-B',str(build)],check=True)
subprocess.run(['cmake','--build',str(build),'-j','2'],check=True)
metadata={'repository':REPOSITORY,'commit':COMMIT,'patches':patches,'numerical_changes':False,'executable':str((build/'vpmb').relative_to(ROOT)),'executable_sha256':hashlib.sha256((build/'vpmb').read_bytes()).hexdigest()}
(base/'vpmb-build-provenance.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps(metadata,indent=2))
