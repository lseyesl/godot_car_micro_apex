#!/usr/bin/env python3
"""Reproduce the checked Linux cloud SDK setup without writing into system directories."""
import hashlib, json, os, pathlib, re, shutil, subprocess, urllib.parse, zipfile
BASE=pathlib.Path('/workspace/.cloud-tools')
SDK=BASE/'android-sdk'
DOWNLOAD=BASE/'godot-4.7'
VERSION='4.7-stable'
TEMPLATE='Godot_v4.7-stable_export_templates.tpz'
SDK_ARCHIVE='commandlinetools-linux-13114758_latest.zip'
# Official repository2-3.xml checksum for cmdline-tools;19.0 (Linux).
SDK_SHA1='5fdcc763663eefb86a5b8879697aa6088b041e70'
def fetch(url,destination):
    destination.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['curl','-fsSL','--retry','3',url,'-o',str(destination)],check=True)
def digest(path,algorithm):
    with path.open('rb') as f:return hashlib.file_digest(f,algorithm).hexdigest()
DOWNLOAD.mkdir(parents=True,exist_ok=True)
url=f'https://github.com/godotengine/godot/releases/download/{VERSION}/'
fetch(url+'SHA512-SUMS.txt',DOWNLOAD/'SHA512-SUMS.txt')
sums={parts[1].lstrip('*'):parts[0] for line in (DOWNLOAD/'SHA512-SUMS.txt').read_text().splitlines() if len(parts:=line.split())==2}
if TEMPLATE not in sums:raise SystemExit('Official template checksum is missing')
archive=DOWNLOAD/TEMPLATE
if not archive.exists():fetch(url+TEMPLATE,archive)
if digest(archive,'sha512')!=sums[TEMPLATE]:raise SystemExit('Template SHA-512 mismatch; archive was not used')
target=BASE/'data/godot/export_templates/4.7.stable'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as source:
    for name in ['android_debug.apk','android_release.apk','android_source.zip','linux_debug.x86_64','linux_release.x86_64']:
        temporary=target/(name+'.tmp')
        temporary.write_bytes(source.read('templates/'+name))
        temporary.chmod(0o755)
        temporary.replace(target/name)
archive=BASE/'android-tools19.zip'
if not archive.exists():fetch('https://dl.google.com/android/repository/'+SDK_ARCHIVE,archive)
if digest(archive,'sha1')!=SDK_SHA1:raise SystemExit('Android CLI checksum mismatch; archive was not used')
with zipfile.ZipFile(archive) as source:
    for member in source.infolist():
        if member.is_dir():continue
        path=SDK/'cmdline-tools/19.0'/pathlib.Path(member.filename).relative_to('cmdline-tools')
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(source.read(member))
        if 'bin' in path.parts:path.chmod(0o755)
environment=os.environ.copy()
environment['ANDROID_USER_HOME']=str(BASE/'android-user')
pathlib.Path(environment['ANDROID_USER_HOME']).mkdir(parents=True,exist_ok=True)
args=[str(SDK/'cmdline-tools/19.0/bin/sdkmanager'),'--sdk_root='+str(SDK),'platform-tools','platforms;android-36','build-tools;36.0.0']
proxy=urllib.parse.urlparse(environment.get('HTTPS_PROXY',environment.get('https_proxy','')))
if proxy.hostname:args+=['--proxy=http','--proxy_host='+proxy.hostname,'--proxy_port='+str(proxy.port or 80)]
subprocess.run(args,input='y\n'*100,text=True,env=environment,check=True)
java=shutil.which('java')
if not java or not shutil.which('keytool') or not shutil.which('javac'):raise SystemExit('A full JDK 17+ (java, javac, keytool) must be installed for Gradle export')
java_root=pathlib.Path(java).resolve().parent.parent
settings=BASE/'config/godot/editor_settings-4.7.tres'
settings.parent.mkdir(parents=True,exist_ok=True)
body=settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for key,value in {'export/android/android_sdk_path':json.dumps(str(SDK)),'export/android/java_sdk_path':json.dumps(str(java_root)),'export/android/shutdown_adb_on_exit':'false'}.items():
    line=key+' = '+value
    pattern=r'^'+re.escape(key)+r'\s*=.*$'
    body=re.sub(pattern,lambda _:line,body,flags=re.MULTILINE) if re.search(pattern,body,re.MULTILINE) else body.rstrip()+'\n'+line+'\n'
settings.write_text(body)
print('Verified Godot templates, SDK 36, build-tools 36.0.0 and editor SDK paths.')
