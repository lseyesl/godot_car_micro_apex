#!/usr/bin/env bash
# Requires matching Godot 4.7 templates, Java 17+, SDK 36 / build-tools 36.0.0.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
godot_bin="${GODOT_BIN:-godot}"
engine_version="$("$godot_bin" --version)"
[[ "$engine_version" == 4.7.stable* ]] || { echo "Godot 4.7 stable is required." >&2; exit 1; }
mkdir -p build/android
if [ ! -f build/android/debug.keystore ]; then
  python3 tools/prepare_android_signing.py
else
  python3 tools/prepare_android_signing.py --check-existing
fi
import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT
"$godot_bin" --headless --path . --editor --import 2>&1 | tee "$import_log"
# Godot can return zero after a script parse error; do not package broken scripts.
python3 -c 'import pathlib,sys; text=pathlib.Path(sys.argv[1]).read_text(); sys.exit("Godot import reported errors; export stopped") if "SCRIPT ERROR:" in text or "ERROR:" in text else None' "$import_log"
"$godot_bin" --headless --path . --install-android-build-template --export-debug Android build/android/micro-apex-0.13.3-review.apk
"$godot_bin" --headless --path . --export-release 'Android Release Unsigned' build/android/micro-apex-0.13.3-release-unsigned.apk
# The release APK deliberately needs the publisher's signing key before installation.
test -s build/android/micro-apex-0.13.3-review.apk
test -s build/android/micro-apex-0.13.3-release-unsigned.apk
if [ -n "${ANDROID_HOME:-}" ]; then
  python3 tools/verify_android_apk.py build/android/micro-apex-0.13.3-review.apk --sdk "$ANDROID_HOME" --certificate-sha256-file config/android-debug-cert.sha256
fi
sha256sum build/android/micro-apex-0.13.3-*.apk > build/android/SHA256SUMS.txt
