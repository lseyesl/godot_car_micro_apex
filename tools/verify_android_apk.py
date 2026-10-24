#!/usr/bin/env python3
"""Verify APK integrity, signing, alignment and installable manifest components."""
import argparse, json, re, os, pathlib, subprocess, xml.etree.ElementTree as ET, zipfile
ANDROID = '{http://schemas.android.com/apk/res/android}'

def validate_manifest(text, package='org.lseyesl.microapex'):
    root = ET.fromstring(text)
    if root.get('package') != package:
        raise ValueError('Unexpected Android package name')
    app = root.find('application')
    if app is None:
        raise ValueError('Missing application')
    authorities = {}
    for provider in app.findall('provider'):
        name = provider.get(ANDROID+'name', '')
        for authority in provider.get(ANDROID+'authorities', '').split(';'):
            if not authority or '${' in authority:
                raise ValueError(f'Invalid provider authority: {name}')
            if authority in authorities:
                raise ValueError(f'Duplicate provider authority {authority}: {authorities[authority]} and {name}')
            authorities[authority] = name
    def qualify(name):
        return package+name if name.startswith('.') else package+'.'+name if '.' not in name else name
    activities = {qualify(n.get(ANDROID+'name','')) for n in app.findall('activity')}
    launchers = []
    for node in list(app.findall('activity'))+list(app.findall('activity-alias')):
        for intent in node.findall('intent-filter'):
            actions = {n.get(ANDROID+'name') for n in intent.findall('action')}
            categories = {n.get(ANDROID+'name') for n in intent.findall('category')}
            if 'android.intent.action.MAIN' in actions and 'android.intent.category.LAUNCHER' in categories:
                if node.get(ANDROID+'exported') != 'true':
                    raise ValueError('Launcher must be exported')
                if node.tag == 'activity-alias' and qualify(node.get(ANDROID+'targetActivity','')) not in activities:
                    raise ValueError('Launcher alias points to missing activity')
                launchers.append(node.get(ANDROID+'name'))
    if not launchers:
        raise ValueError('No MAIN/LAUNCHER entry point')
    return {'package': package, 'version': root.get(ANDROID+'versionName'), 'launchers': launchers, 'providers': authorities}

def validate_certificate(output, expected):
    expected = expected.strip().lower()
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('Invalid expected signing certificate SHA-256')
    certificates = re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})\s*$', output, re.MULTILINE)
    if len(certificates) != 1 or certificates[0].lower() != expected:
        raise ValueError('APK signer does not match the pinned certificate')


def validate_model_style(archive, expected):
    data = json.loads(archive.read('assets/config/model_style.json'))
    if data.get('format') != 1 or data.get('locked') is not True or data.get('model_style') != expected or expected not in ('original', 'bright_clay', 'paper_craft'):
        raise ValueError('APK model style is not the expected sealed build style')
    ids = data.get('model_ids', [])
    if not ids or len(set(ids)) != len(ids) or any(not re.fullmatch(r'[a-z0-9_]+', x) for x in ids):
        raise ValueError('Invalid model catalog in package')
    selected = 'assets/assets/models/' if expected == 'original' else f'assets/assets/styles/{expected}/models/'
    excluded = [('assets/assets/models/' if style == 'original' else f'assets/assets/styles/{style}/') for style in ('original','bright_clay','paper_craft') if style != expected]
    names = set(archive.namelist())
    suffixes = ('.glb', '.glb.remap', '.glb.import')
    for model in ids:
        candidates = [selected + model + suffix for suffix in suffixes]
        if not any(name in names for name in candidates):
            raise ValueError('Missing selected model: ' + model)
        # Godot exports imported GLBs as .import metadata plus a .godot scene.
        for name in candidates[1:]:
            if name not in names:
                continue
            metadata = archive.read(name).decode('utf-8')
            target = re.search(r'^path="(res://[^"]+)"', metadata, re.MULTILINE)
            if not target or 'assets/' + target[1][6:] not in names:
                raise ValueError('Missing imported model target: ' + model)
    if any(any(n.startswith(prefix) for prefix in excluded) for n in names):
        raise ValueError('Unselected model style is also packaged')
    return data

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk',type=pathlib.Path)
    parser.add_argument('--sdk',default=os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT'))
    parser.add_argument('--certificate-sha256-file',type=pathlib.Path)
    parser.add_argument('--build-tools',default='36.0.0')
    parser.add_argument('--expected-model-style', choices=('original','bright_clay','paper_craft'))
    args=parser.parse_args()
    if not args.sdk:parser.error('Set ANDROID_HOME or supply --sdk')
    sdk=pathlib.Path(args.sdk); apk=args.apk.resolve(); build=sdk/'build-tools'/args.build_tools
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip():raise ValueError('Corrupt APK ZIP entry')
        if args.expected_model_style:
            print('MODEL_STYLE_VALIDATION_OK', validate_model_style(archive, args.expected_model_style))
        if not any(n.startswith('lib/arm64-v8a/') and n.endswith('.so') for n in archive.namelist()):
            raise ValueError('Missing ARM64 native libraries')
    signing=subprocess.check_output([str(build/'apksigner'),'verify','--verbose','--print-certs',str(apk)],text=True)
    if args.certificate_sha256_file:
        validate_certificate(signing,args.certificate_sha256_file.read_text())
    print(signing)
    subprocess.run([str(build/'zipalign'),'-c','-P','16','4',str(apk)],check=True)
    manifest=subprocess.check_output([str(sdk/'cmdline-tools/latest/bin/apkanalyzer'),'manifest','print',str(apk)],text=True)
    print(validate_manifest(manifest))
    print('APK_VALIDATION_OK')

if __name__=='__main__':main()
