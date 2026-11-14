"""Verify APK identity, version and signing certificate using Android SDK tools."""
import argparse
import os
import re
import subprocess
from pathlib import Path
from version import resolve


def verify(apk, tag, expected):
    version = resolve(tag)
    if not re.fullmatch(r'[A-Fa-f0-9]{64}', expected):
        raise ValueError('Missing or invalid expected Android certificate')
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
    versions = [p for p in (sdk/'build-tools').iterdir() if re.fullmatch(r'\d+\.\d+\.\d+', p.name)]
    tools = max(versions, key=lambda p: tuple(map(int, p.name.split('.'))))
    cert = subprocess.check_output([str(tools/'apksigner'), 'verify', '--verbose', '--print-certs', apk], text=True)
    fingerprints = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)', cert)
    if [p.upper() for p in fingerprints] != [expected.upper()]:
        raise ValueError('Unexpected signing certificate')
    badging = subprocess.check_output([str(tools/'aapt'), 'dump', 'badging', apk], text=True)
    match = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not match or match.groups() != ('io.github.hashev.decoplanner', str(version['code']), version['name']):
        raise ValueError('APK applicationId or version differs from release identity')
    print('APK signature, applicationId and version verified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk')
    parser.add_argument('--tag', required=True)
    args = parser.parse_args()
    verify(args.apk, args.tag, os.environ['ANDROID_CERT_SHA256'])
