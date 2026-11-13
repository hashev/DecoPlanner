"""Read-only audit of required reference dimensions, not line coverage.

Each dimension has applicable controls; this does not claim a Cartesian product
of every altitude, conservatism, unit, mode and surface interval.
"""
import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / 'packages/deco_core/test/fixtures/independent'


def cases(name):
    return json.loads((FIX / f'{name}.json').read_text())['cases']


def ids(name):
    rows = cases(name)
    result = {row['id'] for row in rows}
    assert len(rows) == len(result), f'Duplicate ID in {name}'
    return result


def main():
    si = [0, 45, 60, 180, 1440]
    transitions = ['oc-to-oc', 'ccr-to-ccr', 'ccr-to-oc', 'ccr-to-bailout', 'bailout-to-ccr']
    altitude = ['2000-acclimatized', '2000-travel', '8848-travel']
    buhlmann = {
        f'{model}-{mode}-alt{alt}'
        for model, mode, alt in itertools.product('BC', ['oc', 'ccr', 'bailout'], altitude)
    } | {
        f'{model}-{transition}-si{interval}'
        for model, transition, interval in itertools.product('BC', transitions, si)
    }
    assert ids('buhlmann-altitude-repetitive') == buhlmann
    assert ids('vpmb-full-altitude-repetitive') == {
        *(f'altitude-{alt}' for alt in altitude),
        *(f'repetitive-si{interval}' for interval in si),
    }
    assert ids('vpmb-ccr-altitude-repetitive') == {
        *(f'{mode}-altitude-{alt}' for mode, alt in itertools.product(['ccr', 'bailout'], altitude)),
        *(f'{transition}-si{interval}' for transition, interval in itertools.product(transitions[1:], si)),
    }
    assert ids('buhlmann-imperial-ccr-bailout') == {
        f'buhlmann-{model}-imperial-{variant}'
        for model, variant in itertools.product('bc', ['ccr-no-switch', 'ccr-switches', 'bailout-hold', 'bailout-end'])
    }
    oc = ids('buhlmann-oc-normalized-schedules')
    assert {'imperial-b-oc', 'imperial-c-oc', 'oc-b-multilevel', 'oc-c-multilevel',
            'oc-b-deco-switch', 'oc-c-deco-switch', 'oc-b-lost-oxygen', 'oc-c-lost-oxygen',
            'last-stop-double-b', 'minimum-stop-override-b', 'half-minute-minimum', 'descent-added'} <= oc
    for name, count in [('vpmb-multilevel-descending-units', 30), ('vpmb-redescent-normalized', 60)]:
        rows = cases(name)
        assert len(rows) == len(ids(name)) == count
        assert {r['conservatism'] for r in rows} == set(range(5))
        assert {r['units'] for r in rows} == {'metric', 'imperial'}
        assert {r['mode'] for r in rows} == {'oc', 'ccr', 'bailout'}
    assert len(cases('continuous-highs')) == 486
    assert len(cases('gas-usage-quadrature')) == 37
    assert len(cases('vdw-mpmath')) == 25
    # Fixture hashes, field assertions and source provenance are checked by
    # audit_numerical_fixtures; detailed VPM dimensions by their dedicated audits.
    print('PASS: B/C/VPM OC/CCR/bailout, altitude, SI0/45/60/180/1440, imperial and multilevel matrices; 486 blending, 37 usage and 25 EOS controls retained.')


if __name__ == '__main__':
    main()
