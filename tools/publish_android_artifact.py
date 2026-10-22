#!/usr/bin/env python3
"""Publish a verified existing Android artifact, exclusively from Actions runners."""
import base64, hashlib, json, os, pathlib, re, subprocess, tempfile, zipfile

FILES = ('micro-apex-debug.apk', 'micro-apex-debug.apk.sha256', 'apk-info.txt', 'signing-certificate.sha256')

def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()

def api(repo, path):
    return json.loads(gh('api', f'repos/{repo}/{path}'))

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def require(condition, message):
    if not condition:
        raise ValueError(message)

def validate_files(directory, expected_sha, certificate):
    require(sorted(p.name for p in directory.iterdir()) == sorted(FILES), 'Unexpected artifact contents')
    apk = directory / FILES[0]
    require(digest(apk) == expected_sha, 'APK differs from the approved build SHA-256')
    require((directory / FILES[1]).read_text().split() == [expected_sha, FILES[0]], 'APK checksum file mismatch')
    require((directory / FILES[3]).read_text().strip() == certificate, 'Pinned debug certificate mismatch')
    info = (directory / FILES[2]).read_text()
    match = re.search(r"package: name='org.lseyesl.microapex' versionCode='(\d+)' versionName='([^']+)'", info)
    require(match is not None, 'Unexpected package/version information')
    with zipfile.ZipFile(apk) as archive:
        require(archive.testzip() is None, 'Corrupt APK ZIP entry')
        architectures = {n.split('/')[1] for n in archive.namelist() if n.startswith('lib/') and n.endswith('.so')}
        require(architectures == {'arm64-v8a'}, 'APK must contain only ARM64 native libraries')
    return match.groups()

def verify_assets(assets, directory):
    require(len({a['name'] for a in assets}) == len(assets), 'Duplicate Release assets')
    require(all(a['name'] in FILES for a in assets), 'Unexpected Release asset; inspect draft before retrying')
    for asset in assets:
        path = directory / asset['name']
        require(asset['state'] == 'uploaded' and asset['size'] == path.stat().st_size, 'Existing asset is incomplete or has a different size')
        require(asset.get('digest') == 'sha256:' + digest(path), 'Existing asset digest mismatch or unavailable; do not overwrite')

def tag_sha(repo, tag):
    # A missing tag is expected for an unpublished draft; all other failures stop.
    result = subprocess.run(['gh', 'api', f'repos/{repo}/git/ref/tags/{tag}'], text=True, capture_output=True)
    if result.returncode:
        require('HTTP 404' in result.stderr, 'Unable to inspect tag: ' + result.stderr)
        return None
    obj = json.loads(result.stdout)['object']
    for _ in range(5):
        if obj['type'] == 'commit':
            return obj['sha']
        require(obj['type'] == 'tag', 'Unexpected tag object')
        obj = api(repo, 'git/tags/' + obj['sha'])['object']
    raise ValueError('Too many annotated tag indirections')

def publish(repo, run_id, artifact_id, release_id, tag, build_sha, apk_sha):
    require(os.environ.get('GITHUB_ACTIONS') == 'true', 'Release asset uploads must run inside GitHub Actions, never cloud Codex')
    require(re.fullmatch(r'[\w.-]+/[\w.-]+', repo), 'Invalid repository')
    require(all(re.fullmatch(r'[1-9]\d*', x) for x in (run_id, artifact_id, release_id)), 'Invalid run/artifact/release ID')
    require(re.fullmatch(r'[0-9a-f]{40}', build_sha) and re.fullmatch(r'[0-9a-f]{64}', apk_sha), 'Invalid approved digest')
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', tag), 'Invalid release tag')
    subprocess.run(['git', 'check-ref-format', 'refs/tags/' + tag], check=True)
    run = api(repo, 'actions/runs/' + run_id)
    require(run['status'] == 'completed' and run['conclusion'] == 'success', 'Source build must have succeeded')
    require(run['repository']['full_name'] == repo and run['head_sha'] == build_sha, 'Source build repository/SHA mismatch')
    require(run['path'] == '.github/workflows/android-debug.yml', 'Source run is not the Android build workflow')
    jobs = api(repo, 'actions/runs/' + run_id + '/jobs?per_page=100')['jobs']
    require(any(s['name'] == 'Export and verify APK' and s['conclusion'] == 'success' for j in jobs for s in j['steps']), 'Original APK signing/manifest/alignment validation did not succeed')
    artifact = api(repo, 'actions/artifacts/' + artifact_id)
    require(not artifact['expired'] and artifact['workflow_run']['id'] == int(run_id) and artifact['workflow_run']['head_sha'] == build_sha, 'Artifact is expired or belongs to a different build')
    require(artifact['name'] == f"micro-apex-android-debug-{run['run_number']}", 'Unexpected APK artifact')
    release = api(repo, 'releases/' + release_id)
    require(release['tag_name'] == tag and release['target_commitish'] == build_sha and release['prerelease'], 'Draft tag/target/type mismatch')
    require(build_sha in release['body'] and apk_sha in release['body'], 'Release notes must identify the approved build and APK digest')
    existing_tag = tag_sha(repo, tag)
    require(existing_tag is None or existing_tag == build_sha, 'Existing tag points at a different commit; never move it')
    pin = api(repo, 'contents/config/android-debug-cert.sha256?ref=' + build_sha)
    certificate = base64.b64decode(pin['content']).decode().strip()
    require(re.fullmatch(r'[0-9a-f]{64}', certificate), 'Invalid source-build certificate pin')
    preset = api(repo, 'contents/export_presets.cfg?ref=' + build_sha)
    preset_text = base64.b64decode(preset['content']).decode()
    with tempfile.TemporaryDirectory() as temp:
        directory = pathlib.Path(temp)
        gh('run', 'download', run_id, '--repo', repo, '--name', artifact['name'], '--dir', temp)
        code, version = validate_files(directory, apk_sha, certificate)
        require(f'version/code={code}\n' in preset_text and f'version/name="{version}"' in preset_text, 'Artifact version differs from the source-build export preset')
        verify_assets(release['assets'], directory)
        existing_names = {a['name'] for a in release['assets']}
        missing = [n for n in FILES if n not in existing_names]
        require(release['draft'] or not missing, 'Published Release is incomplete; inspect it instead of changing it automatically')
        for name in missing:
            # No clobber: a failed/interrupted run is resumed only after checking assets above.
            gh('release', 'upload', tag, str(directory / name), '--repo', repo)
        release = api(repo, 'releases/' + release_id)
        require(len(release['assets']) == len(FILES), 'Missing uploaded Release assets')
        verify_assets(release['assets'], directory)
        if release['draft']:
            gh('release', 'edit', tag, '--repo', repo, '--draft=false', '--prerelease', '--latest=false')
        release = api(repo, 'releases/' + release_id)
        require(not release['draft'] and release['prerelease'], 'Release is not a public debug prerelease')
        require(tag_sha(repo, tag) == build_sha, 'Published tag differs from the actual source build')
        verify_assets(release['assets'], directory)
        summary = f"## Android debug prerelease\n\n{release['html_url']}\n\nBuild: {build_sha}\n\nAPK: {version} ({code}), ARM64\n\nSHA-256: {apk_sha}\n\nAndroid device acceptance remains unverified.\n\n"
        for asset in release['assets']:
            summary += f"- [{asset['name']}]({asset['browser_download_url']}), {asset['size']} bytes, {asset['digest']}\n"
        print(summary)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
                stream.write(summary)

if __name__ == '__main__':
    publish(*(os.environ[k] for k in ('GITHUB_REPOSITORY', 'SOURCE_RUN_ID', 'SOURCE_ARTIFACT_ID', 'RELEASE_ID', 'RELEASE_TAG', 'BUILD_SHA', 'APK_SHA256')))
