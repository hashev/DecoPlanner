"""Rebuild the static legacy-to-target UI index. Run from any directory."""
import argparse,json,re,xml.etree.ElementTree as ET
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-root',type=Path,default=PROJECT/'local/reference');args=p.parse_args()
ROOT=args.reference_root
if not (ROOT/'analysis/manifest.json').exists():p.error('Optional local reference archive is required for regeneration')
OUT=PROJECT/'docs/ui'
controllers={'DP':'DP','OC':'W','CC':'R','Bailout':'Y','GasMixingTabPane':'K','GasMixingCostDialog':'X','HelpDialogPane':'f_0','SplashScreen':'SplashScreenLoader'}
rows=json.loads((ROOT/'analysis/maps/ui-outputs.json').read_text())
context={}
for p in (ROOT/'analysis/maps/inventory/resources/decoplanner').glob('*.fxml'):
 root=ET.parse(p).getroot()
 def visit(e,anc):
  tag=e.tag.split('}')[-1];a=e.attrib
  section=anc+[a.get('text','')] if tag in ['Tab','TitledPane'] else anc
  key=(tag,a.get('{http://javafx.com/fxml/1}id') or a.get('id'),a.get('text'),a.get('onAction'))
  context.setdefault((p.name,key),[]).append(section)
  for c in e:visit(c,section)
 visit(root,[])

def target(f,id,text,section):
 s=' '.join(section); key=(id+' '+text).lower()
 if f=='SplashScreen':return None,'exclude','Legacy splash, consent and licence wording are not reused.'
 if f=='HelpDialogPane':
  if 'license' in key or 'support' in s.lower() or 'gue' in text.lower() or 'about' in key:return None,'exclude','Original licence, brand and support destination are not the new product.'
  return 'S02','redesign','Offline glossary and explicit external help, not embedded legacy WebView.'
 if f=='DP':
  if id in ['checkForUpdatesButton','themeSilverRadioButton']:return None,'exclude','Legacy update service or hidden Silver theme.'
  if id=='resetPlanButton' or 'divePlans' in id or id=='generalTypeOfScubaChoiceBox':return 'P01','redesign','Plan lifecycle and mode selector.'
  if id=='mixingButton':return 'T01','redesign','Open tool catalogue; all seven tools reachable.'
  if any(x in s for x in ['Decompression Gas Sets','Tanks','Dive Profile Graphs','Color Theme']) or any(x in id.lower() for x in ['theme','tanks','decogassets','diveprofile','help','settings']):return 'S02','redesign','Library, presentation settings or contextual help.'
  return 'S01','redesign','Current-plan parameters with explicit apply/defaults.'
 if f=='GasMixingCostDialog':return 'T08','retain','Recipe-linked volumes and itemised cost.'
 if f=='GasMixingTabPane':
  tabs={'MOD & END':'T01','Density':'T02','Custom gas':'T03','Gas mixing':'T04','Top off':'T05','Tank equalizer':'T06','Tank conversion':'T07'}
  return next((v for k,v in tabs.items() if k in section),'T01'),'retain','Field preserved in its tool form; layouts redesigned.'
 if 'reserves' in key:return None,'exclude','Hidden by W/Y; no reserve algorithm recovered.'
 if 'surfaceinterval' in key or 'surface interval' in key or text in ['hours','minutes']:return 'P01','retain','Sequence and surface interval.'
 if any(x in key for x in ['rangeplan','plan nodeco','plannodeco','tables...']):return 'P08','retain','Range/alternative scenario and printable result.'
 if 'tissue' in key or 'profile' in key or 'ratio' in key:return 'P05','retain','Analysis with numerical alternative and legend.'
 if 'bailoutplanbutton' in key:return 'P07','retain','Create linked bailout from valid CCR result.'
 if 'input' in key or id=='depthPlanUnitLabel' or 'dive plan' in key:return ('P07' if f=='Bailout' else 'P02'),'retain','Level editor; explicit OC/CCR segment type in bailout.'
 if any(x in key for x in ['gasvolume','gastank','gastext','gas usage']):return 'P06','retain','One diver, no reserves; tank-dependent pressure.'
 if any(x in key for x in ['decogascontainer','decogasset','decogasswitch','decogasoxygen','decogashe','decogasminimum','decogaslost','decogaspo2','decogastable','decompression gas','deco. gas','diluent or']):return 'P03','retain','Applicable gas/setpoint switching controls.'
 if id=='planButton':return ('P07' if f=='Bailout' else 'P02'),'redesign','Explicit calculation action and state.'
 return 'P04','retain','Result context, container or table field; see source ancestors.'

items=[]
for n,row in enumerate(rows,1):
 f=Path(row['resource']).stem; id=row['id'] or '';text=row['text'] or ''
 key=(row['type'],row['id'],row['text'],row['action']);contexts=context.get((f+'.fxml',key),[[]]);section=contexts.pop(0) if len(contexts)>1 else contexts[0]
 screen,decision,reason=target(f,id,text,section)
 p=ROOT/row['resource'];lines=p.read_text().splitlines();needle=('fx:id="'+id+'"') if id else ('text="'+text.replace('&','&amp;').replace('"','&quot;')+'"')
 hits=[i for i,l in enumerate(lines,1) if needle in l];line=hits[0] if hits else None
 c=controllers[f];cp=ROOT/f'analysis/decompiled/source/decoplanner/{c}.java';cl=cp.read_text().splitlines() if cp.exists() else []
 ch=[i for i,l in enumerate(cl,1) if id and re.search(r'\b'+re.escape(id)+r'\b',l)]
 cap='gas-tool-workflows' if screen and screen.startswith('T') else 'planner-workspace'
 items.append({'id':f'L{n:04}', 'legacy_index':n-1,'source':row,'ancestors':section,'evidence':{'status':'static-fxml/controller','resource_line':line,'controller':str(cp.relative_to(ROOT)),'controller_field_lines':ch,'runtime_ui':'not-run'},'target':{'screen':screen,'component':id or text or row['type'],'decision':decision,'reason':reason,'spec':cap if screen else 'adaptive-planner-presentation','scenario':'flows.md#'+(screen or 'exclusions').lower(),'mockups':([f'mockups/{screen}-mobile-light.svg',f'mockups/{screen}-desktop-light.svg'] if screen else [])}})
dynamic=[]
anchors=[('DP','Next dive','P01','Повторное погружение'),('DP','addBailoutTab','P07','Связанный bailout'),('DP','diveProfileClearGraphButton_InputAction','P05','Очистка сравнений'),('R','bailoutPlanButton_InputAction','P07','Bailout из CCR'),('K','continuousBlendingOptionsChoiceBox.setItems','T04','Варианты непрерывного смешивания'),('K','partialPressureFillOrderChoiceBox.setItems','T04','Порядок O2/He'),('X','private void B()','T08','Пересчёт стоимости')]
for c in ['W','R','Y']:
 for a,sc,label in [('tablesButton_InputAction','P08','Диапазонные таблицы'),('rangePlanButton_InputAction','P08','Альтернативная range-ветвь'),('tissuePressureGraphButton_InputAction','P05','Графики тканей'),('setOnEditCommit','P02','Редактирование ячеек'),('clearProfileGraph','P05','Очистка профиля'),('getButton()','P02','Действия мыши в контексте строки'),('Printable...','P08','Печатный диалог'),('showSettingChanged','P04','Изменённые настройки')]:
  anchors.append((c,a,sc,label))
for c,a,sc,label in anchors:
 path=ROOT/f'analysis/decompiled/source/decoplanner/{c}.java'; lines=path.read_text().splitlines(); hits=[i for i,l in enumerate(lines,1) if a in l]
 if not hits: continue
 dynamic.append({'id':f'D{len(dynamic)+1:03}','label':label,'source':str(path.relative_to(ROOT)),'anchor':a,'lines':hits,'evidence':'static-controller','runtime_ui':'not-run','target':{'screen':sc,'component':label,'decision':'redesign','scenario':'flows.md#'+sc.lower(),'mockups':[f'mockups/{sc}-mobile-light.svg',f'mockups/{sc}-desktop-light.svg']}})
OUT.joinpath('feature-map.json').write_text(json.dumps({'schema_version':1,'source':'analysis/maps/ui-outputs.json','entries':items,'dynamic':dynamic,'gaps':['Original GUI not launched; appearance/event order inferred statically.','Range HTML/printing and full chart interactions lack legacy runtime confirmation.','VPM/altitude/SI defects and rare blending limits remain calculation gaps; see limitations.md.']},ensure_ascii=False,indent=2)+'\n')
print(len(items),'legacy entries')
