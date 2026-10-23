#!/usr/bin/env python3
"""Export/test both Android resource packs locally; no APK build or remote actions."""
import argparse
import json
import os
import pathlib
import subprocess
import tempfile

from prepare_model_style import prepare

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(godot):
    output = ROOT / 'build/validation/styles'
    output.mkdir(parents=True, exist_ok=True)
    backup = {name: (ROOT / name).read_bytes()
              for name in ('config/model_style.json', 'export_presets.cfg')}
    results = []
    try:
        with tempfile.TemporaryDirectory(prefix='apex-style-export-') as temporary:
            workspace = pathlib.Path(temporary)
            env = dict(os.environ)
            for key, name in (('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'),
                              ('XDG_CACHE_HOME', 'cache')):
                path = workspace / name
                path.mkdir()
                env[key] = str(path)
            empty = workspace / 'empty'
            empty.mkdir()
            for style in ('original', 'bright_clay'):
                prepare(ROOT, style)
                pack = output / f'{style}.pck'
                with (output / f'export-{style}.log').open('w') as log:
                    result = subprocess.run(
                        [godot, '--headless', '--path', str(ROOT), '--export-pack', 'Android', str(pack)],
                        cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
                    if result.returncode:
                        raise RuntimeError(f'Export failed; see {log.name}')
                for ambient in ('original', 'bright_clay', 'invalid_ambient'):
                    result = subprocess.run(
                        [godot, '--headless', '--path', str(empty), '--main-pack', str(pack),
                         '--script', str(ROOT / 'tests/exported_model_style_probe.gd'), '--', style],
                        env=dict(env, MICRO_APEX_MODEL_STYLE=ambient), stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True)
                    (output / f'packed-{style}-{ambient}.log').write_text(result.stdout)
                    if result.returncode or 'failures=0' not in result.stdout:
                        raise RuntimeError(result.stdout)
                    print(result.stdout.strip(), flush=True)
                result = subprocess.run(
                    [godot, '--headless', '--path', str(empty), '--main-pack', str(pack),
                     '--script', str(ROOT / 'tests/exported_style_scene_probe.gd')],
                    env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                (output / f'packed-scenes-{style}.log').write_text(result.stdout)
                if result.returncode or result.stdout.count('PACKED_STYLE_SCENE ') != 6 or 'ERROR:' in result.stdout:
                    raise RuntimeError(result.stdout)
                print(f'PASS packed six tracks: {style}', flush=True)
                results.append({'style': style, 'bytes': pack.stat().st_size})
        (output / 'export-summary.json').write_text(json.dumps(results, indent=2) + '\n')
        print(results, flush=True)
    finally:
        for name, content in backup.items():
            (ROOT / name).write_bytes(content)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    run(parser.parse_args().godot)
