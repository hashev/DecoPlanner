"""Build read-only contact sheets and Markdown preview index."""
import json,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parents[1];manifest=json.loads((OUT/'mockups/manifest.json').read_text());review=OUT/'reports/contact-sheets';review.mkdir(exist_ok=True)
index=['# Индекс макетов','','SVG — редактируемый оригинал; PNG — отрендеренное превью. Это статические аннотированные схемы, не кликабельное приложение. Продолжения `-02` и далее показывают следующие срезы длинного экрана. Числа и поле provenance указаны в [манифесте](manifest.json).','','| Экран | Mobile light | Mobile dark | Desktop light | Desktop dark |','|---|---|---|---|---|']
ids=list(dict.fromkeys(m['screen'] for m in manifest if not m['id'].startswith('MATRIX-')))
for sid in ids:
 links=[]
 for mode in ['mobile','desktop']:
  for theme in ['light','dark']:
   name=f'{sid}-{mode}-{theme}';ms=[m for m in manifest if m['id']==name or m['id'].startswith(name+'-')]
   links.append(' · '.join(f"[{m['page']}]({Path(m['svg']).name})" for m in sorted(ms,key=lambda x:x['page'])))
 index+=['| '+sid+' | '+' | '.join(links)+' |']
index+=['','## Размерная матрица','','| Вариант | Срезы |','|---|---|']
groups={}
for m in manifest:
 if m['id'].startswith('MATRIX-'):groups.setdefault((m['width'],m['height'],m['theme'],m['text_scale']),[]).append(m)
for key,ms in groups.items():index+=['| '+' / '.join(map(str,key))+' | '+' · '.join(f"[{m['page']}]({Path(m['svg']).name})" for m in sorted(ms,key=lambda x:x['page']))+' |']
(OUT/'mockups/README.md').write_text('\n'.join(index)+'\n')
# Each contact sheet has a stable list of its full-resolution members.
sheets=[]
for i in range(0,len(manifest),24):
 batch=manifest[i:i+24];path=review/f'sheet-{i//24+1:02}.png'
 cmd=['magick','montage','-font','Verdana','-pointsize','12']
 for m in batch:cmd+=['-label',m['id'],str(OUT/m['png'])]
 cmd+=['-thumbnail','230x300','-background','#E2E8F0','-fill','#0F172A','-gravity','center','-tile','6x4','-geometry','240x330+8+12',str(path)]
 subprocess.run(cmd,check=True,capture_output=True)
 sheets.append(dict(file=str(path.relative_to(OUT)),members=[m['id'] for m in batch]))
(OUT/'reports/contact-sheets.json').write_text(json.dumps(sheets,indent=2)+'\n')
print(len(sheets),'contact sheets')
