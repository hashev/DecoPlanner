"""Validate native bundles and package them without signing credentials."""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import zipfile
from pathlib import Path
from version import resolve


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def package(platform, source, output, tag, sha, certificate=None):
    version = resolve(tag)
    if len(sha) != 40 or any(c not in '0123456789abcdef' for c in sha):
        raise ValueError('Expected a full commit SHA')
    source, output = Path(source), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    if platform == 'windows':
        required = [source/'deco_planner.exe', source/'flutter_windows.dll', source/'data/icudtl.dat', source/'data/app.so',
                    source/'msvcp140.dll', source/'vcruntime140.dll', source/'vcruntime140_1.dll',
                    source/'MICROSOFT-RUNTIME-NOTICE.txt']
        if not all(p.is_file() for p in required):
            raise ValueError('Incomplete Windows runtime')
        if os.name == 'nt':
            executable = str((source/'deco_planner.exe').resolve()).replace("'", "''")
            command = f"[System.Diagnostics.FileVersionInfo]::GetVersionInfo('{executable}') | Select-Object FileVersion,FileMajorPart,FileMinorPart,FileBuildPart,FilePrivatePart | ConvertTo-Json"
            native = json.loads(subprocess.check_output(['powershell', '-NoProfile', '-Command', command], text=True))
            numbers = [native['FileMajorPart'], native['FileMinorPart'], native['FileBuildPart']]
            if numbers != list(map(int, version['name'].split('.'))) or native['FilePrivatePart'] != 0:
                raise ValueError('Windows numeric version differs from release tag')
            if native['FileVersion'] != f"{version['name']}+{version['code']}":
                raise ValueError('Windows string version differs from release identity')
        architectures = ['x86_64']
        name = f'DecoPlanner-{tag}-windows-x64.zip'
        with zipfile.ZipFile(output/name, 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(source.rglob('*')):
                if path.is_file():
                    archive.write(path, path.relative_to(source))
    elif platform == 'macos':
        if not (source/'Contents/Info.plist').is_file():
            raise ValueError('Incomplete macOS app')
        with (source/'Contents/Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        if (info.get('CFBundleIdentifier'), info.get('CFBundleShortVersionString'), str(info.get('CFBundleVersion'))) != ('io.github.hashev.decoplanner', version['name'], str(version['code'])):
            raise ValueError('macOS bundle identity or version differs from release')
        if tuple(map(int, info['LSMinimumSystemVersion'].split('.'))) > (12, 0, 0):
            raise ValueError('macOS deployment target exceeds 12.0')
        architectures = ['arm64', 'x86_64']
        binaries = 0
        for path in source.rglob('*'):
            if not path.is_file() or path.is_symlink():
                continue
            kind = subprocess.check_output(['file', '-b', str(path)], text=True)
            if 'Mach-O' in kind:
                slices = subprocess.check_output(['lipo', '-archs', str(path)], text=True).split()
                if not set(architectures).issubset(slices):
                    raise ValueError(f'Non-universal Mach-O: {path}')
                binaries += 1
        if not binaries:
            raise ValueError('No macOS executable found')
        name = f'DecoPlanner-{tag}-macos-universal.zip'
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(source), str(output/name)], check=True)
    else:
        if not certificate or len(certificate) != 64 or any(c not in '0123456789ABCDEF' for c in certificate):
            raise ValueError('Expected Android certificate SHA256')
        architectures = ['armeabi-v7a', 'arm64-v8a', 'x86_64']
        with zipfile.ZipFile(source) as apk:
            for abi in architectures:
                if f'lib/{abi}/libapp.so' not in apk.namelist():
                    raise ValueError(f'Missing APK ABI: {abi}')
        name = f'DecoPlanner-{tag}-android-universal.apk'
        shutil.copyfile(source, output/name)
    metadata = dict(version, sha=sha, platform=platform, architectures=architectures,
                    filename=name, sha256=digest(output/name),
                    signing=certificate if platform == 'android' else 'No trusted publisher signature')
    (output/f'{platform}.json').write_text(json.dumps(metadata, indent=2)+'\n')
    return metadata


def assemble(directory, tag, sha):
    directory = Path(directory)
    records = [json.loads((directory/f'{p}.json').read_text()) for p in ['windows', 'macos', 'android']]
    for record in records:
        if record['tag'] != tag or record['sha'] != sha or digest(directory/record['filename']) != record['sha256']:
            raise ValueError('Artifact identity or checksum mismatch')
    manifest = {'tag': tag, 'sha': sha, 'artifacts': records}
    path = directory/'manifest.json'
    path.write_text(json.dumps(manifest, indent=2)+'\n')
    files = sorted([directory/r['filename'] for r in records]+[path])
    (directory/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in files))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['windows', 'macos', 'android', 'assemble'])
    parser.add_argument('--source')
    parser.add_argument('--output', default='build/packages')
    parser.add_argument('--tag', required=True)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--certificate')
    args = parser.parse_args()
    if args.platform == 'assemble':
        assemble(args.output, args.tag, args.sha)
    else:
        if not args.source:
            parser.error('--source required')
        package(args.platform, args.source, args.output, args.tag, args.sha, args.certificate)
