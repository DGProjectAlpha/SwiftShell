#!/usr/bin/env python3
"""Controlled-pattern native blur proof. No private desktop captures."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PySide6.QtGui import QImage
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,snapshot

parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);args=parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def clients():return json.loads(ipc('j/clients'))
def own():return next(w for w in clients() if w.get('title')=='SwiftShell Settings' and w.get('class')=='org.quickshell')
def board():return next(w for w in clients() if w.get('title')=='SwiftShell Blur Test Pattern')
def move(w,x,y):
    selector=json.dumps('address:'+w['address'])
    assert ipc(f'eval hl.dispatch(hl.dsp.window.move({{window={selector},x={x},y={y}}}))').strip()=='ok'
def wait(predicate):
    for _ in range(60):
        try:
            if predicate():return
        except StopIteration:pass
        time.sleep(.05)
    raise AssertionError('Native blur fixture did not become ready')
command('settings','displays');wait(lambda:own());time.sleep(.4)
original=own()
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
appearance=json.loads(config.read_text())['appearance']
original_blur=appearance.get('panelBlur',1)
original_opacity=appearance.get('panelOpacity',.92)
original_effects={key:appearance[key] for key in ('radius','shadowOpacity','shadowSoftness')}
pattern=ROOT/'tests/live/BlurPattern.qml'
subprocess.run(['qs','-p',str(pattern),'--no-duplicate','--daemonize'],check=True,stdout=subprocess.DEVNULL,env=dict(os.environ,SWIFTSHELL_BLUR_WIDTH=str(original['size'][0]+8),SWIFTSHELL_BLUR_HEIGHT=str(original['size'][1]+8)))
wait(lambda:board())

def contrast(path,logical_width):
    image=QImage(str(path));assert not image.isNull()
    factor=image.width()/logical_width
    x0,x1,y0,y1=[round(n*factor) for n in (72,140,580,640)]
    values=[]
    for y in range(y0,y1):
        for x in range(x0,x1-1):
            a=image.pixelColor(x,y);b=image.pixelColor(x+1,y)
            values.append(abs(a.red()-b.red()))
    return sum(values)/len(values)
try:
    command('appearance','panelOpacity','0.64')
    for monitor in snapshot():
        if not monitor['enabled']:continue
        x,y=monitor['x']+100,monitor['y']+60
        move(own(),x,y);time.sleep(.25)
        current=own();x,y=current['at'];width,height=current['size']
        move(board(),x-4,y-4)
        command('window','restore');time.sleep(.6)
        scores={}
        for label,value in [('on',1),('off',0)]:
            command('appearance','panelBlur',str(value));time.sleep(.5)
            current=own();background=board()
            x,y=current['at'];width,height=current['size']
            assert background['at'][0]<=x and background['at'][1]<=y
            assert background['at'][0]+background['size'][0]>=x+width and background['at'][1]+background['size'][1]>=y+height, {'output':monitor['name'],'settings':(current['at'],current['size']),'pattern':(background['at'],background['size'])}
            path=Path('/tmp')/f'swiftshell-settings-blur-{monitor["name"]}-{label}.png'
            subprocess.run(['grim','-g',f'{x},{y} {width}x{height}',str(path)],check=True)
            scores[label]=contrast(path,width)
        assert scores['off']>max(1,scores['on']*3),(monitor['name'],scores)
        print('PASS genuine backdrop blur on',monitor['name'],'(mean edge contrast on/off:',round(scores['on'],3),round(scores['off'],3),')',flush=True)
        def capture_effect(label):
            time.sleep(.5)
            path=Path('/tmp')/f'swiftshell-settings-effect-{monitor["name"]}-{label}.png'
            subprocess.run(['grim','-g',f'{x},{y} {width}x{height}',str(path)],check=True)
            return QImage(str(path))
        def difference(first,second,rect):
            factor=first.width()/width
            left,top,right,bottom=[round(n*factor) for n in rect]
            values=[abs(first.pixelColor(px,py).red()-second.pixelColor(px,py).red())
                    for py in range(top,bottom) for px in range(left,right)]
            return sum(values)/len(values)
        command('appearance','panelBlur','1')
        command('appearance','shadowOpacity','0')
        flat=capture_effect('no-shadow')
        command('appearance','shadowOpacity','0.4')
        command('appearance','shadowSoftness','4')
        sharp=capture_effect('sharp-shadow')
        command('appearance','shadowSoftness','24')
        soft=capture_effect('soft-shadow')
        assert difference(flat,sharp,(8,120,32,400))>.05
        assert difference(sharp,soft,(8,120,32,400))>.05
        command('appearance','radius','6')
        square=capture_effect('square')
        command('appearance','radius','12')
        rounded=capture_effect('rounded')
        assert difference(square,rounded,(32,32,44,44))>.05
        print('PASS visible radius, shadow opacity, and shadow softness on',monitor['name'],flush=True)

finally:
    for key,value in original_effects.items():command('appearance',key,str(value))
    command('appearance','panelBlur',str(original_blur))
    command('appearance','panelOpacity',str(original_opacity))
    try:move(own(),*original['at'])
    except StopIteration:pass
    subprocess.run(['qs','kill','-p',str(pattern)],stdout=subprocess.DEVNULL,check=False)
