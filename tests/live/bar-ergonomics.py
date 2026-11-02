#!/usr/bin/env python3
"""Opt-in real clock, bar layout, right-click visibility and frosted popup test."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from PySide6.QtGui import QImage
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,logical_size
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
ROOT=Path(__file__).parents[2];QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(QS+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def bar(output):
    for _ in range(25):
        result=next(b for b in state()['barSurfaces'] if b['output']==output)
        if not result['menu']['visible']:return result
        layer_data=json.loads(ipc('j/layers')).get(output,{})
        observed=[item for items in layer_data.get('levels',{}).values() for item in items if item.get('namespace')=='swiftshell-popover']
        if observed:
            assert len(observed)==1,'Expected only this SwiftShell popover on the test output'
            actual=observed[0];geometry=result['menu']['geometry']
            if all(abs(geometry[field]-actual[key])<=1 for field,key in [('x','x'),('y','y'),('width','w'),('height','h')]):return result
        time.sleep(.03)
    raise AssertionError('Popover geometry did not agree with compositor observations')

def wait(predicate):
    for _ in range(100):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Bar/menu state did not become ready')
def clients():return json.loads(ipc('j/clients'))
def board():return next((w for w in clients() if w.get('title')=='SwiftShell Blur Test Pattern'),None)
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
original_settings=state();saved=json.loads(config.read_text());prefs=saved['bar'];clock=saved['clock'];appearance=saved['appearance']
sides=json.loads(prefs.get('moduleSidesJson','{}'));hidden=json.loads(prefs.get('hiddenOutputsJson','{}'))
monitors=json.loads(ipc('j/monitors'));original_focus=next(m['name'] for m in monitors if m['focused'])
original_client=json.loads(ipc('j/activewindow')).get('address')
original_cursor=json.loads(ipc('j/cursorpos'))
pattern=ROOT/'tests/live/BlurPattern.qml'
try:
    for m in monitors:call('barPanel',m['name'],'close')
    call('clockOptions','false','true','true','iso')
    wait(lambda:all(re.search(r'\d{4}-\d{2}-\d{2} · \d{1,2}:\d{2}:\d{2} [AP]M$',b['clock']) for b in state()['barSurfaces']))
    before=[b['clock'] for b in state()['barSurfaces']]
    wait(lambda:[b['clock'] for b in state()['barSurfaces']]!=before)
    call('clockOptions','true','false','false','short')
    wait(lambda:all(re.fullmatch(r'\d{2}:\d{2}',b['clock']) for b in state()['barSurfaces']))
    call('moduleSide','clock','center')
    wait(lambda:all('clock' in b['modules']['center'] for b in state()['barSurfaces']))
    for b in state()['barSurfaces']:
        left,center,right=[b['layout'][s] for s in ['left','center','right']]
        assert left['x']+left['width']<=center['x']+1 and center['x']+center['width']<=right['x']+1,b['layout']
    print('PASS actual 12h/date/seconds ticks, 24h/minute display and centered non-overlapping clock on both outputs',flush=True)
    with tempfile.TemporaryDirectory(prefix='swiftshell-bar-actions-') as temp:
        temp=Path(temp)
        for protocol,prefix,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
            path=ROOT/'tests/protocols'/protocol
            subprocess.run(['wayland-scanner','client-header',str(path),str(temp/f'{prefix}-client.h')],check=True)
            subprocess.run(['wayland-scanner','private-code',str(path),str(temp/f'{prefix}-protocol.c')],check=True)
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(temp),str(ROOT/'tests/helpers'/source),str(temp/f'{prefix}-protocol.c'),'-o',str(temp/prefix)]+libs,check=True)
        def pointer(m,x,y,button='left'):
            width,height=map(round,logical_size(m));x,y=round(x),round(y)
            argv=[str(temp/'pointer'),str(x-m['x']),str(y-m['y']),str(width),str(height),'0','0',m['name'],str(x),str(y),button]
            for attempt in range(3):
                result=subprocess.run(argv)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                # Exit 6 means the transport sent no button press. Wait for any
                # compositor cursor warp to settle, then safely retry the motion.
                time.sleep(.2)
            result.check_returncode()
        subprocess.run([str(temp/'keyboard'),'escape'],check=True)
        for m in monitors:
            name=m['name'];width,_=logical_size(m)
            # Actual right-click anywhere on this shell's bar opens its own menu.
            pointer(m,m['x']+width*.35,m['y']+bar(name)['height']/2,'right')
            wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['id']=='customize')
            time.sleep(.2)
            menu=bar(name)['menu'];geometry=menu['geometry']
            assert m['x']<=geometry['x'] and m['y']<=geometry['y']
            assert geometry['x']+geometry['width']<=m['x']+logical_size(m)[0]+1
            assert geometry['y']+geometry['height']<=m['y']+logical_size(m)[1]+1
            item=next(i for i in geometry['items'] if i['module']=='search')
            before_self=bar(name)['modules'];other_before=[b['modules'] for b in state()['barSurfaces'] if b['output']!=name]
            pointer(m,geometry['x']+item['x']+item['width']/2,geometry['y']+item['y']+item['height']/2)
            wait(lambda:bar(name)['modules']!=before_self)
            assert [b['modules'] for b in state()['barSurfaces'] if b['output']!=name]==other_before
            geometry=bar(name)['menu']['geometry'];item=next(i for i in geometry['items'] if i['module']=='search')
            pointer(m,geometry['x']+item['x']+item['width']/2,geometry['y']+item['y']+item['height']/2)
            wait(lambda:bar(name)['modules']==before_self)
            subprocess.run([str(temp/'keyboard'),'escape'],check=True)
            wait(lambda:not bar(name)['menu']['visible'])
            print('PASS actual right-click, per-output checkbox isolation, bounds and Escape on',name,flush=True)
            pointer(m,m['x']+width*.35,m['y']+bar(name)['height']/2,'right')
            wait(lambda:bar(name)['menu']['visible'])
            geometry=bar(name)['menu']['geometry'];item=next(i for i in geometry['items'] if i['module']=='customize')
            pointer(m,geometry['x']+item['x']+item['width']/2,geometry['y']+item['y']+item['height']/2)
            wait(lambda:state()['settingsOpen'] and state()['category']=='bar' and not state()['windowBusy'])
            assert not bar(name)['menu']['visible']
            call('window','close');wait(lambda:not state()['settingsOpen'])
            pointer(m,m['x']+width*.35,m['y']+bar(name)['height']/2,'right')
            wait(lambda:bar(name)['menu']['visible'])
            subprocess.run([str(temp/'keyboard'),'toggle'],check=True)
            wait(lambda:state()['launcherOpen'] and all(not b['menu']['visible'] for b in state()['barSurfaces']))
            subprocess.run([str(temp/'keyboard'),'escape'],check=True);wait(lambda:not state()['launcherOpen'])
            print('PASS real Customize bar action and clean launcher focus handoff on',name,flush=True)

            if name in hidden:call('moduleVisibility',name,' '+json.dumps(hidden[name]))
            else:call('moduleInherit',name)
            # Place an owned checkerboard beneath each native popup; no private pixels.
            for panel in ['calendar','date','control','power','customize']:
                call('barPanel',name,panel);wait(lambda:bar(name)['menu']['visible']);time.sleep(.25)
                geometry=bar(name)['menu']['geometry'];assert geometry['height']<=logical_size(m)[1] and geometry['width']<=logical_size(m)[0];call('barPanel',name,'close');wait(lambda:not bar(name)['menu']['visible'])
                subprocess.run(['qs','-p',str(pattern),'--no-duplicate','--daemonize'],check=True,stdout=subprocess.DEVNULL,env=dict(os.environ,SWIFTSHELL_BLUR_WIDTH=str(round(geometry['width'])+16),SWIFTSHELL_BLUR_HEIGHT=str(round(geometry['height'])+16)))
                wait(lambda:board() is not None)
                w=board();selector=json.dumps('address:'+w['address'])
                dispatch('hl.dsp.window.move({window='+selector+f',x={round(geometry["x"])-8},y={round(geometry["y"])-8}'+'})')
                dispatch('hl.dsp.window.set_prop({window='+selector+',prop="rounding",value="0"})')
                dispatch('hl.dsp.focus({window='+selector+'})')
                assert json.loads(ipc('j/activewindow')).get('address')==w['address'],'Fixture must shield the underlying applications'
                call('barPanel',name,panel);wait(lambda:bar(name)['menu']['visible']);time.sleep(.25)
                geometry=bar(name)['menu']['geometry']
                # Focusing the fixture can change the focused-title group's width.
                # Reposition the shield after the final anchor has been observed.
                dispatch('hl.dsp.window.move({window='+selector+f',x={round(geometry["x"])-8},y={round(geometry["y"])-8}'+'})')
                time.sleep(.2)
                geometry=bar(name)['menu']['geometry'];background=board()
                x=round(geometry['x']+100);y=round(geometry['y']+105)
                assert background['at'][0]+12<x and background['at'][1]+12<y
                assert background['at'][0]+background['size'][0]-12>x+80 and background['at'][1]+background['size'][1]-12>y+80
                scores={}
                for label,value in [('on','1'),('off','0')]:
                    call('appearance','panelBlur',value);wait(lambda:state()['panelBlur']==int(value));time.sleep(.3)
                    path=Path('/tmp')/f'swiftshell-popover-{name}-{panel}-{label}.png'
                    subprocess.run(['grim','-g',f'{x},{y} 80x80',str(path)],check=True)
                    if label=='on' and panel in ('calendar','date','customize'):
                        frame=bar(name)['menu']['geometry']
                        assert background['at'][0]<=frame['x'] and background['at'][1]<=frame['y']
                        assert background['at'][0]+background['size'][0]>=frame['x']+frame['width'] and background['at'][1]+background['size'][1]>=frame['y']+frame['height']
                        subprocess.run(['grim','-g',f'{round(frame["x"])},{round(frame["y"])} {round(frame["width"])}x{round(frame["height"])}',f'/tmp/swiftshell-popover-{name}-{panel}-full.png'],check=True)
                    image=QImage(str(path));assert not image.isNull()
                    scores[label]=sum(abs(image.pixelColor(ix,iy).red()-image.pixelColor(ix+1,iy).red()) for iy in range(image.height()) for ix in range(image.width()-1))/(image.height()*(image.width()-1))
                assert scores['off']>scores['on']*1.3,(name,panel,scores)
                print('PASS actual rounded popup backdrop blur on',name,panel,{k:round(v,3) for k,v in scores.items()},flush=True)
                call('barPanel',name,'close');wait(lambda:not bar(name)['menu']['visible'])
                subprocess.run(['qs','kill','-p',str(pattern)],check=True,stdout=subprocess.DEVNULL)
                wait(lambda:board() is None)
                call('appearance','panelBlur',str(appearance['panelBlur']))
finally:
    for m in monitors:
        call('barPanel',m['name'],'close')
        if m['name'] in hidden:call('moduleVisibility',m['name'],' '+json.dumps(hidden[m['name']]))
        else:call('moduleInherit',m['name'])
    call('moduleSide','clock',sides.get('clock','inherit'))
    call('clockOptions',str(clock['use24Hour']).lower(),str(clock.get('showSeconds',False)).lower(),str(clock.get('showDate',False)).lower(),clock.get('dateFormat','short'))
    call('appearance','panelBlur',str(appearance['panelBlur']))
    if board():subprocess.run(['qs','kill','-p',str(pattern)],check=False,stdout=subprocess.DEVNULL)
    call('settings',original_settings['category']);wait(lambda:state()['window'] is not None and not state()['windowBusy'])
    if not original_settings['settingsOpen']:
        call('window','close');wait(lambda:not state()['settingsOpen'])
    wait(lambda:state()['settingsPersistence']=='ready')

    if original_client and any(w['address']==original_client for w in clients()):dispatch('hl.dsp.focus({window='+json.dumps('address:'+original_client)+'})')
    dispatch('hl.dsp.cursor.move({x='+str(original_cursor['x'])+',y='+str(original_cursor['y'])+'})')
    dispatch('hl.dsp.focus({monitor='+json.dumps(original_focus)+'})')
