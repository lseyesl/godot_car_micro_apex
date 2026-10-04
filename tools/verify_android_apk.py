#!/usr/bin/env python3
"""Verify APK integrity, signing, alignment and installable manifest components."""
import argparse, os, pathlib, subprocess, xml.etree.ElementTree as ET, zipfile
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

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk',type=pathlib.Path)
    parser.add_argument('--sdk',default=os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT'))
    parser.add_argument('--build-tools',default='36.0.0')
    args=parser.parse_args()
    if not args.sdk:parser.error('Set ANDROID_HOME or supply --sdk')
    sdk=pathlib.Path(args.sdk); apk=args.apk.resolve(); build=sdk/'build-tools'/args.build_tools
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip():raise ValueError('Corrupt APK ZIP entry')
        if not any(n.startswith('lib/arm64-v8a/') and n.endswith('.so') for n in archive.namelist()):
            raise ValueError('Missing ARM64 native libraries')
    subprocess.run([str(build/'apksigner'),'verify','--verbose',str(apk)],check=True)
    subprocess.run([str(build/'zipalign'),'-c','-P','16','4',str(apk)],check=True)
    manifest=subprocess.check_output([str(sdk/'cmdline-tools/latest/bin/apkanalyzer'),'manifest','print',str(apk)],text=True)
    print(validate_manifest(manifest))
    print('APK_VALIDATION_OK')

if __name__=='__main__':main()
