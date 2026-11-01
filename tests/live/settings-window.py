#!/usr/bin/env python3
"""Opt-in native pointer tests. Only targets the SwiftShell Settings window."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
sys.path.insert(0,str(Path(__file__).parents[2]/'shell/helpers'))
from displayctl import ipc,logical_size,snapshot

parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True)
parser.add_argument('--output')
args=parser.parse_args()
ROOT=Path(__file__).parents[2]
QS=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']

def command(*args):return subprocess.check_output(QS+list(args),text=True)
def diagnostics():return json.loads(command('diagnostics'))
def window():return next((w for w in json.loads(ipc('j/clients')) if w.get('title')=='SwiftShell Settings' and w.get('class')=='org.quickshell'),None)
def wait(predicate):
    for _ in range(60):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Native Settings state did not reach the expected result')

command('settings','displays');wait(lambda:window() is not None);time.sleep(.6)
original=window();assert original['floating']
if args.output:
    monitor=next(m for m in snapshot() if m['name']==args.output and m['enabled'])
    selector=json.dumps('address:'+original['address'])
    logical_width,logical_height=logical_size(monitor)
    width=min(original['size'][0],int(logical_width)-200,1200)
    height=min(original['size'][1],int(logical_height)-200,700)
    ipc(f'eval hl.dispatch(hl.dsp.window.resize({{window={selector},x={width},y={height}}}))')
    x,y=monitor['x']+100,monitor['y']+60
    ipc(f'eval hl.dispatch(hl.dsp.window.move({{window={selector},x={x},y={y}}}))')
    time.sleep(.4)
with tempfile.TemporaryDirectory(prefix='swiftshell-pointer-test-') as temp:
    temp=Path(temp)
    protocol=ROOT/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
    subprocess.run(['wayland-scanner','client-header',str(protocol),str(temp/'pointer-client.h')],check=True)
    subprocess.run(['wayland-scanner','private-code',str(protocol),str(temp/'pointer-protocol.c')],check=True)
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(temp),str(ROOT/'tests/helpers/settings-pointer.c'),str(temp/'pointer-protocol.c'),'-o',str(temp/'pointer'),'-lwayland-client'],check=True)
    monitors=snapshot()
    right=round(max(m['x']+logical_size(m)[0] for m in monitors if m['enabled']))
    bottom=round(max(m['y']+logical_size(m)[1] for m in monitors if m['enabled']))
    def gesture(x,y,dx=0,dy=0):
        w=window();assert w and w['pid']==original['pid']
        # Every starting click must be inside this exact Settings client.
        assert w['at'][0]<=x<w['at'][0]+w['size'][0] and w['at'][1]<=y<w['at'][1]+w['size'][1]
        m=next(m for m in monitors if m['enabled'] and m['x']<=x<m['x']+logical_size(m)[0] and m['y']<=y<m['y']+logical_size(m)[1])
        width,height=map(round,logical_size(m))
        subprocess.run([str(temp/'pointer'),str(int(x-m['x'])),str(int(y-m['y'])),str(width),str(height),str(dx),str(dy),m['name'],str(int(x)),str(int(y))],check=True)
    def button(kind):
        w=window();inset=diagnostics()['window']['shadowInset']
        offset={'close':28,'maximize':64,'minimize':100}[kind]
        gesture(w['at'][0]+w['size'][0]-inset-offset,w['at'][1]+inset+26)
    try:
        before=window();inset=diagnostics()['window']['shadowInset']
        gesture(before['at'][0]+350,before['at'][1]+inset+26,40,20)
        wait(lambda:window()['at']!=before['at'])
        assert window()['size']==before['size']
        print('PASS native title-bar drag',flush=True)
        before=window()
        gesture(before['at'][0]+before['size'][0]-4,before['at'][1]+before['size'][1]-4,40,30)
        wait(lambda:window()['size'][0]>before['size'][0]+20 and window()['size'][1]>before['size'][1]+15)
        resized=window()
        print('PASS native corner resize',flush=True)
        # Exercise every remaining native edge/corner, returning to the same geometry.
        for label,rx,ry,dx,dy in [('left',4,.5,-30,0),('right',-4,.5,30,0),('top',.5,4,0,-20),('bottom',.5,-4,0,20),('top-left',4,4,-30,-20),('top-right',-4,4,30,-20),('bottom-left',4,-4,-30,20)]:
            before=window();x,y=before['at'];width,height=before['size']
            px=x+(width*rx if isinstance(rx,float) else (rx if rx>0 else width+rx))
            py=y+(height*ry if isinstance(ry,float) else (ry if ry>0 else height+ry))
            gesture(px,py,dx,dy)
            wait(lambda:window()['size']!=before['size'])
            assert window()['size'][0]>=width+(15 if dx else -1)
            assert window()['size'][1]>=height+(10 if dy else -1)
            selector=json.dumps('address:'+before['address'])
            ipc('eval hl.dispatch(hl.dsp.window.resize({window='+selector+f',x={width},y={height}'+'}));hl.dispatch(hl.dsp.window.move({window='+selector+f',x={x},y={y}'+'}))')
            wait(lambda:window()['size']==before['size'] and window()['at']==before['at'])
        print('PASS all four edges and four corners',flush=True)

        button('maximize');wait(lambda:window()['fullscreen']==1)
        assert diagnostics()['window']['maximized'] is True
        button('maximize');wait(lambda:window()['fullscreen']==0)
        assert window()['size']==resized['size']
        print('PASS real maximize and restore buttons',flush=True)
        before=window()
        button('minimize');wait(lambda:window()['workspace']['name'].startswith('special:swiftshell-settings-hidden'))
        command('settings','displays');wait(lambda:window()['workspace']['name']==before['workspace']['name'])
        print('PASS real minimize and Settings reactivation',flush=True)
        before=window();time.sleep(.4)
        button('close');wait(lambda:window() is None)
        command('settings','displays');wait(lambda:window() is not None);time.sleep(.6)
        wait(lambda:window()['at']==before['at'] and window()['size']==before['size'])
        print('PASS close, reopen, and persisted size/position',flush=True)
    except Exception:
        print("Window diagnostics:",diagnostics(),flush=True)
        raise
    finally:
        w=window()
        if w:
            if w.get('fullscreen'):command('window','maximize');time.sleep(.2)
            selector=json.dumps('address:'+w['address'])
            x,y=original['at'];width,height=original['size']
            ipc('eval hl.dispatch(hl.dsp.window.resize({window='+selector+f',x={width},y={height}'+'}));hl.dispatch(hl.dsp.window.move({window='+selector+f',x={x},y={y}'+'}))')
            time.sleep(.2)
            subprocess.run([sys.executable,str(ROOT/'shell/helpers/windowctl.py'),'remember','--owner-pid',str(original['pid'])],stdout=subprocess.DEVNULL,check=True)
