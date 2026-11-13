"""Independent OTU quadrature outside the supported CNS domain.
User decision: keep decompression and OTU, preserve CNS unavailable with reason.
"""
import hashlib,json
from pathlib import Path
import mpmath as mp
mp.mp.dps=65
ROOT=Path(__file__).resolve().parents[1]
rows=[]
for name,a,b,t in [('o2-20ft',mp.mpf(53)/33,mp.mpf(53)/33,10),
                   ('high-1.9',mp.mpf('1.9'),mp.mpf('1.9'),10),
                   ('cross-domain',mp.mpf('.21'),mp.mpf('1.7'),5)]:
    rate=lambda p:max(mp.mpf(0),2*(p-mp.mpf('.5')))**(mp.mpf(5)/6)
    if a==b:dose=t*rate(a)
    else:
        lo,hi=sorted([a,b]);active=max(lo,mp.mpf('.5'))
        dose=mp.quad(rate,[active,hi])*t/(hi-lo)
    rows.append(dict(id=name,start_ata=mp.nstr(a,60),end_ata=mp.nstr(b,60),
                     duration_min=t,cns_fraction=None,cns_reason='outsideModelDomain',otu=mp.nstr(dose,55)))
pdf=ROOT/'local/oracles/oxygen-sources/baker-oxygen.pdf'
result=dict(schema_version=1,policy='baker-seven-bands-si90-v1',
    provenance=dict(kind='primary-equation-independent-quadrature',source='https://cdn.shopify.com/s/files/1/0838/3732/1530/files/Oxygen_Toxicity_Calculations.pdf?v=1710181583',
                    source_sha256=hashlib.sha256(pdf.read_bytes()).hexdigest(),solver='mpmath '+mp.__version__,
                    command='local/oracles/python-env/bin/python tool/capture_oxygen_domain_reference.py'),
    decision='CNS domain status does not block decompression or independent OTU',cases=rows)
(ROOT/'packages/deco_core/test/fixtures/independent/oxygen-outside-cns-domain-mpmath.json').write_text(json.dumps(result,indent=2)+'\n')
print('Captured3 independent OTU examples with explicit unavailable CNS')
