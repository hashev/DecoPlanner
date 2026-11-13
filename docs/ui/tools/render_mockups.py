"""Render static SVG design boards + PNG previews. Requires rsvg-convert.
No calculations are performed. Read screen-model.json for editable content.
"""
import argparse,copy,html,json,math,subprocess,textwrap
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; OUT=ROOT/'docs/ui'; DEST=OUT/'mockups'
TOKENS=json.loads((OUT/'tokens.json').read_text()); SCREENS=json.loads((OUT/'screen-model.json').read_text())
def esc(s):return html.escape(str(s),quote=True)
def lines(s,width,size):
 # Conservative width reserve for Cyrillic Verdana and punctuation.
 return textwrap.wrap(str(s),max(4,int(width/(size*.66))),break_long_words=True,break_on_hyphens=False) or ['']
class Board:
 def __init__(self,w,h,theme,scale=1):
  self.w,self.h,self.t,self.scale=w,h,TOKENS[theme],scale;self.svg=[];self.bounds=[];self.hits=[];self.field_count=0
 def rect(self,x,y,w,h,fill,stroke=None,r=0,hit=False):
  self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'+(f' stroke="{stroke}"' if stroke else '')+'/>')
  self.bounds.append([x,y,x+w,y+h])
  if hit:self.hits.append([w,h])
 def text(self,x,y,s,size=16,color=None,weight=400,width=None):
  size*=self.scale; ls=lines(s,width,size) if width else [s];lh=math.ceil(size*1.45)
  for n,l in enumerate(ls):
   yy=y+n*lh
   self.svg.append(f'<text x="{x}" y="{yy}" font-family="Verdana,sans-serif" font-size="{size}" font-weight="{weight}" fill="{color or self.t["text"]}">{esc(l)}</text>')
   self.bounds.append([x,yy-size,x+min(len(l)*size*.66,width or self.w),yy+size*.25])
  return len(ls)*lh
 def button(self,x,y,w,label,primary=False):
  size=14*self.scale; h=max(48,len(lines(label,w-24,size))*math.ceil(size*1.45)+20)
  self.rect(x,y,w,h,self.t['primary'] if primary else self.t['surface'],self.t['primary'],8,True)
  self.text(x+12,y+16+size*.7,label,14,self.t['onPrimary'] if primary else self.t['primary'],600,w-24)
  return h
 def panel_height(self,p,w):
  sc=self.scale;size=16*sc;sz=14*sc
  height=20+len(lines(p['title'],w-32,size))*math.ceil(size*1.45)+12
  for f in p['fields']:
   value_h=len(lines(f['value'],w-56,size))*math.ceil(size*1.45)
   height+=len(lines(f['label'],w-32,sz))*math.ceil(sz*1.45)+8+max(48,value_h+16)+16
  if p.get('note'):height+=len(lines(p['note'],w-32,sz))*math.ceil(sz*1.45)+12
  if p.get('chart'):height+=210
  if p.get('table'):height+=64+48*len(p['table']['rows'])+16
  return height+12
 def panel(self,x,y,w,p):
  previous_tokens=self.t
  if p.get('paper'):self.t=TOKENS['light']
  h=self.panel_height(p,w);self.rect(x,y,w,h,self.t['surface'],self.t['border'],12)
  yy=y+20
  th=self.text(x+16,yy+16*self.scale,p['title'],16,weight=600,width=w-32);yy+=th+12
  for f in p['fields']:
   lh=self.text(x+16,yy+14*self.scale,f['label'],14,self.t['error'] if f.get('error') else self.t['secondary'],width=w-32);yy+=lh+8
   vh=len(lines(f['value'],w-56,16*self.scale))*math.ceil(16*self.scale*1.45);bh=max(48,vh+16)
   self.rect(x+16,yy,w-32,bh,self.t['background'],self.t['error'] if f.get('error') else self.t['border'],8,True)
   self.text(x+28,yy+8+16*self.scale,f['value'],16,width=w-56);yy+=bh+16
   self.field_count+=1
  if p.get('note'):
   yy+=self.text(x+16,yy+14*self.scale,p['note'],14,self.t['secondary'],width=w-32)+12
  if p.get('chart'):
   self.chart(x+16,yy,w-32,p['chart'])
  if p.get('table'):self.table(x+16,yy,w-32,p['table'])
  self.t=previous_tokens
  return h
 def table(self,x,y,w,data):
  cols=data['headers'];cw=w/len(cols)
  for i,col in enumerate(cols):self.text(x+i*cw+8,y+18,col,14,self.t['secondary'],600,cw-16)
  yy=y+64
  for row in data['rows']:
   self.rect(x,yy,w,48,self.t['background'],self.t['border'])
   for i,val in enumerate(row):self.text(x+i*cw+8,yy+29,val,14,width=cw-16)
   yy+=48
 def chart(self,x,y,w,kind):
  # Deliberately illustrative series; never presented as an original result.
  self.text(x,y+18,'Глубина, м' if kind=='profile' else 'Давление, ATA',14,self.t['secondary'])
  xx=x+32;yy=y+34;ww=w-48;hh=116
  for dy,label in [(0,'0' if kind=='profile' else '4'),(58,'20' if kind=='profile' else '2'),(116,'40' if kind=='profile' else '0')]:
   self.text(x,yy+dy+5,label,14,self.t['secondary']);self.svg.append(f'<path d="M{xx},{yy+dy} h{ww}" stroke="{self.t["border"]}" fill="none"/>')
  pts=[(0,0),(.12,90),(.60,90),(.72,60),(.82,30),(1,0)] if kind=='profile' else [(0,110),(.20,90),(.5,35),(.72,20),(1,42)]
  points=' '.join(f'{xx+a*ww},{yy+b}' for a,b in pts)
  self.svg.append(f'<polyline points="{points}" fill="none" stroke="{self.t["primary"]}" stroke-width="3"/>')
  points=' '.join(f'{xx+a*ww},{yy+min(116,b+12)}' for a,b in pts)
  self.svg.append(f'<polyline points="{points}" fill="none" stroke="{self.t["secondary"]}" stroke-width="2" stroke-dasharray="8 5"/>')
  self.text(x,y+180,'A — линия; B — штрих' if kind=='profile' else 'N2 — линия; He — штрих',14,self.t['secondary'],width=w)
  self.text(x,y+204,'Время, мин → · Иллюстрация',14,self.t['secondary'],width=w)
 def save(self,path,title,desc):
  assert all(x>=0 and y>=0 and xx<=self.w+.01 and yy<=self.h+.01 for x,y,xx,yy in self.bounds),(path,[b for b in self.bounds if b[2]>self.w or b[3]>self.h])
  assert all(w>=48 and h>=48 for w,h in self.hits)
  path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" role="img" aria-labelledby="title desc"><title id="title">{esc(title)}</title><desc id="desc">{esc(desc)}</desc>'+''.join(self.svg)+'</svg>\n')

def split_panels(b,panels,w,available):
 result=[]
 for p in panels:
  if b.panel_height(p,w)<=available:result.append(p);continue
  current=dict(title=p['title'],fields=[],note='',paper=p.get('paper',False))
  for f in p['fields']:
   trial={**current,'fields':current['fields']+[f]}
   if b.panel_height(trial,w)>available and current['fields']:
    result.append(current);current=dict(title=p['title'] if b.scale>1 else p['title']+' · далее',fields=[],note='',paper=p.get('paper',False))
   current['fields'].append(f)
  current['note']=p.get('note','')
  if b.panel_height(current,w)>available:
   note=current['note'];current['note']='';result.append(current);current=dict(title='Примечание',fields=[],note=note)
  result.append(current)
 return result

def render(s,w,h,theme,stem,scale=1):
 narrow=w<600 or scale>1; rail=0 if narrow else 88;section=s.get('section',s['id'][0])
 b=Board(w,h,theme,scale); gutter=16 if narrow else 24
 top=(120+len(lines(s['title'],w-32,20*scale))*math.ceil(20*scale*1.45)) if scale>1 else (180 if narrow else 164)
 if scale==1:top+=max(0,len(lines(s['title'],w-rail-32,24))*math.ceil(24*1.45)-35)
 bottom=178 if scale>1 else (148 if narrow else 110)
 # Extra content previews for landscape use short chrome, not hidden fields.
 if h<500:top=112;bottom=84
 reserve=40 if scale>1 else 32
 available=h-top-bottom-reserve
 col=(w-gutter*2) if narrow else (min(356,w-rail-gutter*2) if w>=1000 else min(640,w-rail-gutter*2))
 panels=split_panels(b,[p for p in s['panels'] if not p.get('desktop_only') or (not narrow and w>=1000)],col,available)
 pages=[];page=[];y=top;x=rail+gutter;col_index=0
 for p in panels:
  pw=col if col_index==0 else min(640,w-x-gutter)
  ph=b.panel_height(p,pw)
  if y+ph>h-bottom-reserve and page:
   if not narrow and w>=1000 and col_index==0:
    col_index=1;x=rail+gutter+col+16;y=top;pw=min(640,w-x-gutter);ph=b.panel_height(p,pw)
   else:pages.append(page);page=[];y=top;x=rail+gutter;col_index=0;pw=col;ph=b.panel_height(p,pw)
  assert y+ph<=h-bottom-reserve,(s['id'],w,h,scale,p['title'],ph,available)
  page.append((x,y,pw,p));y+=ph+16
 if page:pages.append(page)
 manifests=[]
 for number,content in enumerate(pages,1):
  b=Board(w,h,theme,scale);t=b.t;b.rect(0,0,w,h,t['background'])
  if rail:
   b.rect(0,0,rail,h,t['surface']);
   for k,(lab,dest) in enumerate([('План','P'),('Инстр.','T'),('Настр.','S')]):
    yy=140+k*72;b.rect(8,yy,72,48,t['primary'] if section==dest else t['surface'],t['border'],8,True);b.text(16,yy+30,lab,14,t['onPrimary'] if section==dest else t['primary'],600)
  left=rail+gutter
  if h<500:
   b.text(left,28,s['id']+' · '+s['title'],18,weight=600,width=w-left-16)
   b.text(left,66,'МАКЕТ · Иллюстрация · продолжение '+str(number)+'/'+str(len(pages)),14,t['secondary'],width=w-left-16)
  else:
   b.text(left,36 if scale>1 else 30,'МАКЕТ' if scale>1 else 'DECO / ПЛАНЕР',14,t['primary'],600)
   title_y=120 if scale>1 else 76
   title_h=b.text(left,title_y,s['title'],20 if scale>1 else 24,weight=600,width=w-left-16)
   if scale==1:b.text(left,title_y+title_h+1,'МАКЕТ · '+s['id'] if scale>1 else 'МАКЕТ · '+s['id']+' · '+('Эталон в аннотации' if s.get('fixture') else 'Иллюстрация'),14,t['secondary'],width=w-left-16)
   if scale>1:b.button(w-156,8,140,'Меню')
   if scale==1:b.text(left,title_y+title_h+34,'Погружение 1 · OC / CCR' if section=='P' else 'Инструменты' if section=='T' else 'Настройки',14,t['secondary'])
  for x,y,pw,p in content:b.panel(x,y,pw,p)
  by=h-bottom+16;bw=min(w-left-gutter,440)
  if h<500:
   b.button(left, h-64,min(300,w-left-16),s['action'],True)
  else:
   b.button(left,by,bw,s['action'],s['state']!='calculating')
   if narrow and scale==1:
    ny=h-64
    for k,lab in enumerate(['План','Инстр.','Настройки']):
     nw=(w-32)/3;sel=section==['P','T','S'][k];b.rect(16+k*nw,ny,nw-4,48,t['primary'] if sel else t['surface'],t['border'],8,True);b.text(16+k*nw+6,ny+30,lab,14,t['onPrimary'] if sel else t['primary'],600)
   b.text(left,h-bottom-4,f'Срез {number}/{len(pages)}' if scale>1 else f'{number}/{len(pages)} · '+('Продолжение прокрутки' if number>1 else {'draft':'Черновик','ready':'Пример результата','empty':'Пустой план','invalid':'Ошибка ввода','calculating':'Расчёт…','stale':'Нужен пересчёт','error':'Ошибка расчёта','unavailable':'Недоступно','confirmation':'Подтверждение','drain':'Стравливание','impossible':'Невозможно','component-reference':'Компоненты','print-preview':'Печатный вид'}.get(s['state'],s['state'])),14,t['secondary'],width=w-left-16)
  name=stem+('' if number==1 else f'-{number:02}')
  path=DEST/(name+'.svg');desc=f"{s['id']}; {w}×{h}; {theme}; state={s['state']}; page {number}/{len(pages)}; scale={scale}; fixture={s.get('fixture')}; illustrative design, no live calculation; annotations in screens.md and flows.md"
  b.save(path,s['title'],desc)
  subprocess.run(['rsvg-convert',str(path),'-o',str(path.with_suffix('.png'))],check=True,capture_output=True)
  manifests.append(dict(id=name,screen=s['id'],svg=str(path.relative_to(OUT)),png=str(path.with_suffix('.png').relative_to(OUT)),width=w,height=h,theme=theme,text_scale=scale,page=number,pages=len(pages),state=s['state'],requirements=s['requirements'],scenario='flows.md#'+s['id'].lower(),fixture=s.get('fixture'),provenance=s['provenance'],font='Verdana fallback',field_count=b.field_count,bounds_checked=True,min_hit_target=48))
 return manifests

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--screens',nargs='*');parser.add_argument('--matrix',action='store_true');args=parser.parse_args()
 manifest_path=DEST/'manifest.json';manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else []
 ids=args.screens or [s['id'] for s in SCREENS]
 fresh=[]
 for s in SCREENS:
  if s['id'] not in ids:continue
  for mode,w,h in [('mobile',375,812),('desktop',1440,900)]:
   for theme in TOKENS:fresh+=render(s,w,h,theme,f"{s['id']}-{mode}-{theme}")
 if args.matrix:
  s=next(s for s in SCREENS if s['id']=='P02')
  for w,h in [(390,844),(844,390),(768,1024),(1024,768),(599,900),(600,900),(999,900),(1000,900)]:
   for theme in TOKENS:fresh+=render(s,w,h,theme,f'MATRIX-{w}x{h}-{theme}')
  for w,h in [(375,812),(600,900),(1000,900),(1440,900)]:fresh+=render(s,w,h,'light',f'MATRIX-{w}x{h}-text200',2)
 names={m['id'] for m in fresh};old=manifest;manifest=[m for m in manifest if (m['id'].startswith('MATRIX-') and not args.matrix) or (not m['id'].startswith('MATRIX-') and m['screen'] not in ids)]+fresh
 keep={m['id'] for m in manifest}
 for m in old:
  if m['id'] not in keep:
   for key in ['svg','png']:(OUT/m[key]).unlink(missing_ok=True)
 manifest_path.write_text(json.dumps(sorted(manifest,key=lambda x:x['id']),ensure_ascii=False,indent=2)+'\n')
 print('Rendered',len(fresh),'boards; total',len(manifest))
if __name__=='__main__':main()
