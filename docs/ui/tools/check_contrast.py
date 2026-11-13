"""Verify all allowed opaque token combinations, not a runtime a11y test."""
import json
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]
TOKENS=json.loads((OUT/'tokens.json').read_text())
def lum(s):
 rgb=[int(s[i:i+2],16)/255 for i in [1,3,5]]
 rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 return sum(a*b for a,b in zip(rgb,[.2126,.7152,.0722]))
def ratio(a,b):
 x,y=sorted([lum(a),lum(b)]);return (y+.05)/(x+.05)
rows=[]
for theme,t in TOKENS.items():
 for bg in ['background','surface']:
  for fg in ['text','secondary','primary','warning','error','success','border','focus']:
   minimum=3 if fg in ['border','focus'] else 4.5
   r=ratio(t[fg],t[bg]); rows.append(dict(theme=theme,foreground=fg,background=bg,ratio=round(r,3),minimum=minimum,passed=r>=minimum))
 r=ratio(t['onPrimary'],t['primary']);rows.append(dict(theme=theme,foreground='onPrimary',background='primary',ratio=round(r,3),minimum=4.5,passed=r>=4.5))
assert all(x['passed'] for x in rows)
(OUT/'reports/contrast.json').write_text(json.dumps({'method':'sRGB relative luminance, opaque colours, (L1+.05)/(L2+.05)','pairs':rows,'all_passed':True},indent=2)+'\n')
print(len(rows),'pairs passed; minimum',min(x['ratio'] for x in rows))
