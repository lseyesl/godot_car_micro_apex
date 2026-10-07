#!/usr/bin/env python3
"""Run gameplay checks and verify runner completion, not just process exit."""
import argparse, os, pathlib, re, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
p.add_argument('--balance',action='store_true')
a=p.parse_args()
logs=ROOT/'build'/'validation';logs.mkdir(parents=True,exist_ok=True)
suites={'steering_direction':r'STEERING_DIRECTION checks=\d+ failures=0','layout_density':r'LAYOUT_DENSITY failures=0','elevations':r'ELEVATIONS checks=\d+ failures=0','test_runner':r'RULE_TESTS checks=\d+ failures=0','handling':r'HANDLING checks=\d+ failures=0','integration':r'INTEGRATION checks=\d+ failures=0','curb_collisions':r'CURB_COLLISIONS checks=\d+ failures=0','career':r'CAREER checks=\d+ failures=0','product_flow':r'PRODUCT_FLOW checks=\d+ failures=0','district_layout':r'DISTRICT_LAYOUT checks=\d+ failures=0','camera_framing':r'CAMERA_FRAMING checks=\d+ failures=0','square_tracks':r'MINI_TRACKS failures=0','expansion_flow':r'EXPANSION_FLOW races=3 failures=0'}
if a.balance:suites['campaign_balance']=r'CAMPAIGN_BALANCE combinations=192 failures=0'
def run(name,args,marker=None,timeout=240):
    result=subprocess.run([a.godot,'--headless','--path',str(ROOT)]+args,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout)
    (logs/(name+'.log')).write_text(result.stdout)
    errors=[line for line in result.stdout.splitlines() if re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|^ERROR:',line)]
    # This suite deliberately corrupts the primary file to verify backup recovery.
    if name=='career':errors=[line for line in errors if not re.match(r'^ERROR: ConfigFile parse error at /tmp/apex-career-\d+\.cfg(?:\.broken(?:\.bak)?)?:',line)]
    if result.returncode or errors or (marker and not re.search(marker,result.stdout)):
        print(result.stdout);raise SystemExit(f'FAILED {name}; see {logs/name}.log')
    print('PASS',name, re.search(marker,result.stdout).group(0) if marker else '')
run('import',['--editor','--import'])
for name,marker in suites.items():run(name,['--script',f'res://tests/{name}.gd'],marker,900 if name=='campaign_balance' else 180)
print('All selected suites completed successfully.')
