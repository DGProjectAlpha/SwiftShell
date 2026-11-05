#!/usr/bin/env python3
"""Opt-in native Settings placement, visible resize edge and control regression.

Loads a private copy with temporary preferences. Pointer gestures are guarded by
its exact PID, title, monitor and visible frame; captures use its owned Qt item.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).parents[2]
sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc,logical_size
from windowctl import centered_geometry
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--output');args=parser.parse_args()

def wait(predicate,message):
    for _ in range(160):
        try:
            result=predicate()
            if result:return result
        except (ValueError,subprocess.CalledProcessError):pass
        time.sleep(.05)
    raise AssertionError(message)

def clients():return json.loads(ipc('j/clients'))
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
main=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
original=json.loads(subprocess.check_output(main+['diagnostics'],text=True))
if original['settingsOpen']:
    subprocess.run(main+['window','close'],check=True,stdout=subprocess.DEVNULL)
    wait(lambda:not json.loads(subprocess.check_output(main+['diagnostics'],text=True))['settingsOpen'],'Production Settings did not close')
original_active=json.loads(ipc('j/activewindow')).get('address')
monitors=json.loads(ipc('j/monitors'))
selected=[m for m in monitors if not args.output or m['name']==args.output]
# Secondary first so a missing first-map output rule is caught early.
selected.sort(key=lambda m:m['scale']==1)
with tempfile.TemporaryDirectory(prefix='swiftshell-settings-ux-') as folder:
    folder=Path(folder);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
    shutil.copyfile(ROOT/'tests/live/settings-ux.qml',shell/'Audit.qml')
    for directory in ['config/swiftshell','state','cache']:(folder/directory).mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'shell/config/defaults.json',folder/'config/swiftshell/settings.json')
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    protocol=ROOT/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
    subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'pointer-client.h')],check=True)
    subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'pointer-protocol.c')],check=True)
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers/settings-pointer.c'),str(folder/'pointer-protocol.c'),'-o',str(folder/'pointer'),'-lwayland-client'],check=True)
    command=['qs','ipc','-p',str(shell/'Audit.qml'),'call','audit']
    def call(*items):return subprocess.check_output(command+list(map(str,items)),text=True,stderr=subprocess.DEVNULL)
    def state():return json.loads(call('status'))
    log=open(folder/'audit.log','w');process=subprocess.Popen(['qs','-p',str(shell/'Audit.qml')],env=env,stdout=log,stderr=log)
    def window():return next((w for w in clients() if w.get('pid')==process.pid and w.get('title')=='SwiftShell Settings'),None)
    def ready():
        result=state()
        if result['error']:raise AssertionError(result['error'])
        return window() and result['frame'] and result['frame']['ready'] and not result['busy']
    def gesture(m,x,y,dx=0,dy=0):
        current=window();assert current and current['pid']==process.pid
        assert m['x']<=x<m['x']+logical_size(m)[0] and m['y']<=y<m['y']+logical_size(m)[1]
        assert current['at'][0]<=x<current['at'][0]+current['size'][0] and current['at'][1]<=y<current['at'][1]+current['size'][1]
        width,height=map(round,logical_size(m))
        argv=[str(folder/'pointer'),str(round(x-m['x'])),str(round(y-m['y'])),str(width),str(height),str(dx),str(dy),m['name'],str(round(x)),str(round(y))]
        for _ in range(3):
            result=subprocess.run(argv)
            if result.returncode==0:return
            if result.returncode!=6:result.check_returncode()
            time.sleep(.1)
        result.check_returncode()
    try:
        wait(lambda:state(),'Audit IPC did not start')
        for monitor in selected:
            output=monitor['name']
            call('open',output,'appearance');wait(ready,'Settings did not map on '+output)
            current=window();expected=centered_geometry({'width':1000,'height':700},monitor)
            assert current['at']==[expected['x'],expected['y']],(current['at'],expected)
            assert current['size']==[1000,700],current['size']
            assert current['monitor']==monitor['id'],(current['monitor'],monitor['id'])
            print('PASS first-map requested-monitor centering on',output,flush=True)
            frame=state()['frame'];before=window()
            # The corner target is inside the actual painted edge, 32px away
            # from the old transparent outer window boundary.
            gesture(monitor,before['at'][0]+frame['x']+frame['width']-4,before['at'][1]+frame['y']+frame['height']-4,32,24)
            wait(lambda:window()['size'][0]>=before['size'][0]+20,'Visible corner did not resize')
            assert window()['size'][1]>=before['size'][1]+15
            print('PASS resize begins at the painted Settings corner on',output,flush=True)
            # Find a real section header and collapse/reopen it by pointer.
            section=next(s for s in state()['ui']['sections'] if s['id']=='appearance.interface')
            box=section['box'];current=window()
            gesture(monitor,current['at'][0]+box['x']+25,current['at'][1]+box['y']+14)
            wait(lambda:not next(s for s in state()['ui']['sections'] if s['id']=='appearance.interface')['expanded'],'Section did not collapse')
            call('search','text size')
            wait(lambda:state()['category']=='appearance' and any(s['id']=='appearance.interface' and s['effectiveExpanded'] and not s['expanded'] for s in state()['ui']['sections']),'Search did not temporarily expand collapsed section')
            call('search','')
            wait(lambda:any(s['id']=='appearance.interface' and not s['effectiveExpanded'] for s in state()['ui']['sections']),'Search changed saved section preference')
            call('scroll',0)
            section=next(s for s in state()['ui']['sections'] if s['id']=='appearance.interface');box=section['box'];current=window()
            gesture(monitor,current['at'][0]+box['x']+25,current['at'][1]+box['y']+14)
            wait(lambda:any(s['id']=='appearance.interface' and s['expanded'] for s in state()['ui']['sections']),'Section did not reopen')
            # A diagonal pointer drag must stay on the slider, not scroll.
            call('search','text size')
            slider=wait(lambda:next((s for s in state()['ui']['sliders'] if s['name']=='Text size'),None),'Text size slider missing')
            current=window();position=state()['ui']['scroll']['position'];font=state()['fontSize'];past=state()['past'];box=slider['box']
            gesture(monitor,current['at'][0]+box['x']+box['width']*.35,current['at'][1]+box['y']+box['height']/2,round(box['width']*.35),24)
            wait(lambda:state()['fontSize']!=font,'Pointer drag did not change text size')
            assert state()['ui']['scroll']['position']==position
            assert state()['past']==past+1
            call('undo');wait(lambda:state()['fontSize']==font,'Undo did not restore one complete drag')
            print('PASS section persistence/search and slider drag/one-step Undo on',output,flush=True)
            call('search','');call('scroll',0)
            capture='/tmp/swiftshell-settings-ux-'+output+'.png';Path(capture).unlink(missing_ok=True);call('capture',capture)
            wait(lambda:Path(capture).exists(),'Owned Qt capture was not written')
            wait(lambda:state()['persistence']=='ready','Latest settings did not finish saving')
            # Move it off center, then reopen: location must follow launch intent.
            current=window();size=current['size'];selector=json.dumps('address:'+current['address'])
            dispatch('hl.dsp.window.move({window='+selector+',x='+str(monitor['x']+50)+',y='+str(monitor['y']+45)+'})')
            time.sleep(.4);call('close');wait(lambda:window() is None and not state()['busy'],'Settings did not close')
            call('open',output,'appearance');wait(ready,'Settings did not reopen')
            expected=centered_geometry({'width':size[0],'height':size[1]},monitor)
            assert window()['at']==[expected['x'],expected['y']]
            assert window()['size']==size
            print('PASS reopen centers requested monitor and preserves size on',output,flush=True)
            call('close');wait(lambda:window() is None and not state()['busy'],'Settings did not close between monitors')
            # Start next monitor from the canonical size, not this test's resize.
            geometry=folder/'state/swiftshell/settings-window.json'
            if geometry.exists():geometry.unlink()
        print('PASS native Settings UX audit',flush=True)
    except Exception:
        log.flush();print('Final owned Settings state:',state(),file=sys.stderr);print((folder/'audit.log').read_text(),file=sys.stderr);raise
    finally:
        try:call('close');wait(lambda:window() is None and not state()['busy'],'Audit cleanup did not close its window')
        except Exception:pass
        subprocess.run(['qs','kill','-p',str(shell/'Audit.qml')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
        try:process.wait(timeout=4)
        except subprocess.TimeoutExpired:process.terminate();process.wait(timeout=4)
        log.close()
        if original['settingsOpen']:
            subprocess.run(main+['settings',original['category']],check=True,stdout=subprocess.DEVNULL)
        elif original_active and any(w.get('address')==original_active for w in clients()):
            dispatch('hl.dsp.focus({window='+json.dumps('address:'+original_active)+'})')
