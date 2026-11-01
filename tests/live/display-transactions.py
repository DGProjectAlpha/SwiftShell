#!/usr/bin/env python3
"""Explicit live hardware test. Temporarily changes displays, always restores."""
import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True,help='authorize temporary live display changes')
args=parser.parse_args()
helper=Path(__file__).parents[2]/'shell/helpers/displayctl.py'
spec=importlib.util.spec_from_file_location('displayctl',helper)
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)

def call(action,outputs=None):
    argv=[sys.executable,str(helper),action]
    if outputs is not None:argv+=['--outputs',json.dumps(outputs)]
    result=json.loads(subprocess.check_output(argv,text=True))
    if not result.get('ok'):raise AssertionError(result.get('message'))
    return result

def verify_restored():
    for _ in range(50):
        if d.matches(original,d.snapshot()):return
        time.sleep(.1)
    raise AssertionError('Original monitor state was not restored')

original=d.snapshot()
assert len(original)==2, 'This workstation test expects two connected monitors'
try:
    changed=copy.deepcopy(original)
    for m in changed:m['y']+=20
    result=call('apply',changed)
    assert result['state']=='pending',result
    assert call('keep')['state']=='kept'
    assert d.matches(changed,d.snapshot())
    assert call('apply',original)['state']=='pending'
    assert call('keep')['state']=='kept'
    verify_restored()
    print('PASS live Apply / Keep on both monitors',flush=True)
    assert call('apply',changed)['state']=='pending'
    assert call('revert')['state']=='reverted'
    verify_restored()
    print('PASS live explicit Revert',flush=True)
    for output in original:
        for label,patch in [('mode',{'width':1280,'height':720,'refresh':60,'scale':1}),
                            ('scale',{'scale':1 if output['scale']!=1 else 1.25}),
                            ('rotation',{'transform':1})]:
            trial=copy.deepcopy(original)
            selected=next(m for m in trial if m['name']==output['name'])
            selected.update(patch)
            result=call('apply',trial)
            assert result['state']=='pending',(output['name'],label,result)
            assert d.matches(trial,d.snapshot())
            assert call('revert')['state']=='reverted'
            verify_restored()
            # Confirm that 10-bit/color settings were not reset by geometry changes.
            assert [m['format'] for m in d.snapshot()]==[m['format'] for m in original]
            print('PASS live',output['name'],label,'and recovery',flush=True)
    assert call('apply',changed)['state']=='pending'
    time.sleep(d.TIMEOUT+1)
    verify_restored()
    print('PASS independent confirmation timeout',flush=True)
    # A temporary parent invokes the bridge and exits, reproducing a shell crash.
    code='import subprocess,sys; subprocess.check_call(sys.argv[1:],stdout=subprocess.DEVNULL)'
    subprocess.check_call([sys.executable,'-c',code,sys.executable,str(helper),'apply','--outputs',json.dumps(changed)])
    verify_restored()
    print('PASS independent owner-exit recovery',flush=True)
finally:
    state=call('status')
    if state.get('state') in ('pending','applying','reverting','recovery-failed'):call('revert')
    if not d.matches(original,d.snapshot()):
        call('apply',original);call('keep')
    verify_restored()
print('PASS final original monitor modes, scale, rotation, positions and color formats restored',flush=True)
