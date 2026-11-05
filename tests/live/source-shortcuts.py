#!/usr/bin/env python3
"""Live Lua source edit/Undo/crash recovery using only a private no-op binding."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
import hyprsource as h
runtime=h.Runtime();baseline=runtime.binds();previous_auto=runtime.autoreload_disabled()
label='SwiftShell source shortcut audit';old='CTRL + SUPER + F30';new='CTRL + SUPER + F31'
for value in baseline:
    assert not (value.get('modmask')==68 and value.get('key') in ('F30','F31')),'Native source audit keys are already assigned.'
with tempfile.TemporaryDirectory(prefix='swiftshell-source-shortcut-') as temp:
    folder=Path(temp);config=folder/'hypr';config.mkdir()
    source=config/'hyprland.lua'
    original='-- exact user-style fixture\nhl.bind("'+old+'",function() _G.__swiftshell_source_audit=(_G.__swiftshell_source_audit or 0)+1 end,{description="'+label+'"})\n'
    source.write_text(original);source.chmod(0o640)
    saved_state=os.environ.get('XDG_STATE_HOME');os.environ['XDG_STATE_HOME']=str(folder/'state')
    try:
        runtime.evaluate('_G.__swiftshell_source_audit=0;'+original)
        observed=runtime.binds();assert len(observed)==len(baseline)+1
        identifier=next(value['id'] for value in h.linked(observed,config).values() if value['description']==label)
        transaction=h.apply(identifier,['ctrl','super'],'F31',config,runtime)
        after=runtime.binds();target=next(value for value in after if value.get('description')==label)
        runtime.evaluate('debug.getregistry()['+str(target['arg'])+'](); assert(_G.__swiftshell_source_audit==1)')
        assert sorted(json.dumps(value,sort_keys=True) for value in after if value.get('description')!=label)==sorted(json.dumps(value,sort_keys=True) for value in baseline)
        assert source.stat().st_mode&0o777==0o640 and 'F31' in source.read_text()
        h.undo(runtime);assert source.read_text()==original and not runtime.autoreload_disabled()
        print('PASS native source span edit, original callback, unchanged unrelated bindings and exact Undo',flush=True)
        identifier=next(value['id'] for value in h.linked(runtime.binds(),config).values() if value['description']==label)
        child='''import os,sys\nfrom pathlib import Path\nsys.path.insert(0,sys.argv[1])\nimport hyprsource as h\noriginal=h.write_source\ndef interrupted(path,raw,expected):\n original(path,raw,expected)\n os._exit(27)\nh.write_source=interrupted\nh.apply(sys.argv[3],["ctrl","super"],"F31",Path(sys.argv[2]))\n'''
        result=subprocess.run([sys.executable,'-c',child,str(root/'shell/helpers'),str(config),identifier],capture_output=True,timeout=8)
        assert result.returncode==27,'Synthetic owner interruption did not reach the intended stage.'
        for _ in range(80):
            journals=[json.loads(path.read_text()) for path in h.state_root().glob('*.json') if path.name!='latest.json']
            if any(value.get('status')=='rolled-back' and value.get('id')!=transaction for value in journals) and source.read_text()==original and runtime.autoreload_disabled()==previous_auto:break
            time.sleep(.05)
        else:raise AssertionError('Independent source recovery did not finish.')
        after=runtime.binds()
        assert len(after)==len(baseline)+1
        assert sorted(json.dumps(value,sort_keys=True) for value in after if value.get('description')!=label)==sorted(json.dumps(value,sort_keys=True) for value in baseline)
        target=next(value for value in after if value.get('description')==label)
        assert target['key']=='F30'
        runtime.evaluate('debug.getregistry()['+str(target['arg'])+'](); assert(_G.__swiftshell_source_audit==2)')
        print('PASS independent helper-death recovery restores source, callback and original auto-reload policy',flush=True)
    finally:
        runtime.evaluate('hl.unbind('+h.lua(old)+'); hl.unbind('+h.lua(new)+'); _G.__swiftshell_source_audit=nil')
        runtime.autoreload(previous_auto)
        if saved_state is None:os.environ.pop('XDG_STATE_HOME',None)
        else:os.environ['XDG_STATE_HOME']=saved_state
assert runtime.binds()==baseline,'Native source audit changed an unrelated binding.'
print('PASS all original effective bindings preserved; no keyboard/game input or global compositor reload')
