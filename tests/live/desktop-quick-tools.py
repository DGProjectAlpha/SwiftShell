#!/usr/bin/env python3
"""Actual bar quick-action clicks and focus; no capture or clipboard mutation."""
import argparse,json,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def bar(name):return next(b for b in state()['barSurfaces'] if b['output']==name)
def wait(predicate):
 for _ in range(120):
  if predicate():return
  time.sleep(.05)
 raise AssertionError('Quick tool did not reach its expected state')
monitors=json.loads(ipc('j/monitors'));focus=next(m['name'] for m in monitors if m['focused'])
cursor=json.loads(ipc('j/cursorpos'));active=json.loads(ipc('j/activewindow')).get('address')
pinned=state()['desktopTools']['clipboard']['open']
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
try:
    call('launcher','close')
    with tempfile.TemporaryDirectory(prefix='swiftshell-quick-tools-') as directory:
        directory=Path(directory)
        for protocol,name,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
            path=root/'tests/protocols'/protocol
            subprocess.run(['wayland-scanner','client-header',str(path),str(directory/(name+'-client.h'))],check=True)
            subprocess.run(['wayland-scanner','private-code',str(path),str(directory/(name+'-protocol.c'))],check=True)
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(directory),str(root/'tests/helpers'/source),str(directory/(name+'-protocol.c')),'-o',str(directory/name)]+libs,check=True)
        def pointer(m,rectangle,button='left'):
            x=round(m['x']+rectangle['x']+rectangle['width']/2);y=round(m['y']+rectangle['y']+rectangle['height']/2)
            w,h=map(round,logical_size(m));args=[str(directory/'pointer'),str(x-m['x']),str(y-m['y']),str(w),str(h),'0','0',m['name'],str(x),str(y),button]
            for _ in range(3):
                result=subprocess.run(args)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                time.sleep(.15)
            result.check_returncode()
        for m in monitors:
            name=m['name']
            for other in monitors:call('barPanel',other['name'],'close')
            layout=bar(name)['layout']
            assert layout['left']['x']+layout['left']['width']<=layout['center']['x']+.5
            assert layout['center']['x']+layout['center']['width']<=layout['right']['x']+.5
            pointer(m,bar(name)['quickTools']['screenshot'])
            wait(lambda:state()['desktopTools']['screenshot']['visible'])
            subprocess.run([str(directory/'keyboard'),'escape'],check=True)
            wait(lambda:not state()['desktopTools']['screenshot']['visible'])
            for tool in ['clipboard','performance']:
                pointer(m,bar(name)['quickTools'][tool])
                wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['id']==tool)
                assert bar(name)['menu']['width']>200
                subprocess.run([str(directory/'keyboard'),'escape'],check=True)
                wait(lambda:not bar(name)['menu']['visible'])
            call('clipboardWindow','open')
            wait(lambda:state()['desktopTools']['clipboard']['ready'])
            call('clipboardWindow','close')
            wait(lambda:not state()['desktopTools']['clipboard']['open'])
            print('PASS '+name+': actual screenshot/clipboard/performance clicks, Escape, pinned window and bar bounds',flush=True)
        call('launcher','open');call('launcherQuery','screenshot')
        wait(lambda:any(row['kind']=='screenshot' for row in state()['spotlight']['card']['providers']))
        call('launcher','close')
        wait(lambda:state()['desktopTools']['performance']['cpu']['usage'] is not None)
        assert state()['desktopTools']['performance']['gpus']
        print('PASS live screenshot search and CPU/RAM/NVIDIA telemetry without clipboard/capture side effects',flush=True)
finally:
    for m in monitors:call('barPanel',m['name'],'close')
    call('clipboardWindow','open' if pinned else 'close')
    if active and any(w['address']==active for w in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+active)+'})')
    dispatch('hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'})')
    dispatch('hl.dsp.focus({monitor='+json.dumps(focus)+'})')
