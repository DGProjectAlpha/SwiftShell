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
def state():return json.loads(subprocess.check_output(command+['diagnostics'],text=True))
def wait(predicate):
    for _ in range(100):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Settings page did not become ready')
original=state()
try:
    for category in ['appearance','bar','spotlight','wallpaper','displays','workspaces','shortcuts','defaultApps','audio','network','power','notifications','weather']:
        subprocess.run(command+['settings',category],check=True)
        wait(lambda:state()['category']==category and state()['window'] and state()['window']['pageStatus']==1 and not state()['windowBusy'])
        assert not state()['windowError'],state()['windowError']
        print('PASS native Settings category:',category,flush=True)
finally:
    subprocess.run(command+['settings',original['category']],check=True)
    wait(lambda:not state()['windowBusy'])
    if not original['settingsOpen']:
        subprocess.run(command+['window','close'],check=True)
        wait(lambda:not state()['settingsOpen'])
    wait(lambda:state()['settingsPersistence']=='ready')
