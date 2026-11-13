"""Audit traceability, generated art, fixture claims and source preservation."""
import argparse,collections,hashlib,json,re,struct,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; UI=ROOT/'docs/ui'
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--with-reference',action='store_true');p.add_argument('--reference-root',type=Path,default=ROOT/'local/reference');args=p.parse_args();REF=args.reference_root
if args.with_reference and not (REF/'analysis/manifest.json').exists():p.error('Reference verification requested, but local archive is unavailable')
def read(p):return json.loads(p.read_text())
original=read(REF/'analysis/maps/ui-outputs.json') if args.with_reference else None; fm=read(UI/'feature-map.json'); screens=read(UI/'screen-model.json'); manifest=read(UI/'mockups/manifest.json')
assert len(fm['entries'])==455
if args.with_reference:assert len(original)==455
assert len({x['id'] for x in fm['entries']+fm['dynamic']})==len(fm['entries'])+len(fm['dynamic'])
ids={s['id'] for s in screens}; all_checks=[]
for i,e in enumerate(fm['entries']):
 assert e['legacy_index']==i
 if args.with_reference:assert e['source']==original[i]
 assert e['target']['decision'] in ['retain','redesign','exclude']
 if e['target']['decision']=='exclude':assert e['target']['reason'] and e['target']['screen'] is None
 else:assert e['target']['screen'] in ids
 for p in e['target']['mockups']:assert (UI/p).exists()
for e in fm['dynamic']:
 if args.with_reference:
  lines=(REF/e['source']).read_text().splitlines()
  assert all(e['anchor'] in lines[n-1] for n in e['lines'])
 assert e['target']['screen'] in ids
for m in manifest:
 svg=UI/m['svg'];png=UI/m['png'];tree=ET.parse(svg);r=tree.getroot()
 assert int(r.attrib['width'])==m['width'] and int(r.attrib['height'])==m['height']
 if png.exists():
  with png.open('rb') as f:
   assert f.read(8)==b'\x89PNG\r\n\x1a\n';chunk=f.read(16);w,h=struct.unpack('>II',chunk[8:16])
  assert (w,h)==(m['width'],m['height'])
 assert m['screen'] in ids and m['bounds_checked'] and m['min_hit_target']>=48
 assert r.find('{http://www.w3.org/2000/svg}title') is not None
 if args.with_reference and m['fixture']:assert (REF/'analysis/fixtures/results'/f"{m['fixture']}.json").exists()
groups=collections.defaultdict(list)
for m in manifest:groups[(m['screen'],m['width'],m['height'],m['theme'],m['text_scale'])].append(m)
for key,ms in groups.items():
 s=next(s for s in screens if s['id']==key[0]);expected=sum(len(p['fields']) for p in s['panels'])
 assert sum(m['field_count'] for m in ms)==expected,(key,'missing fields')
 assert sorted(m['page'] for m in ms)==list(range(1,len(ms)+1))
 charts=sum((UI/m['svg']).read_text().count('<polyline') for m in ms)
 assert charts==sum(2 for p in s['panels'] if p.get('chart')),(key,'missing chart')
for s in screens:
 for mode in ['mobile','desktop']:
  for theme in ['light','dark']:assert any(m['id']==f"{s['id']}-{mode}-{theme}" for m in manifest)
assert read(UI/'reports/contrast.json')['all_passed']
# Independently check numeric claims against saved original runtime data.
checks=[]
def claim(id,actual,expected,unit):
 assert abs(actual-expected)<.001,(id,actual,expected)
 checks.append(dict(fixture=id,actual=actual,displayed=expected,unit=unit))
if args.with_reference:
 r=read(REF/'analysis/fixtures/results/oc-air-30m-20min.json')['actual'][0]['result']
 for k,v,u in [('T',28,'min'),('l',7.333,'min'),('E',5.333,'min'),('Y',.05084,'fraction CNS'),('A',13.388,'OTU')]:claim('oc-air-30m-20min',r[k],v,u)
 assert [(x['G'],x['D'],x['B'],x['H']) for x in r['I'][1:-1]]==[(12,1,22,23),(9,1,23,24),(6,1,24,25),(3,2,25,27)]
 for k,v in [('K',.46),('C',59.2),('L',125.176)]:claim('oc-air-30m-20min',r['I'][1][k],v,'row '+k)
 for id,field,v in [('custom-gas-original-controller','customGasResultOxygenTextField',23.9),('custom-gas-original-controller','customGasResultHeliumTextField',27.2),('topoff-original-controller','topoffResultOxygenTextField',29.2),('equalizer-original-controller','equalizerResultTextField',171),('cost-original-controller','costLabel',1306)]:
  claim(id,float(read(REF/f'analysis/fixtures/results/{id}.json')['actual'][field]),v,'display')
# All repository-relative Markdown links must resolve; anchors are checked separately for feature flows.
links=0
for p in UI.rglob('*.md'):
 for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if '://' in link or link.startswith('#'):continue
  dest=link.split('#')[0]
  assert (p.parent/dest).exists(),(p,link)
  links+=1
for e in fm['entries']+fm['dynamic']:
 target=e['target'];sc=target['screen']
 if sc:assert '## '+sc+'\n' in (UI/'flows.md').read_text()
# Requirements -> screens -> boards -> scenario trace.
requirements={
 'planner-workspace':[['P01','P02','P07'],['P03','S01'],['P01'],['V-empty','V-invalid','V-calculating','V-stale','V-error','V-unavailable'],['P04','P05','P06'],['P05','P08']],
 'gas-tool-workflows':[['T01','T02','T03','T04','T05','T06','T07'],['T01','T02','T03'],['T04','T08','V-drain','V-impossible'],['V-invalid','V-tool-error','V-tool-stale']],
 'adaptive-planner-presentation':[['P02'],['V-components'],['V-components'],['P01','S02'],['P04','V-print']]}
coverage=[]
for cap,targets in requirements.items():
 spec=ROOT/f'openspec/specs/{cap}/spec.md'
 heads=re.findall(r'^### Requirement: (.+)',spec.read_text(),re.M);assert len(heads)==len(targets)
 for head,sids in zip(heads,targets):
  assert all(sid in ids for sid in sids)
  coverage.append(dict(capability=cap,requirement=head,screens=sids,boards=[m['id'] for m in manifest if m['screen'] in sids and m['page']==1],validation='static design + documented walkthrough; runtime not run'))
(UI/'reports/requirement-coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
protected=read(REF/'analysis/manifest.json')['distribution_files'] if args.with_reference else []
for e in protected:assert hashlib.sha256((REF/e['path']).read_bytes()).hexdigest()==e['sha256'],e['path']
report=dict(legacy_entries=len(fm['entries']),legacy_source_verified=args.with_reference,dynamic_scenarios=len(fm['dynamic']),included=sum(e['target']['decision']!='exclude' for e in fm['entries']),excluded=sum(e['target']['decision']=='exclude' for e in fm['entries']),screens=18,state_variants=len(screens)-18,boards=len(manifest),layout_groups=len(groups),markdown_links=links,requirements=len(coverage),fixture_checks=checks,protected_files_unchanged=len(protected) if args.with_reference else None,all_fields_preserved_in_each_layout=True,svg_dimensions_match=True,png_verification='all present previews checked' if all((UI/m['png']).exists() for m in manifest) else 'partial: generated PNG previews optional',all_passed=True,runtime_validation='not tested by static UX audit',reference_verification='passed' if args.with_reference else 'not requested; private sources and numeric claims not verified')
(UI/'reports/artifact-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='fixture_checks'},ensure_ascii=False))
