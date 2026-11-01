#!/usr/bin/env python3
"""Open every real Settings category without changing device controls."""
import argparse
import json
from pathlib import Path
import subprocess
import time
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
for category in ['appearance','bar','wallpaper','displays','workspaces','shortcuts','audio','network','bluetooth','power','notifications']:
    subprocess.run(command+['settings',category],check=True)
    for _ in range(60):
        state=json.loads(subprocess.check_output(command+['diagnostics'],text=True))
        if state['category']==category and state['window'] and state['window']['pageStatus']==1:break
        time.sleep(.05)
    else:raise AssertionError('Settings page did not load: '+category)
    assert not state['windowError'],state['windowError']
    print('PASS native Settings category:',category,flush=True)
subprocess.run(command+['settings','displays'],check=True)
