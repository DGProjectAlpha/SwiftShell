#!/usr/bin/env python3
"""Scoped SwiftShell Settings integration. Never targets other applications."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
from displayctl import atomic, ipc, read, snapshot

TITLE='SwiftShell Settings'
HIDDEN='special:swiftshell-settings-hidden'


def own_window(owner):
    return next((w for w in json.loads(ipc('j/clients')) if w.get('pid')==owner and w.get('class')=='org.quickshell' and w.get('title')==TITLE),None)


def dispatch(expression):
    if ipc('eval hl.dispatch('+expression+')').strip()!='ok':
        raise ValueError('The window action was not accepted.')


def blur_capability():
    """Read-only capability probe shared by toplevel and layer surfaces."""
    result={'blurAvailable':False,'blurReason':'Backdrop blur is unavailable.'}
    # Protocol detection only; no global compositor setting is changed.
    try:
        protocol=subprocess.run(['wayland-info'],capture_output=True,text=True,timeout=3,check=True).stdout
        option=json.loads(ipc('j/getoption decoration:blur:enabled'))
        enabled=option.get('int',option.get('bool',False))
        result['blurAvailable']='ext_background_effect_manager_v1' in protocol and bool(enabled)
        result['blurReason']='Compositor backdrop blur' if result['blurAvailable'] else 'Backdrop blur is disabled in your desktop settings.'
    except (OSError,subprocess.SubprocessError,ValueError):pass
    return result


def run(action,owner):
    if action=='capabilities':return dict(ok=True,**blur_capability())
    folder=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'swiftshell'
    geometry=folder/'settings-window.json'
    minimized=folder/f'settings-minimized-{owner}.json'
    saved=read(geometry,{})
    result={'ok':True,'geometry':saved,'blurAvailable':False,'blurReason':'Backdrop blur is unavailable.'}
    if action=='prepare':
        result.update(blur_capability())
        # Temporary rule scoped to this exact application/title. No config file writes.
        code='if _G.__swiftshell_settings_rule then _G.__swiftshell_settings_rule:set_enabled(false) end; '
        code+=f'_G.__swiftshell_settings_owner={owner}; '
        code+='_G.__swiftshell_settings_rule=hl.window_rule({name="swiftshell-owned-settings",match={class="^org\\\\.quickshell$",title="^SwiftShell Settings$"},float=true,center=true,border_size=0,rounding=0,no_shadow=true,no_blur=false})'
        if ipc('eval '+code).strip()!='ok':raise ValueError('Could not prepare the floating Settings window.')
        return result
    w=own_window(owner)
    if action=='cleanup':
        ipc(f'eval if _G.__swiftshell_settings_owner=={owner} and _G.__swiftshell_settings_rule then _G.__swiftshell_settings_rule:set_enabled(false); _G.__swiftshell_settings_rule=nil end')
        return result
    if w is None:
        if action in ('remember','status'):return result
        raise ValueError('Settings window is not available yet.')
    selector=json.dumps('address:'+w['address'])
    def remember():
        if w.get('fullscreen',0)==0 and not w.get('workspace',{}).get('name','').startswith('special:'):
            monitors=snapshot()
            monitor=next((m['name'] for m in monitors if m['x']<=w['at'][0]<m['x']+m['width']/m['scale']), '')
            atomic(geometry,{'x':w['at'][0],'y':w['at'][1],'width':w['size'][0],'height':w['size'][1],'monitor':monitor})
    if action=='remember':remember()
    elif action=='mapped':
        if not w.get('floating'):dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
        if saved:
            monitors=snapshot()
            m=next((m for m in monitors if m['name']==saved.get('monitor') and m['enabled']),next((m for m in monitors if m['enabled']),None))
            if m:
                width=min(max(640,int(saved.get('width',1000))),round(m['width']/m['scale']))
                height=min(max(440,int(saved.get('height',700))),round(m['height']/m['scale']))
                x=max(m['x'],min(int(saved.get('x',m['x'])),m['x']+round(m['width']/m['scale'])-width))
                y=max(m['y']+28,min(int(saved.get('y',m['y']+40)),m['y']+round(m['height']/m['scale'])-height))
                dispatch(f'hl.dsp.window.resize({{window={selector},x={width},y={height}}})')
                dispatch(f'hl.dsp.window.move({{window={selector},x={x},y={y}}})')
        dispatch('hl.dsp.focus({window='+selector+'})')
        dispatch('hl.dsp.window.alter_zorder({window='+selector+',mode="top"})')
    elif action in ('blur-on','blur-off'):
        # Hyprland also auto-blurs translucent windows; removing the protocol
        # region alone does not disable it. Override only this exact window.
        value='0' if action=='blur-on' else '1'
        dispatch('hl.dsp.window.set_prop({window='+selector+',prop="no_blur",value="'+value+'"})')
    elif action=='maximize':
        remember()
        old=w.get('fullscreen',0)
        dispatch('hl.dsp.window.fullscreen({window='+selector+',mode="maximized",action="toggle"})')
        for _ in range(30):
            current=own_window(owner)
            if current and current.get('fullscreen',0)!=old: break
            time.sleep(.02)
    elif action=='minimize':
        remember()
        atomic(minimized,{'workspace':w['workspace'].get('address') or w['workspace'].get('name') or str(w['workspace'].get('id',1))})
        dispatch('hl.dsp.window.move({window='+selector+',workspace='+json.dumps(HIDDEN)+',follow=false})')
    elif action=='activate':
        previous=read(minimized,{})
        if previous and w.get('workspace',{}).get('name','').startswith('special:'):
            key=previous.get('workspace','1')
            target=int(key) if key.isdecimal() and int(key)>0 else ('name:'+key.removeprefix('name:'))
            dispatch('hl.dsp.window.move({window='+selector+',workspace='+json.dumps(target)+',follow=false})')
            minimized.unlink(missing_ok=True)
        dispatch('hl.dsp.focus({window='+selector+'})')
        dispatch('hl.dsp.window.alter_zorder({window='+selector+',mode="top"})')
    elif action!='status':raise ValueError('Unknown window action.')
    w=own_window(owner) or w
    result['window']={k:w.get(k) for k in ('at','size','floating','fullscreen')}
    result['geometry']=read(geometry,{})
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['capabilities','prepare','mapped','remember','minimize','maximize','blur-on','blur-off','activate','status','cleanup'])
    parser.add_argument('--owner-pid',type=int,default=os.getppid())
    args=parser.parse_args()
    try:result=run(args.action,args.owner_pid)
    except Exception as error:result={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Window integration is unavailable.'}
    print(json.dumps(result,separators=(',',':')))
