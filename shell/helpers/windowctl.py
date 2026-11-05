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


def launch_output(outputs, requested=''):
    usable=[m for m in outputs if not m.get('disabled', False)]
    return next((m for m in usable if m.get('name')==requested),
                next((m for m in usable if m.get('focused')), usable[0] if usable else None))


def centered_geometry(saved, monitor):
    # Persist size; every explicit launch is centered on its requested output.
    scale=max(.25,float(monitor.get('scale',1)))
    width,height=round(monitor['width']/scale),round(monitor['height']/scale)
    if int(monitor.get('transform',0)) % 2:
        width,height=height,width
    reserved=monitor.get('reserved',[0,0,0,0])
    left,top,right,bottom=[max(0,round(value)) for value in reserved]
    available_width=max(1,width-left-right)
    available_height=max(1,height-top-bottom)
    def size(name, fallback, minimum, maximum):
        value=saved.get(name,fallback)
        if isinstance(value,bool) or not isinstance(value,(int,float)) or not 0<value<100000:
            value=fallback
        return min(max(minimum,round(value)),maximum)
    w=size('width',1000,640,available_width)
    h=size('height',700,440,available_height)
    return {'x':round(monitor['x']+left+(available_width-w)/2),
            'y':round(monitor['y']+top+(available_height-h)/2),
            'width':w,'height':h,'monitor':monitor['name']}


def run(action,owner,output=""):
    if action=='capabilities':return dict(ok=True,**blur_capability())
    folder=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'swiftshell'
    geometry=folder/'settings-window.json'
    minimized=folder/f'settings-minimized-{owner}.json'
    saved=read(geometry,{})
    result={'ok':True,'geometry':saved,'blurAvailable':False,'blurReason':'Backdrop blur is unavailable.'}
    if action=='prepare':
        result.update(blur_capability())
        monitor=launch_output(json.loads(ipc('j/monitors')),output)
        if monitor:
            result['geometry']=centered_geometry(saved,monitor)
            result['output']=monitor['name']
        # Temporary rule scoped to this exact application/title. No config file writes.
        code='if _G.__swiftshell_settings_rule then _G.__swiftshell_settings_rule:set_enabled(false) end; '
        code+=f'_G.__swiftshell_settings_owner={owner}; '
        monitor_rule='monitor='+json.dumps(monitor['name'],ensure_ascii=False)+',' if monitor else ''
        code+='_G.__swiftshell_settings_rule=hl.window_rule({'+monitor_rule+'name="swiftshell-owned-settings",match={class="^org\\\\.quickshell$",title="^SwiftShell Settings$"},float=true,center=true,no_anim=true,no_initial_focus=true,border_size=0,rounding=0,no_shadow=true,no_blur=false})'
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
            monitor=next((m['name'] for m in monitors if m['x']<=w['at'][0]+w['size'][0]/2<m['x']+m['width']/m['scale'] and m['y']<=w['at'][1]+w['size'][1]/2<m['y']+m['height']/m['scale']), '')
            atomic(geometry,{'x':w['at'][0],'y':w['at'][1],'width':w['size'][0],'height':w['size'][1],'monitor':monitor})
    if action=='remember':remember()
    elif action=='mapped':
        if not w.get('floating'):dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
        monitor=launch_output(json.loads(ipc('j/monitors')),output)
        if monitor:
            placed=centered_geometry(saved,monitor)
            dispatch(f'hl.dsp.window.resize({{window={selector},x={placed["width"]},y={placed["height"]}}})')
            dispatch(f'hl.dsp.window.move({{window={selector},x={placed["x"]},y={placed["y"]}}})')
            result['output']=monitor['name']
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
        if output:
            monitor=launch_output(json.loads(ipc('j/monitors')),output)
            if monitor:
                placed=centered_geometry({'width':w['size'][0],'height':w['size'][1]},monitor)
                dispatch(f'hl.dsp.window.resize({{window={selector},x={placed["width"]},y={placed["height"]}}})')
                dispatch(f'hl.dsp.window.move({{window={selector},x={placed["x"]},y={placed["y"]}}})')
                result['output']=monitor['name']
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
    parser.add_argument('--output',default='')
    parser.add_argument('--owner-pid',type=int,default=os.getppid())
    args=parser.parse_args()
    try:result=run(args.action,args.owner_pid,args.output)
    except Exception as error:result={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Window integration is unavailable.'}
    print(json.dumps(result,separators=(',',':')))
