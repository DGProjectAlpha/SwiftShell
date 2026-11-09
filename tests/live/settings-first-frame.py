#!/usr/bin/env python3
"""Check the existing Settings application's first painted frame on one output."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'shell/helpers'))
sys.path.insert(0,str(ROOT/'tests/live'))
from displayctl import ipc
from fullscreen_guard import require_idle_desktop


def run(output):
    command=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
    def call(*args):return subprocess.check_output(command+list(args),text=True,timeout=5)
    def state():return json.loads(call('diagnostics'))
    def wait(predicate):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            try:
                value=predicate()
                if value:return value
            except (ValueError,subprocess.CalledProcessError):pass
            time.sleep(.04)
        raise AssertionError('Settings did not reach the expected state.')
    monitor=next(item for item in json.loads(ipc('j/monitors')) if item['name']==output)
    active=json.loads(ipc('j/activewindow')).get('address')
    try:
        if wait(state)['settingsOpen']:
            call('window','close');wait(lambda:not state()['settingsOpen'])
        call('settingsOn',output)
        def presented():
            current=state()
            window=current.get('window') or {}
            frame=window.get('frame') or {}
            initial=frame.get('presentation')
            return initial if initial and initial['pageReady'] else None
        initial=wait(presented)
        assert initial['contentOpacity']==1 and initial['pageReady'], initial
        wait(lambda:not state()['windowBusy'])
        own=next(item for item in json.loads(ipc('j/clients')) if item['class']=='org.quickshell' and item['title']=='SwiftShell Settings')
        assert own['monitor']==monitor['id'], 'Settings opened on another monitor.'
        print(json.dumps({'output':output,'initialPresentation':initial,'finalBlurApplied':state()['blurRegionApplied']}))
    finally:
        call('window','close');wait(lambda:not state()['settingsOpen'])
        if active and any(item['address']==active for item in json.loads(ipc('j/clients'))):
            ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+active)+'}))')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live',action='store_true',required=True)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    require_idle_desktop()
    run(args.output)
