import base64
import hashlib
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value
signing = module('prepare_android_signing')
apk = module('verify_android_apk')

@unittest.skipUnless(shutil.which('keytool'), 'JDK keytool required')
class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.root = Path(cls.directory.name)
        cls.keys = []
        for i in range(2):
            path = cls.root / f'{i}.keystore'
            subprocess.run(['keytool', '-genkeypair', '-noprompt', '-keystore', str(path),
                            '-storepass', 'android', '-keypass', 'android', '-alias', 'androiddebugkey',
                            '-dname', 'CN=Signing Test', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '2'],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            cls.keys.append(path.read_bytes())
        cls.digest = signing.certificate_digest(cls.root / '0.keystore')
        cls.pin = cls.root / 'pin'; cls.pin.write_text(cls.digest)
    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()
    def test_two_clean_runners_restore_identical_key(self):
        for runner in ['runner-a', 'runner-b']:
            target = self.root / runner / 'debug.keystore'
            self.assertEqual(signing.restore(base64.b64encode(self.keys[0]).decode(), target, self.pin), self.digest)
            self.assertEqual(target.read_bytes(), self.keys[0])
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
    def test_missing_secret_fails_without_generation(self):
        target = self.root / 'absent.keystore'
        with self.assertRaisesRegex(ValueError, 'Missing'):
            signing.restore('', target, self.pin)
        self.assertFalse(target.exists())
    def test_wrong_certificate_preserves_existing_key(self):
        target = self.root / 'preserved.keystore'; target.write_bytes(self.keys[0])
        with self.assertRaisesRegex(ValueError, 'differs'):
            signing.restore(base64.b64encode(self.keys[1]).decode(), target, self.pin)
        self.assertEqual(target.read_bytes(), self.keys[0])
    def test_invalid_encoding_rejected(self):
        with self.assertRaisesRegex(ValueError, 'base64'):
            signing.restore('not a key!', self.root / 'invalid', self.pin)
    def test_corrupt_key_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Cannot read'):
            signing.restore(base64.b64encode(b'broken').decode(), self.root / 'corrupt', self.pin)
    def test_apk_signer_matches_pin(self):
        apk.validate_certificate('Signer #1 certificate SHA-256 digest: ' + self.digest, self.digest)
    def test_apk_with_other_or_missing_signer_rejected(self):
        for output in ['', 'Signer #1 certificate SHA-256 digest: ' + '0'*64,
                       'Signer #1 certificate SHA-256 digest: '+self.digest+'\nSigner #2 certificate SHA-256 digest: '+self.digest]:
            with self.assertRaises(ValueError): apk.validate_certificate(output, self.digest)

if __name__ == '__main__': unittest.main()
