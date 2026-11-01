#!/usr/bin/env python3
"""Native pointer test: in-window picker, draft/commit, no extra Wayland client."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,logical_size
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--output');args=parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def state():return json.loads(command('diagnostics'))
def clients():return json.loads(ipc('j/clients'))
def window():return next(w for w in clients() if w.get('title')=='SwiftShell Settings' and w.get('class')=='org.quickshell')
def wait(predicate):
    for _ in range(80):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Color picker did not reach expected native state')
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
def preferences():return json.loads(config.read_text())
original_state=state();saved=preferences();bar=saved['bar']
command('settings','bar');wait(lambda:state()['window'] is not None and not state()['windowBusy'])
original_geometry=window()
if args.output:
    monitor=next(m for m in json.loads(ipc('j/monitors')) if m['name']==args.output)
    selector=json.dumps('address:'+original_geometry['address'])
    x,y=monitor['x']+80,monitor['y']+40
    assert ipc('eval hl.dispatch(hl.dsp.window.move({window='+selector+f',x={x},y={y}'+'}))').strip()=='ok'
    time.sleep(.3)
geometry=window();identities={w['address'] for w in clients()}
try:
    with tempfile.TemporaryDirectory(prefix='swiftshell-color-pointer-') as directory:
        directory=Path(directory);protocol=ROOT/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(directory/'pointer-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(directory/'pointer-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(directory),str(ROOT/'tests/helpers/settings-pointer.c'),str(directory/'pointer-protocol.c'),'-o',str(directory/'pointer'),'-lwayland-client'],check=True)
        def gesture(part,dx=0,dy=0):
            w=window();assert w['pid']==geometry['pid'] and w['address']==geometry['address']
            box=state()['window']['colorPicker'][part]
            x=round(w['at'][0]+box['x']+box['width']/2);y=round(w['at'][1]+box['y']+box['height']/2)
            assert w['at'][0]<=x<w['at'][0]+w['size'][0] and w['at'][1]<=y<w['at'][1]+w['size'][1]
            monitor=next(m for m in json.loads(ipc('j/monitors')) if m['x']<=x<m['x']+logical_size(m)[0] and m['y']<=y<m['y']+logical_size(m)[1])
            width,height=map(round,logical_size(monitor))
            try:
                subprocess.run([str(directory/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(width),str(height),str(dx),str(dy),monitor['name'],str(x),str(y)],check=True)
            except subprocess.CalledProcessError:
                print('Pointer expected/observed:',(x,y),json.loads(ipc('j/cursorpos')),flush=True)
                raise
        for accept in [False,False,True]:
            command('window','color-picker');wait(lambda:state()['window']['colorPickerOpen'])
            assert {w['address'] for w in clients()}==identities,'Picker opened another native window'
            before=preferences()
            gesture('hue',40,0);gesture('spectrum',30,-20)
            time.sleep(.15)
            draft=state()['window']['colorPicker']['draft']
            assert preferences()['bar']==before['bar'] and preferences()['appearance']==before['appearance'],'Draft unexpectedly persisted'
            gesture('accept' if accept else 'cancel')
            wait(lambda:not state()['window']['colorPickerOpen'])
            if accept:wait(lambda:preferences()['bar']['surfaceColor']==draft)
            else:assert preferences()['bar']==before['bar']
            assert window()['at']==geometry['at'] and window()['size']==geometry['size'], {'before':(geometry['at'],geometry['size']),'after':(window()['at'],window()['size'])}
        print('PASS native color picker pointer editing, draft/cancel, commit, stable geometry and no additional client',flush=True)
finally:
    if args.output:
        current=window();selector=json.dumps('address:'+current['address']);x,y=original_geometry['at']
        ipc('eval hl.dispatch(hl.dsp.window.move({window='+selector+f',x={x},y={y}'+'}))')
        time.sleep(.15)
    command('barSurface','',bar.get('surfaceMode','transparent'),bar.get('surfaceColor','#161616'),str(bar.get('surfaceOpacity',.75)))
    command('settings',original_state['category'])
    wait(lambda:not state()['windowBusy'])
    if not original_state['settingsOpen']:
        command('window','close');wait(lambda:not state()['settingsOpen'])
