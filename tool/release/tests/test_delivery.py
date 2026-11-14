import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package import package, assemble, digest
from publish import publish
from source import verify

SHA = 'a' * 40
TAG = 'v0.1.0'


class FakeGitHub:
    def __init__(self):
        self.release = None
        self.assets = {}
        self.finished = False
        self.fail_upload = False

    def releases(self):
        return [self.release] if self.release else []

    def create(self, tag, sha):
        self.release = {'id': 1, 'tag_name': tag, 'draft': True,
                        'body': f'Source commit: {sha}'}
        return self.release

    def refresh(self, release):
        return dict(self.release, assets=[{'name': n} for n in self.assets])

    def upload(self, release, files):
        for file in files:
            if file.name in self.assets:
                raise AssertionError('Overwrite attempted')
            self.assets[file.name] = file.read_bytes()
            if self.fail_upload:
                raise RuntimeError('Interrupted upload')

    def download(self, release, directory):
        for name, content in self.assets.items():
            (Path(directory)/name).write_bytes(content)

    def finish(self, release):
        self.finished = True
        self.release['draft'] = False


def fixture(root):
    records = []
    for platform, suffix in [('windows', '.zip'), ('macos', '.zip'), ('android', '.apk')]:
        path = root/(platform+suffix)
        path.write_bytes(platform.encode())
        record = dict(tag=TAG, sha=SHA, filename=path.name, sha256=digest(path), platform=platform)
        (root/(platform+'.json')).write_text(json.dumps(record))
        records.append(record)
    assemble(root, TAG, SHA)
    (root/'releases.md').write_text('Installation instructions')
    with (root/'SHA256SUMS').open('a') as f:
        f.write(f'{digest(root/"releases.md")}  releases.md\n')


class DeliveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        fixture(self.root)
        self.api = FakeGitHub()

    def test_publish_and_rerun_preserves_assets(self):
        self.assertEqual(publish(self.api, self.root, TAG, SHA), 'published')
        original = dict(self.api.assets)
        self.assertEqual(publish(self.api, self.root, TAG, SHA), 'already-published')
        self.assertEqual(self.api.assets, original)

    def test_partial_upload_stays_draft_and_can_resume(self):
        self.api.fail_upload = True
        with self.assertRaises(RuntimeError):
            publish(self.api, self.root, TAG, SHA)
        self.assertFalse(self.api.finished)
        self.assertTrue(self.api.release['draft'])
        self.api.fail_upload = False
        self.assertEqual(publish(self.api, self.root, TAG, SHA), 'published')

    def test_changed_draft_not_overwritten(self):
        self.api.fail_upload = True
        with self.assertRaises(RuntimeError):
            publish(self.api, self.root, TAG, SHA)
        name = next(iter(self.api.assets))
        self.api.assets[name] = b'changed'
        self.api.fail_upload = False
        with self.assertRaises(ValueError):
            publish(self.api, self.root, TAG, SHA)
        self.assertFalse(self.api.finished)

    def test_wrong_sha(self):
        with self.assertRaises(ValueError):
            publish(self.api, self.root, TAG, 'b'*40)
        self.assertIsNone(self.api.release)

    def test_remote_corruption(self):
        publish(self.api, self.root, TAG, SHA)
        self.api.assets['windows.zip'] = b'corrupted'
        with self.assertRaises(ValueError):
            publish(self.api, self.root, TAG, SHA)

    def test_assemble_rejects_missing_or_changed_artifact(self):
        (self.root/'android.apk').write_bytes(b'bad')
        with self.assertRaises(ValueError):
            assemble(self.root, TAG, SHA)
        (self.root/'android.json').unlink()
        with self.assertRaises(FileNotFoundError):
            assemble(self.root, TAG, SHA)

    def test_windows_requires_complete_runtime(self):
        source = self.root/'bundle'
        source.mkdir()
        with self.assertRaises(ValueError):
            package('windows', source, self.root/'out', TAG, SHA)
        for name in ['deco_planner.exe', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so', 'plugin.dll']:
            path=source/name; path.parent.mkdir(exist_ok=True); path.write_bytes(b'fixture')
        item=package('windows', source, self.root/'out', TAG, SHA)
        with zipfile.ZipFile(self.root/'out'/item['filename']) as z:
            self.assertIn('plugin.dll', z.namelist())
            self.assertIn('data/app.so', z.namelist())

    def test_android_requires_universal_and_certificate(self):
        apk=self.root/'input.apk'
        with zipfile.ZipFile(apk,'w') as z:
            z.writestr('lib/arm64-v8a/libapp.so', b'fixture')
        with self.assertRaises(ValueError):
            package('android', apk, self.root/'out', TAG, SHA, 'A'*64)
        with self.assertRaises(ValueError):
            package('android', apk, self.root/'out', TAG, SHA, None)

    def test_tag_outside_main_fails(self):
        with patch('source.subprocess.check_output', return_value=SHA+'\n'), patch('source.subprocess.run') as run:
            run.side_effect=[None, subprocess.CalledProcessError(1, 'merge-base')]
            with self.assertRaises(subprocess.CalledProcessError):
                verify(TAG, SHA)
        with self.assertRaises(ValueError):
            verify('v1.0.0;bad', SHA)

    def test_tag_different_commit_fails(self):
        with patch('source.subprocess.check_output', return_value='b'*40+'\n'), patch('source.subprocess.run'):
            with self.assertRaises(ValueError):
                verify(TAG, SHA)


if __name__ == '__main__':
    unittest.main()
