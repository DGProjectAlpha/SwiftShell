#!/usr/bin/env python3
"""Opt-in IPC invocation/focus regression against the real running shell."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,snapshot

parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True)
parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def diagnostics():return json.loads(command('diagnostics'))
def wait(predicate):
    for _ in range(60):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Launcher state/focus did not reach the expected result')
def focus(name):
    assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(name)+'}))').strip()=='ok'
original=next(m['name'] for m in json.loads(ipc('j/monitors')) if m.get('focused'))
command('launcher','close')
try:
    for monitor in snapshot():
        if not monitor['enabled']:continue
        focus(monitor['name']);time.sleep(.2)
        for _ in range(3):
            subprocess.run([str(ROOT/'scripts/request-launcher.sh')],check=True)
            wait(lambda:diagnostics()['launcherOpen'] and diagnostics()['launcherHasFocus'])
            assert diagnostics()['launcherOutput']==monitor['name']
            subprocess.run([str(ROOT/'scripts/swiftshell'),'request-launcher'],check=True)
            wait(lambda:not diagnostics()['launcherOpen'])
        print('PASS scoped launcher invocation, repeat toggle and real input focus on',monitor['name'],flush=True)
finally:
    command('launcher','close')
    focus(original)
