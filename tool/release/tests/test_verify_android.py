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

    def test_sdk37_scheme_labels(self):
        for label in ['V1 Signer:', 'V2 Signer:', 'V3 Signer:', 'V3.1 Signer:',
                      'V3.2 Signer:', 'V3 Signer #1:',
                      'Signer (minSdkVersion=24, maxSdkVersion=32)']:
            with self.subTest(label=label), patch('verify_android.subprocess.check_output', side_effect=[
                f'{label} certificate SHA-256 digest: {CERT.lower()}', BADGING]):
                verify('release.apk', 'v0.1.0', CERT)

    def test_duplicate_certificate_across_schemes(self):
        output = f'V2 Signer: certificate SHA-256 digest: {CERT}\nV3 Signer: certificate SHA-256 digest: {CERT}'
        with patch('verify_android.subprocess.check_output', side_effect=[output, BADGING]):
            verify('release.apk', 'v0.1.0', CERT)

    def test_different_certificate_in_any_scheme_is_rejected(self):
        for label in ['Signer #2', 'V3 Signer:']:
            output = f'Signer #1 certificate SHA-256 digest: {CERT}\n{label} certificate SHA-256 digest: '+ 'B'*64
            with self.subTest(label=label), patch('verify_android.subprocess.check_output', return_value=output):
                with self.assertRaises(ValueError):
                    verify('release.apk', 'v0.1.0', CERT)

    def test_missing_malformed_or_public_key_digest_is_rejected(self):
        for output in ['', f'V2 Signer: certificate SHA-256 digest: {CERT[:-1]}',
                       f'V2 Signer: public key SHA-256 digest: {CERT}']:
            with self.subTest(output=output), patch('verify_android.subprocess.check_output', return_value=output):
                with self.assertRaises(ValueError):
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
