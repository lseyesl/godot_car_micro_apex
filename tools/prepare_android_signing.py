#!/usr/bin/env python3
"""Restore the persistent CI debug key; never generate a replacement implicitly."""
import argparse
import base64
import binascii
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / 'config/android-debug-cert.sha256'
KEY = ROOT / 'build/android/debug.keystore'


def certificate_digest(key):
    result = subprocess.run(['keytool', '-exportcert', '-keystore', str(key),
                             '-storepass', 'android', '-alias', 'androiddebugkey'],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ValueError('Cannot read debug signing certificate; check key, alias and password')
    return hashlib.sha256(result.stdout).hexdigest()


def check_key(key, pin):
    expected = pin.read_text().strip().lower()
    if len(expected) != 64 or any(c not in '0123456789abcdef' for c in expected):
        raise ValueError('Invalid pinned signing certificate SHA-256')
    actual = certificate_digest(key)
    if actual != expected:
        raise ValueError('Signing certificate differs from the pinned certificate; refusing key rotation')
    return actual


def restore(encoded, destination=KEY, pin=PIN):
    if not encoded:
        raise ValueError('Missing ANDROID_DEBUG_KEYSTORE_BASE64 secret; no temporary signing key will be generated')
    try:
        data = base64.b64decode(''.join(encoded.split()), validate=True)
    except (binascii.Error, ValueError):
        raise ValueError('ANDROID_DEBUG_KEYSTORE_BASE64 is not valid base64') from None
    if not data:
        raise ValueError('Signing key is empty')
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        digest = check_key(temporary, pin)
        temporary.replace(destination)
        return digest
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-existing', action='store_true')
    args = parser.parse_args()
    try:
        digest = check_key(KEY, PIN) if args.check_existing else restore(os.environ.get('ANDROID_DEBUG_KEYSTORE_BASE64', ''))
    except (ValueError, OSError) as exc:
        raise SystemExit(str(exc)) from None
    (KEY.parent / 'signing-certificate.sha256').write_text(digest + '\n')
    print('Persistent Android debug signing certificate verified: ' + digest)


if __name__ == '__main__':
    main()
