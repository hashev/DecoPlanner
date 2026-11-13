"""Read-only fixture inventory: hashes, roles, provenance and assertion contracts.

Run from any directory with Python 3. No private oracle checkout is required.
This command never regenerates expectations or updates the reviewed snapshot.
"""
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'packages/deco_core/test/fixtures'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finite(value):
    if isinstance(value, float):
        assert math.isfinite(value), 'Nonfinite numeric expectation'
    elif isinstance(value, dict):
        for item in value.values():
            finite(item)
    elif isinstance(value, list):
        for item in value:
            finite(item)


def read(path):
    data = json.loads(path.read_text(), parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
    finite(data)
    return data


def main():
    ledger = read(ROOT / 'docs/models/numerical-fixtures.json')
    assert ledger['schema_version'] == 1
    reproduction = read(ROOT / 'docs/models/reference-reproduction.json')
    commands = reproduction['commands']
    assert len(commands) == 20
    assert len({entry['command'] for entry in commands}) == 20
    for entry in commands:
        assert entry['exit_code'] == 0 and entry['changed_fixtures'] == []
        generator = ROOT / entry['command'].split()[-1]
        assert digest(generator) == entry['generator_sha256'], generator
    for entry in reproduction['additional_repeated_captures']:
        assert digest(FIXTURES / 'independent' / entry['fixture']) == entry['fixture_sha256']
    rows = ledger['fixtures']
    actual = {str(p.relative_to(ROOT)) for p in FIXTURES.rglob('*.json')}
    assert len(rows) == len(actual) == len({r['path'] for r in rows})
    assert {r['path'] for r in rows} == actual, 'Unreviewed or missing fixture'
    for row in rows:
        path = ROOT / row['path']
        assert digest(path) == row['sha256'], f"Changed expectation: {row['path']}"
        data = read(path)
        assert sorted(data) == row['top_level_keys']
        assert data.get('schema_version') == row['schema_version']
        assert data.get('provenance') == row['provenance']
        assert {k: v for k, v in data.items() if 'tolerance' in k} == row['declared_tolerances']
        for contract in row['test_contracts']:
            assert digest(ROOT / contract['path']) == contract['sha256'], f"Assertion contract changed: {contract['path']}"
        if row['role'].startswith('independent-') or row['role'] == 'corrected-regression':
            assert row['test_contracts'], f"No executable comparison: {row['path']}"
        if row['role'] == 'corrected-regression-linked-to-independent-replay':
            provenance = data['provenance']
            independent = FIXTURES / 'independent' / provenance['independent_fixture']
            assert digest(independent) == provenance['independent_fixture_sha256']
            legacy = FIXTURES / 'legacy_baseline' / path.name.replace('-gas-label-corrected', '')
            assert digest(legacy) == provenance['legacy_fixture_sha256']
            assert data['expected'] == read(independent)['expected']
        # Verify generator linkage where captured. External-source hashes remain
        # preserved provenance; source reruns require the separate private env.
        provenance = data.get('provenance') or {}
        command = provenance.get('command', '')
        if provenance.get('generator_sha256') and command:
            generators = [part for part in command.split() if part.startswith('tool/') and part.endswith('.py')]
            assert len(generators) == 1, command
            assert digest(ROOT / generators[0]) == provenance['generator_sha256'], generators[0]
    print(f"PASS: {len(rows)} fixture files; complete inventory, hashes, finite numbers, provenance, field assertion contracts and linked regressions.")
    print(dict(sorted(Counter(row['role'] for row in rows).items())))


if __name__ == '__main__':
    main()
