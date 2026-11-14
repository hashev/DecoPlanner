import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_android import verify

CERT = 'A'*64
BADGING = "package: name='io.github.hashev.decoplanner' versionCode='1000' versionName='0.1.0'"


class VerifyAndroidTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        sdk = Path(self.temp.name)
        (sdk/'build-tools/36.0.0').mkdir(parents=True)
        (sdk/'build-tools/36.1.0-rc1').mkdir()
        self.env = patch.dict(os.environ, ANDROID_HOME=str(sdk))
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_valid_signature_and_version(self):
        with patch('verify_android.subprocess.check_output', side_effect=[
            f'Signer #1 certificate SHA-256 digest: {CERT.lower()}', BADGING]):
            verify('release.apk', 'v0.1.0', CERT)

    def test_wrong_certificate(self):
        with patch('verify_android.subprocess.check_output', return_value='Signer #1 certificate SHA-256 digest: '+'B'*64):
            with self.assertRaises(ValueError):
                verify('release.apk', 'v0.1.0', CERT)

    def test_missing_expected_certificate(self):
        with self.assertRaises(ValueError):
            verify('release.apk', 'v0.1.0', '')

    def test_wrong_identity_or_version(self):
        for bad in [BADGING.replace('io.github.hashev.decoplanner','com.example.app'),
                    BADGING.replace("'1000'", "'1'"), BADGING.replace("'0.1.0'", "'0.0.1'")]:
            with patch('verify_android.subprocess.check_output', side_effect=[
                'Signer #1 certificate SHA-256 digest: '+CERT, bad]):
                with self.assertRaises(ValueError):
                    verify('release.apk', 'v0.1.0', CERT)


if __name__ == '__main__':
    unittest.main()
