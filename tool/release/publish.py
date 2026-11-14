"""Publish a complete release, leaving interrupted uploads as an unpublished draft."""
import json
import os
import subprocess
import tempfile
from pathlib import Path
from package import assemble, digest
from version import resolve


class GitHub:
    def __init__(self, repo):
        self.repo = repo

    def api(self, path, method='GET', data=None):
        args = ['gh', 'api', path, '--method', method]
        if data is not None:
            args += ['--input', '-']
        result = subprocess.run(args, input=json.dumps(data) if data is not None else None,
                                text=True, capture_output=True)
        if result.returncode:
            # Avoid echoing response bodies containing unexpected credentials.
            raise RuntimeError(f'GitHub API request failed: {method} {path}')
        return json.loads(result.stdout) if result.stdout.strip() else None

    def releases(self):
        pages = subprocess.check_output(['gh', 'api', f'repos/{self.repo}/releases?per_page=100', '--paginate', '--slurp'], text=True)
        return [release for page in json.loads(pages) for release in page]

    def create(self, tag, sha):
        return self.api(f'repos/{self.repo}/releases', 'POST', {
            'tag_name': tag, 'target_commitish': sha, 'name': f'DecoPlanner {tag}',
            'draft': True, 'body': f'Source commit: {sha}\n\nSee releases.md for installation and signature limitations.'})

    def upload(self, release, files):
        # gh fails on existing names; never use --clobber.
        subprocess.run(['gh', 'release', 'upload', release['tag_name'], '--repo', self.repo,
                        *map(str, files)], check=True)

    def refresh(self, release):
        return self.api(f"repos/{self.repo}/releases/{release['id']}")

    def download(self, release, directory):
        subprocess.run(['gh', 'release', 'download', release['tag_name'], '--repo', self.repo,
                        '--dir', str(directory)], check=True)

    def finish(self, release):
        return self.api(f"repos/{self.repo}/releases/{release['id']}", 'PATCH', {'draft': False})


def verify_remote(api, release, tag, sha, expected_names):
    if {a['name'] for a in release['assets']} != set(expected_names):
        raise ValueError('Remote asset set differs from complete release')
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        api.download(release, root)
        manifest = json.loads((root/'manifest.json').read_text())
        if manifest['tag'] != tag or manifest['sha'] != sha:
            raise ValueError('Remote release belongs to another source SHA')
        expected_files = {a['filename'] for a in manifest['artifacts']} | {'manifest.json', 'SHA256SUMS', 'releases.md'}
        if expected_files != set(expected_names):
            raise ValueError('Remote manifest is incomplete')
        checksums = {}
        for line in (root/'SHA256SUMS').read_text().splitlines():
            checksum, name = line.split('  ', 1)
            if name not in expected_names or '/' in name or '\\' in name:
                raise ValueError('Invalid checksum filename')
            checksums[name] = checksum
        if set(checksums) != set(expected_names)-{'SHA256SUMS'}:
            raise ValueError('Incomplete checksum list')
        for name, checksum in checksums.items():
            if digest(root/name) != checksum:
                raise ValueError('Remote checksum mismatch')
        for item in manifest['artifacts']:
            if digest(root/item['filename']) != item['sha256']:
                raise ValueError('Remote artifact differs from manifest')


def publish(api, directory, tag, sha):
    directory = Path(directory)
    manifest = json.loads((directory/'manifest.json').read_text())
    if manifest['tag'] != tag or manifest['sha'] != sha:
        raise ValueError('Local manifest identity mismatch')
    files = [directory/a['filename'] for a in manifest['artifacts']]
    files += [directory/'manifest.json', directory/'SHA256SUMS', directory/'releases.md']
    names = [p.name for p in files]
    releases = api.releases()
    existing = next((r for r in releases if r['tag_name'] == tag), None)
    if existing and not existing['draft']:
        verify_remote(api, api.refresh(existing), tag, sha, names)
        return 'already-published'
    current = resolve(tag)['code']
    for release in releases:
        if release['draft'] or release['tag_name'] == tag:
            continue
        try:
            older = resolve(release['tag_name'])['code']
        except ValueError:
            continue
        if current <= older:
            raise ValueError('New release version must exceed published versions')
    release = existing or api.create(tag, sha)
    if existing and f'Source commit: {sha}' not in (release.get('body') or ''):
        raise ValueError('Draft source SHA differs')
    remote = api.refresh(release)
    remote_names = {a['name'] for a in remote['assets']}
    if not remote_names.issubset(names):
        raise ValueError('Unexpected assets in draft')
    # Existing draft files must match this exact build before resuming upload.
    if remote_names:
        with tempfile.TemporaryDirectory() as temporary:
            api.download(remote, temporary)
            for name in remote_names:
                if digest(Path(temporary)/name) != digest(directory/name):
                    raise ValueError('Draft asset differs; refusing overwrite')
    missing = [p for p in files if p.name not in remote_names]
    if missing:
        api.upload(release, missing)
    verify_remote(api, api.refresh(release), tag, sha, names)
    api.finish(release)
    return 'published'


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', default='build/packages')
    parser.add_argument('--tag', required=True)
    parser.add_argument('--sha', required=True)
    args = parser.parse_args()
    print(publish(GitHub(os.environ['GITHUB_REPOSITORY']), args.directory, args.tag, args.sha))
