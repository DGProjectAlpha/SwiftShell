#!/usr/bin/env python3
"""Own clipboard window only. No clipboard text is read, persisted or logged."""
import argparse
import json
import os
from pathlib import Path
from displayctl import atomic, ipc, read, snapshot, logical_size
from windowctl import dispatch

TITLE='SwiftShell Clipboard'

def own_window(owner):
    return next((w for w in json.loads(ipc('j/clients')) if w.get('pid')==owner and w.get('class')=='org.quickshell' and w.get('title')==TITLE),None)

def run(action,owner,blur_enabled=True):
    path=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'swiftshell/clipboard-window.json'
    saved=read(path,{})
    result={'ok':True,'geometry':saved}
    if action=='prepare':
        code='if _G.__swiftshell_clipboard_rule then _G.__swiftshell_clipboard_rule:set_enabled(false) end; '
        code+=f'_G.__swiftshell_clipboard_owner={owner}; '
        code+='_G.__swiftshell_clipboard_rule=hl.window_rule({name="swiftshell-owned-clipboard",match={class="^org\\\\.quickshell$",title="^SwiftShell Clipboard$"},float=true,center=true,border_size=0,rounding=0,no_shadow=true,no_blur=false})'
        if ipc('eval '+code).strip()!='ok':raise ValueError('Window integration unavailable.')
        return result
    if action=='cleanup':
        ipc(f'eval if _G.__swiftshell_clipboard_owner=={owner} and _G.__swiftshell_clipboard_rule then _G.__swiftshell_clipboard_rule:set_enabled(false); _G.__swiftshell_clipboard_rule=nil end')
        return result
    w=own_window(owner)
    if action=='remember-close':
        if w:
            monitors=snapshot()
            m=next((m for m in monitors if m['enabled'] and m['x']<=w['at'][0]<m['x']+logical_size(m)[0]),None)
            if w.get('fullscreen',0)==0:atomic(path,{'x':w['at'][0],'y':w['at'][1],'width':w['size'][0],'height':w['size'][1],'monitor':m['name'] if m else ''})
        ipc(f'eval if _G.__swiftshell_clipboard_owner=={owner} and _G.__swiftshell_clipboard_rule then _G.__swiftshell_clipboard_rule:set_enabled(false); _G.__swiftshell_clipboard_rule=nil end')
        return result
    if not w:raise ValueError('Window not mapped yet.')
    selector=json.dumps('address:'+w['address'])
    if action=='mapped':
        if not w.get('floating'):dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
        if saved:
            monitors=snapshot()
            m=next((m for m in monitors if m['enabled'] and m['name']==saved.get('monitor')),next((m for m in monitors if m['enabled']),None))
            if m:
                mw,mh=map(round,logical_size(m))
                width=min(max(400,int(saved.get('width',480))),mw)
                height=min(max(440,int(saved.get('height',600))),mh)
                x=max(m['x'],min(int(saved.get('x',m['x'])),m['x']+mw-width))
                y=max(m['y'],min(int(saved.get('y',m['y'])),m['y']+mh-height))
                dispatch(f'hl.dsp.window.resize({{window={selector},x={width},y={height}}})')
                dispatch(f'hl.dsp.window.move({{window={selector},x={x},y={y}}})')
    if action in ('mapped','activate'):
        dispatch('hl.dsp.focus({window='+selector+'})')
        dispatch('hl.dsp.window.alter_zorder({window='+selector+',mode="top"})')
    if action in ('mapped','blur'):
        # Match native compositor blur to the shared appearance preference.
        dispatch('hl.dsp.window.set_prop({window='+selector+',prop="no_blur",value="'+('0' if blur_enabled else '1')+'"})')
    elif action not in ('activate',):raise ValueError('Unknown window action.')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','mapped','activate','blur','remember-close','cleanup']);parser.add_argument('--owner-pid',type=int,default=os.getppid());parser.add_argument('--blur-enabled',choices=['0','1'],default='1');args=parser.parse_args()
    try:result=run(args.action,args.owner_pid,args.blur_enabled=='1')
    except Exception:result={'ok':False,'message':'Clipboard window integration is unavailable.'}
    print(json.dumps(result,separators=(',',':')))
