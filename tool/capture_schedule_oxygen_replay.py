"""Independent Baker quadrature on previously observed OC schedules.
Runs only optional reference Python; never imports or observes Dart outputs.
"""
import hashlib,json
from pathlib import Path
import mpmath as mp
from capture_oxygen_reference import exposure
ROOT=Path(__file__).resolve().parents[1];FIX=ROOT/'packages/deco_core/test/fixtures'
rows=[]
for path in sorted((FIX/'independent').glob('*-tissue-replay.json')):
    data=json.loads(path.read_text());cns=mp.mpf(0);otu=mp.mpf(0)
    for seg in data['expected']['segments']:
        a=(mp.mpf('1.01325')+mp.mpf(str(seg['start_depth_m']))/10)*mp.mpf(str(seg['o2_fraction']))/mp.mpf('1.01325')
        b=(mp.mpf('1.01325')+mp.mpf(str(seg['end_depth_m']))/10)*mp.mpf(str(seg['o2_fraction']))/mp.mpf('1.01325')
        dc,do=exposure(a,b,mp.mpf(str(seg['duration_min'])));cns+=dc;otu+=do
    rows.append(dict(id=path.stem.replace('-tissue-replay',''),schedule_fixture=path.name,
                     schedule_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                     cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55)))
output=dict(schema_version=1,policy='baker-seven-bands-si90-v1',
    provenance=dict(kind='independent-oxygen-quadrature-of-observed-schedules',solver='mpmath '+mp.__version__,
                    source='https://cdn.shopify.com/s/files/1/0838/3732/1530/files/Oxygen_Toxicity_Calculations.pdf?v=1710181583',
                    command='local/oracles/python-env/bin/python tool/capture_schedule_oxygen_replay.py'),
    scope='Oxygen integrals only; stop search/timing are observed schedules',cases=rows)
(FIX/'independent/oc-oxygen-replay.json').write_text(json.dumps(output,indent=2)+'\n')
probe=ROOT/'local/experiments/oxygen-band-equality-result.json'
legacy=json.loads(probe.read_text())
a=mp.mpf('.21');b=mp.mpf('40.1325')/mp.mpf('10.1325')*a
cns,otu=exposure(a,b,3)
reg=dict(schema_version=1,id='cns-clipped-lower-band-equality',
    correction='cns-movement-band-equality',request=dict(mode='oc',model='b',depth_from_m=0,depth_to_m=30,duration_min=3,oxygen_fraction=.21),
    provenance=dict(archive_sha256=legacy['archive_sha256'],legacy_result_sha256=hashlib.sha256(probe.read_bytes()).hexdigest(),
                    expected_origin='Independent mpmath quadrature of Baker table; not Dart output',
                    command='local/oracles/python-env/bin/python tool/capture_schedule_oxygen_replay.py'),
    legacy_observed=dict(cns_fraction=legacy['actual']['cns'],otu=legacy['actual']['otu']),
    expected=dict(cns_fraction=mp.nstr(cns,55),otu=mp.nstr(otu,55)))
(FIX/'regression/cns-clipped-lower-band-equality.json').write_text(json.dumps(reg,indent=2)+'\n')
print('Captured14 independent OC oxygen replays and proven clipped-band boundary correction')
print('Probe CNS: legacy',legacy['actual']['cns'],'independent',mp.nstr(cns,20))
