#!/usr/bin/env python3
"""Opt-in actual bar modes/blur proof against a shielded checkerboard."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PySide6.QtGui import QImage
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,logical_size
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
def command(*args):return subprocess.check_output(QS+list(args),text=True)
def diag():return json.loads(command('diagnostics'))
def clients():return json.loads(ipc('j/clients'))
def board():return next(w for w in clients() if w.get('title')=='SwiftShell Bar Test Pattern')
def wait(predicate):
    for _ in range(70):
        try:
            if predicate():return
        except StopIteration:pass
        time.sleep(.05)
    raise AssertionError('Bar test state did not become ready')
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
saved=json.loads(config.read_text())['bar'];overrides=json.loads(saved.get('surfaceOutputsJson','{}'))
active=json.loads(ipc('j/activewindow')).get('address')
pattern=ROOT/'tests/live/BarPattern.qml'
command('launcher','close')
subprocess.run(['qs','-p',str(pattern),'--no-duplicate','--daemonize'],check=True,stdout=subprocess.DEVNULL)
wait(lambda:board())
touched=[]
try:
    selector=json.dumps('address:'+board()['address'])
    dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
    for monitor in json.loads(ipc('j/monitors')):
        name=monitor['name'];touched.append(name)
        width,_=logical_size(monitor)
        x=monitor['x']+round(width/2)-180;y=monitor['y']-10
        dispatch('hl.dsp.window.move({window='+selector+f',x={x},y={y}'+'})')
        dispatch('hl.dsp.focus({window='+selector+'})')
        time.sleep(.3)
        w=board();px=monitor['x']+round(width/2)-150;py=monitor['y']+5
        height=next(b['height'] for b in diag()['barSurfaces'] if b['output']==name)-10
        assert w['at'][0]+12<=px and w['at'][0]+w['size'][0]-12>=px+300
        assert w['at'][1]+12<=py and w['at'][1]+w['size'][1]-12>=py+height
        assert json.loads(ipc('j/activewindow'))['address']==w['address'],'Fixture must shield any application behind the bar'
        scores={}
        others=[dict(b) for b in diag()['barSurfaces'] if b['output']!=name]
        for mode in ['transparent','solid','frosted']:
            command('barSurface',name,mode,'#161616','0.35');time.sleep(.5)
            current=next(b for b in diag()['barSurfaces'] if b['output']==name)
            assert current['mode']==mode
            assert current['blurApplied']==(mode=='frosted')
            assert [dict(b) for b in diag()['barSurfaces'] if b['output']!=name]==others,'Per-output change leaked to another bar'
            path=Path('/tmp')/f'swiftshell-bar-{name}-{mode}.png'
            subprocess.run(['grim','-g',f'{px},{py} 300x{height}',str(path)],check=True)
            image=QImage(str(path));assert not image.isNull()
            values=[abs(image.pixelColor(ix,iy).red()-image.pixelColor(ix+1,iy).red()) for iy in range(image.height()) for ix in range(image.width()-1)]
            scores[mode]=sum(values)/len(values)
        assert scores['transparent']>scores['solid']*1.2,scores
        assert scores['solid']>max(1,scores['frosted']*3),scores
        print('PASS independent transparent/solid/frosted bar and real blur on',name,{k:round(v,3) for k,v in scores.items()},flush=True)
finally:
    for name in touched:
        if name in overrides:
            s=overrides[name];command('barSurface',name,s['mode'],s['color'],str(s['opacity']))
        else:command('barInherit',name)
    subprocess.run(['qs','kill','-p',str(pattern)],check=False,stdout=subprocess.DEVNULL)
    if active and any(w['address']==active for w in clients()):dispatch('hl.dsp.focus({window='+json.dumps('address:'+active)+'})')
