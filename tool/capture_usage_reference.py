"""Independent high precision quadrature over independently captured schedules.
No Dart quantities or usage outputs are read. Physical rows have source hashes.
"""
import hashlib
import json
from pathlib import Path
import mpmath as mp
mp.mp.dps=70
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'packages/deco_core/test/fixtures/independent'

def expected(segments, context, rates):
    amounts=[]
    groups={}
    bottom=mp.mpf(0)
    for segment in segments:
        t=mp.mpf(str(segment['duration_min']))
        entered=segment['phase'] in ['levelTravel','levelHold']
        if entered: bottom+=t
        if segment['mode']=='ccr':
            use=t*mp.mpf(str(rates[2 if entered else 3]))
        else:
            a,b=map(lambda k:mp.mpf(str(segment[k])),['start_depth_m','end_depth_m'])
            surface,gradient=map(lambda k:mp.mpf(str(context[k])),['surface_bar','bar_per_metre'])
            use=mp.mpf(str(rates[0 if entered else 1]))*mp.quad(
                lambda u:(surface+gradient*(a+(b-a)*u/t))/mp.mpf('1.01325'),[0,t]) if t else mp.mpf(0)
        amounts.append(float(use))
        if segment['phase']=='decompression':
            i=round((segment['end_depth_m']-context['last_stop_m'])/context['step_m'])
            group=0 if i<2 else 1+(i-2)//5
            data=groups.setdefault(group,dict(duration=mp.mpf(0),depths=set()))
            data['duration']+=t;data['depths'].add(segment['end_depth_m'])
    return dict(segment_litres=amounts,total_litres=float(sum(map(mp.mpf,amounts))),
        bottom_min=float(bottom),stop_groups=[dict(duration_min=float(v['duration']),
            stop_count=len(v['depths']),shallowest_m=min(v['depths']),deepest_m=max(v['depths']))
            for _,v in sorted(groups.items(),reverse=True)])


def main():
    cases=[];sources={}
    name='buhlmann-oc-normalized-schedules.json'
    raw=(BASE/name).read_bytes();sources[name]=hashlib.sha256(raw).hexdigest()
    for index,row in enumerate(json.loads(raw)['cases']):
        segments=[]
        for segment in row['expected']['segments']:
            segments.append({k:segment[k] for k in ['start_depth_m','end_depth_m','duration_min','phase','oxygen','helium']})
            segments[-1]['mode']='oc'
        context=row['normalization'];rates=[20,15,.7,.5]
        cases.append(dict(id=f'oc-{index}',context=context,rates=rates,segments=segments,
            expected=expected(segments,context,rates)))
    name='buhlmann-bailout-normalized.json'
    raw=(BASE/name).read_bytes();sources[name]=hashlib.sha256(raw).hexdigest()
    for index,row in enumerate(json.loads(raw)['cases']):
        segments=[];time=0.
        for source in row['prefix']:
            s={k:source[k] for k in ['start_depth_m','end_depth_m','duration_min']}
            s.update(phase='levelHold' if s['start_depth_m']==s['end_depth_m'] else 'levelTravel',
                mode='ccr',oxygen=.18 if time>=25 and row['changed_diluent'] else .21,
                helium=.45 if time>=25 and row['changed_diluent'] else .35)
            time+=s['duration_min'];segments.append(s)
        for source in row['expected']['segments']:
            s={k:source[k] for k in ['start_depth_m','end_depth_m','duration_min','phase']}
            s.update(mode='oc' if source['setpoint_bar'] is None else 'ccr',
                oxygen=source['o2'],helium=source['he'])
            segments.append(s)
        context=dict(surface_bar=1.01325,bar_per_metre=.1,step_m=3,last_stop_m=3)
        rates=[20,15,.7,.5]
        cases.append(dict(id=f'ccr-bailout-{index}',context=context,rates=rates,
            segments=segments,expected=expected(segments,context,rates)))
    out=dict(schema_version=1,provenance=dict(kind='independent-quadrature-and-aggregation',
        mpmath=mp.__version__,precision_decimal_digits=70,source_sha256=sources,
        generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        command='local/oracles/python-env/bin/python tool/capture_usage_reference.py'),
        segment_litre_tolerance=1e-8,quantity_tolerance=1e-8,cases=cases)
    (BASE/'gas-usage-quadrature.json').write_text(json.dumps(out,indent=2)+'\n')
    print(f'Captured{len(cases)} independent usage profiles')

if __name__=='__main__':main()
