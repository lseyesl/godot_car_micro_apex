#!/usr/bin/env python3
"""Seal an explicit build style into resources; default ignores ambient developer environment."""
import argparse, json, os, pathlib
STYLES = ('original', 'bright_clay')
VARIABLE = 'MICRO_APEX_MODEL_STYLE'
ROOT = pathlib.Path(__file__).resolve().parents[1]

def prepare(root, style):
    if style not in STYLES:
        raise ValueError(f'Unsupported model style {style!r}; expected original or bright_clay')
    root = pathlib.Path(root)
    models = sorted((root / 'assets/models').glob('*.glb'))
    if not models:
        raise ValueError('No original model catalog found')
    if style == 'bright_clay':
        missing = [p.name for p in models if not (root / 'assets/styles/bright_clay/models' / p.name).is_file()]
        if missing:
            raise ValueError('Missing clay variants: ' + ', '.join(missing))
    preset = root / 'export_presets.cfg'
    lines = preset.read_text().splitlines()
    excluded = 'assets/styles/bright_clay/*' if style == 'original' else 'assets/models/*'
    for i, line in enumerate(lines):
        if line.startswith('include_filter='):
            entries = [x for x in line.split('=', 1)[1].strip('"').split(',') if x]
            if 'config/model_style.json' not in entries:
                entries.append('config/model_style.json')
            lines[i] = 'include_filter="' + ','.join(entries) + '"'
        elif line.startswith('exclude_filter='):
            entries = [x for x in line.split('=', 1)[1].strip('"').split(',') if x and x not in ('assets/models/*', 'assets/styles/bright_clay/*', 'assets/textures/surfaces/*')]
            lines[i] = 'exclude_filter="' + ','.join(entries + [excluded] + (['assets/textures/surfaces/*'] if style == 'bright_clay' else [])) + '"'
    data = {'format': 1, 'model_style': style, 'locked': True, 'model_ids': [p.stem for p in models]}
    payload = json.dumps(data, separators=(',', ':')) + '\n'
    (root / 'config/model_style.json').write_text(payload)
    preset.write_text('\n'.join(lines) + '\n')
    report = root / 'build/android/model-style.json'
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(payload)
    return data

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--style', choices=STYLES)
    group.add_argument('--from-environment', action='store_true')
    parser.add_argument('--project', type=pathlib.Path, default=ROOT)
    args = parser.parse_args()
    style = os.environ.get(VARIABLE) if args.from_environment else (args.style or 'original')
    if style not in STYLES:
        parser.error(f'{VARIABLE} must explicitly be original or bright_clay')
    print(json.dumps(prepare(args.project, style)))
if __name__ == '__main__':
    main()
