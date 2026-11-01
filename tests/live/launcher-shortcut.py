#!/usr/bin/env python3
"""Opt-in real Super+Space test. Requires the explicitly approved handoff."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc
parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True)
parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def diagnostics():return json.loads(command('diagnostics'))
def wait(predicate):
    for _ in range(80):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Global shortcut did not reach expected launcher state')
def focus(name):assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(name)+'}))').strip()=='ok'
monitors=json.loads(ipc('j/monitors'))
original=next(m['name'] for m in monitors if m['focused'])
bindings=json.loads(ipc('j/binds'))
assert len([b for b in bindings if b['modmask']==64 and b.get('key','').lower()=='space' and not b['submap']])==1,'Expected a single approved binding'
command('launcher','close')
try:
    with tempfile.TemporaryDirectory(prefix='swiftshell-keyboard-test-') as directory:
        directory=Path(directory)
        protocol=ROOT/'tests/protocols/virtual-keyboard-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(directory/'keyboard-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(directory/'keyboard-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(directory),str(ROOT/'tests/helpers/launcher-keyboard.c'),str(directory/'keyboard-protocol.c'),'-o',str(directory/'keyboard'),'-lwayland-client','-lxkbcommon'],check=True)
        def key(action):subprocess.run([str(directory/'keyboard'),action],check=True)
        for monitor in monitors:
            focus(monitor['name']);time.sleep(.2)
            for _ in range(2):
                key('toggle');wait(lambda:diagnostics()['launcherOpen'] and diagnostics()['launcherHasFocus'])
                assert diagnostics()['launcherOutput']==monitor['name']
                key('toggle');wait(lambda:not diagnostics()['launcherOpen'])
            key('toggle');wait(lambda:diagnostics()['launcherOpen'] and diagnostics()['launcherHasFocus'])
            key('escape');wait(lambda:not diagnostics()['launcherOpen'])
            print('PASS actual Super+Space open/repeat toggle and Escape on',monitor['name'],flush=True)
finally:
    command('launcher','close')
    focus(original)
