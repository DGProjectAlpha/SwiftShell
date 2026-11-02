#!/usr/bin/env python3
"""Opt-in real Spotlight grid/pointer/keyboard tests. Never launch apps or power actions."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,logical_size
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def state():return json.loads(command('diagnostics'))
def spotlight():return state()['spotlight']
def wait(predicate):
    for _ in range(100):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Spotlight did not reach expected native state')
def focus(output):assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(output)+'}))').strip()=='ok'
monitors=json.loads(ipc('j/monitors'));original_focus=next(m['name'] for m in monitors if m['focused'])
original_cursor=json.loads(ipc('j/cursorpos'))
original=state();original_pins=None;owned_ids=set()
try:
    command('launcher','close')
    if original['settingsOpen']:command('window','close');wait(lambda:not state()['settingsOpen'])
    with tempfile.TemporaryDirectory(prefix='swiftshell-spotlight-ui-') as temp:
        temp=Path(temp)
        for protocol,prefix,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','spotlight-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
            path=ROOT/'tests/protocols'/protocol
            subprocess.run(['wayland-scanner','client-header',str(path),str(temp/f'{prefix}-client.h')],check=True)
            subprocess.run(['wayland-scanner','private-code',str(path),str(temp/f'{prefix}-protocol.c')],check=True)
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(temp),str(ROOT/'tests/helpers'/source),str(temp/f'{prefix}-protocol.c'),'-o',str(temp/prefix)]+libs,check=True)
        def key(action):subprocess.run([str(temp/'keyboard'),action],check=True)
        def click(m,box,button='left'):
            frame=spotlight()['frame'];x=round(m['x']+frame['x']+box['x']+box['width']/2);y=round(m['y']+frame['y']+box['y']+box['height']/2)
            width,height=map(round,logical_size(m))
            argv=[str(temp/'pointer'),str(x-m['x']),str(y-m['y']),str(width),str(height),'0','0',m['name'],str(x),str(y),button]
            for _ in range(3):
                result=subprocess.run(argv)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                time.sleep(.2)
            result.check_returncode()
        for monitor in monitors:
            focus(monitor['name']);time.sleep(.2)
            command('launcher','open');wait(lambda:state()['launcherOpen'] and state()['launcherHasFocus'])
            frame=spotlight()['frame'];assert frame['width']<=logical_size(monitor)[0] and frame['height']<=logical_size(monitor)[1]
            assert state()['launcherOutput']==monitor['name']
            key('calculation');wait(lambda:spotlight()['card']['providers'] and spotlight()['card']['providers'][0]['name']=='= 4')
            assert spotlight()['blurApplied'] or not state()['layerBlurAvailable']
            print('PASS actual keyboard 2+2 result, focus, bounded rounded frost on',monitor['name'],flush=True)
            command('launcherQuery','');command('launcherMode','all');wait(lambda:spotlight()['card']['appCount']>0)
            card=spotlight()['card'];original_pins=card['favorites'] if original_pins is None else original_pins
            mode=next(item for item in card['modes'] if item['id']=='all');click(monitor,mode['box'])
            wait(lambda:spotlight()['card']['mode']=='all')
            app=spotlight()['card']['apps'][0];owned_ids.add(app['id']);before=list(spotlight()['card']['favorites'])
            if len(before)<12 or app['id'] in before:
                key('favorite');wait(lambda:(app['id'] in spotlight()['card']['favorites'])!=(app['id'] in before))
                key('menu');wait(lambda:spotlight()['card']['favoriteMenu'])
                key('enter');wait(lambda:not spotlight()['card']['favoriteMenu'])
                assert set(spotlight()['card']['favorites'])==set(before)
                command('launcherPins',' '+json.dumps(before))
                print('PASS actual Ctrl D, Shift F10 and favorite context Enter on',monitor['name'],flush=True)
            click(monitor,app['box'],'right');wait(lambda:spotlight()['card']['favoriteMenu'])
            click(monitor,spotlight()['card']['favoriteAction']);wait(lambda:not spotlight()['card']['favoriteMenu'])
            wait(lambda:(app['id'] in spotlight()['card']['favorites'])!=(app['id'] in before))
            mode=next(item for item in spotlight()['card']['modes'] if item['id']=='favorites');click(monitor,mode['box'])
            wait(lambda:spotlight()['card']['mode']=='favorites')
            assert spotlight()['card']['appCount']==len(spotlight()['card']['favorites'])
            mode=next(item for item in spotlight()['card']['modes'] if item['id']=='all');click(monitor,mode['box'])
            wait(lambda:spotlight()['card']['mode']=='all')
            app=next(item for item in spotlight()['card']['apps'] if item['id']==app['id'])
            click(monitor,app['box'],'right');wait(lambda:spotlight()['card']['favoriteMenu'])
            click(monitor,spotlight()['card']['favoriteAction']);wait(lambda:not spotlight()['card']['favoriteMenu'])
            if set(spotlight()['card']['favorites'])==set(before):command('launcherPins',' '+json.dumps(before))
            assert spotlight()['card']['favorites']==before
            print('PASS real app context favorite toggle, Favorites/All grid and restore on',monitor['name'],flush=True)
            fixture=[item['id'] for item in spotlight()['card']['apps'][:3]]
            if len(fixture)==3:
                command('launcherPins',' '+json.dumps(fixture));command('launcherMode','favorites')
                wait(lambda:spotlight()['card']['appCount']==3)
                card=spotlight()['card'];first,last=card['apps'][0]['box'],card['apps'][2]['box']
                x=round(monitor['x']+frame['x']+first['x']+first['width']/2)
                y=round(monitor['y']+frame['y']+first['y']+first['height']/2)
                dx=round(last['x']+last['width']/2-first['x']-first['width']/2)
                dy=round(last['y']+last['height']/2-first['y']-first['height']/2)
                width,height=map(round,logical_size(monitor))
                args=[str(temp/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(width),str(height),str(dx),str(dy),monitor['name'],str(x),str(y)]
                subprocess.run(args,check=True)
                expected=fixture[1:]+fixture[:1]
                wait(lambda:spotlight()['card']['favorites']==expected and state()['settingsPersistence']=='ready')
                assert state()['launcherOpen'],'Dragging favorites must never launch an app'
                command('launcherPins',' '+json.dumps(before));command('launcherMode','all')
                wait(lambda:spotlight()['card']['favorites']==before and state()['settingsPersistence']=='ready')
                print('PASS actual favorite drag order, persistence and no accidental launch on',monitor['name'],flush=True)

            actions=spotlight()['card']['actions']
            click(monitor,dict(actions,width=min(82,(frame['width']-64)/5)))
            wait(lambda:state()['settingsOpen'] and not state()['launcherOpen'] and not state()['windowBusy'])
            command('window','close');wait(lambda:not state()['settingsOpen'])
            focus(monitor['name']);command('launcher','open');wait(lambda:state()['launcherOpen'] and state()['launcherHasFocus'])
            key('escape');wait(lambda:not state()['launcherOpen'])
            print('PASS real Settings icon action and Escape on',monitor['name'],flush=True)
finally:
    command('launcher','close')
    if original_pins is not None:
        # Only restore entries actually touched by this audit; keep unrelated edits.
        current=spotlight()['card']['favorites']
        for identifier in owned_ids:
            if (identifier in current)!=(identifier in original_pins):command('launcherFavorite',identifier)
        current=spotlight()['card']['favorites']
        restored=[identifier for identifier in original_pins if identifier in current]+[identifier for identifier in current if identifier not in original_pins]
        if restored!=current:command('launcherPins',' '+json.dumps(restored))
    command('launcherMode',original['spotlight']['card']['mode'])
    wait(lambda:state()['settingsPersistence']=='ready')
    if original['settingsOpen']:command('settings',original['category']);wait(lambda:state()['settingsOpen'] and not state()['windowBusy'])
    focus(original_focus)
    assert ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(original_cursor['x'])+',y='+str(original_cursor['y'])+'}))').strip()=='ok'
