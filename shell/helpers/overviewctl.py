#!/usr/bin/env python3
"""Recoverable Alt+Tab handoff for the verified built-in cycle-next binding only.

Never rewrites Lua files, guesses opaque callbacks or removes unrelated chords.
The runtime handler falls back to cycle-next if SwiftShell is unavailable.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from displayctl import atomic, ipc

DESCRIPTION = 'SwiftShell · Workspace overview'
ORIGINAL_DESCRIPTION = 'Cycle to next window'
ORIGINAL_DISPATCHER = 'HL.Dispatcher(cycle_next)'
SOURCE_PATTERN = re.compile(r'hl\.bind\(\s*"ALT \+ Tab"\s*,\s*hl\.dsp\.window\.cycle_next\(\s*\)\s*,\s*\{\s*description\s*=\s*"Cycle to next window"\s*\}\s*\)')


def state_path():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'swiftshell/overview-shortcut.json'


def load():
    path=state_path()
    if not path.exists(): return {'version':1,'enabled':False}
    try: value=json.loads(path.read_text())
    except (OSError,ValueError): raise ValueError('Overview shortcut recovery state is invalid; no binding changed.') from None
    if not isinstance(value,dict) or value.get('version')!=1 or type(value.get('enabled')) is not bool or (value.get('enabled') and value.get('original')!='cycle-next'):
        raise ValueError('Overview shortcut recovery state is invalid; no binding changed.')
    return value


def bindings():
    data=json.loads(ipc('j/binds'))
    return [b for b in data if b.get('modmask')==8 and str(b.get('key','')).casefold()=='tab']


def known_original(items):
    if len(items)!=1:return False
    b=items[0]
    return not b.get('submap') and b.get('dispatcher')==ORIGINAL_DISPATCHER and b.get('description')==ORIGINAL_DESCRIPTION and (not b.get('arg') or re.fullmatch(r'[0-9]+',str(b.get('arg')))) and not any(b.get(k) for k in ['release','repeat','mouse','catch_all','non_consuming','transparent','ignore_mods','locked','longPress','auto_consuming'])


def owned(items):
    return len(items)==1 and not items[0].get('submap') and items[0].get('description')==DESCRIPTION and items[0].get('dispatcher')=='HL.Dispatcher(exec_cmd)' and not any(items[0].get(key) for key in ['release','repeat','mouse','catch_all','non_consuming','transparent','ignore_mods','locked','longPress','auto_consuming'])


def source_verified():
    path=Path.home()/'.config/hypr/config/binds.lua'
    try: text=path.read_text()
    except OSError:return False
    # Require one exact known declaration, rather than reconstructing a callback.
    lines='\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('--'))
    return len(SOURCE_PATTERN.findall(lines))==1


def evaluate(code):
    if ipc('eval '+code).strip()!='ok':raise ValueError('Hyprland did not accept the overview shortcut change.')


def original_code():
    return 'hl.bind("ALT + Tab",hl.dsp.window.cycle_next(),{description='+json.dumps(ORIGINAL_DESCRIPTION,ensure_ascii=False)+'})'


def handler_code():
    argv=[sys.executable,str(Path(__file__).resolve()),'invoke']
    return 'hl.bind("ALT + Tab",hl.dsp.exec_cmd('+json.dumps(shlex.join(argv),ensure_ascii=False)+'),{description='+json.dumps(DESCRIPTION,ensure_ascii=False)+'})'


def restore():
    saved=load(); current=bindings()
    if not saved['enabled']:
        return snapshot()
    if known_original(current):
        atomic(state_path(),{'version':1,'enabled':False})
        return snapshot()
    if not owned(current):raise ValueError('Alt+Tab changed outside SwiftShell; it was left untouched.')
    # Only our exact chord is removed; original source and unrelated bindings stay intact.
    evaluate('hl.unbind("ALT + Tab"); '+original_code()+'; _G.__swiftshell_overview_binding=nil')
    if not known_original(bindings()):raise ValueError('The original Alt+Tab shortcut could not be verified.')
    atomic(state_path(),{'version':1,'enabled':False})
    return snapshot()


def enable():
    saved=load();current=bindings()
    if owned(current):
        if not saved['enabled']:raise ValueError('An unrecognized overview shortcut exists; no binding changed.')
        return snapshot()
    if not known_original(current) or not source_verified():
        raise ValueError('Alt+Tab uses a custom binding. It was preserved; choose an unused shortcut in Settings.')
    # Recovery is durable before removing the verified built-in binding.
    atomic(state_path(),{'version':1,'enabled':True,'original':'cycle-next'})
    try:
        evaluate('hl.unbind("ALT + Tab"); _G.__swiftshell_overview_binding='+handler_code())
        if not owned(bindings()):raise ValueError('The overview shortcut could not be verified.')
    except Exception:
        try:
            current=bindings()
            if owned(current):evaluate('hl.unbind("ALT + Tab"); '+original_code())
            elif not current:evaluate(original_code())
            if known_original(bindings()):atomic(state_path(),{'version':1,'enabled':False})
        except Exception:pass
        raise
    return snapshot()


def snapshot():
    saved=load();current=bindings()
    return {'ok':True,'enabled':saved['enabled'],'active':owned(current),'canEnable':known_original(current) and source_verified(),
        'conflict':not owned(current) and not known_original(current)}


def invoke():
    shell=Path(__file__).resolve().parents[1]
    try:
        result=subprocess.run(['qs','ipc','-p',str(shell),'call','swiftshell','overview','shortcut'],capture_output=True,timeout=3)
        if result.returncode==0:return
    except (OSError,subprocess.TimeoutExpired):pass
    # A shell crash never leaves Alt+Tab dead. No shell text comes from the caller.
    evaluate('hl.dispatch(hl.dsp.window.cycle_next())')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['status','enable','restore','sync','invoke']);args=parser.parse_args()
    try:
        if args.action=='invoke':invoke();return
        path=state_path();path.parent.mkdir(parents=True,exist_ok=True)
        lock=open(path.with_suffix('.lock'),'a');os.chmod(path.with_suffix('.lock'),0o600);fcntl.flock(lock,fcntl.LOCK_EX)
        if args.action=='enable':result=enable()
        elif args.action=='restore':result=restore()
        elif args.action=='sync':result=enable() if load()['enabled'] else snapshot()
        else:result=snapshot()
        print(json.dumps(result))
    except (OSError,ValueError,subprocess.SubprocessError) as failure:
        print(json.dumps({'ok':False,'message':str(failure)}));raise SystemExit(1)


if __name__=='__main__':main()
