#!/usr/bin/env python3
"""Real date/time context, dedicated panel and native tray menu input checks."""
import argparse,json,os,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def bar(name):return next(bar for bar in state()['barSurfaces'] if bar['output']==name)
def wait(predicate):
    for _ in range(100):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Bar input did not reach its expected state')
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
saved_clock=json.loads(config.read_text())['clock'];saved_tools=call('clockTool','snapshot','')
monitors=json.loads(ipc('j/monitors'));focus=next(m['name'] for m in monitors if m['focused'])
cursor=json.loads(ipc('j/cursorpos'));active=json.loads(ipc('j/activewindow')).get('address')
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
try:
    call('launcher','close')
    call('clockOptions',str(saved_clock['use24Hour']).lower(),str(saved_clock.get('showSeconds',False)).lower(),'true',saved_clock.get('dateFormat','short'))
    with tempfile.TemporaryDirectory(prefix='swiftshell-bar-inputs-') as directory:
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
            wait(lambda:bar(name)['clockTargets']['date']['visible'])
            pointer(m,bar(name)['clockTargets']['date'])
            wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['geometry']['details']['tab']=='calendar')
            pointer(m,bar(name)['clockTargets']['time'])
            wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['geometry']['details']['tab']=='clock')
            pointer(m,bar(name)['clockTargets']['time'])
            wait(lambda:not bar(name)['menu']['visible'])
            print('PASS actual date→Calendar and time→Clock click context on',name,flush=True)
            for panel in ['control','network','power']:
                call('barPanel',name,panel)
                wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['id']==panel)
                menu=bar(name)['menu'];assert menu['blurBounds']['width'] if 'blurBounds' in menu else menu['width']>100
                subprocess.run([str(directory/'keyboard'),'escape'],check=True)
                wait(lambda:not bar(name)['menu']['visible'])
            print('PASS dedicated Audio, Network & Devices and Power panels with Escape on',name,flush=True)
            tray=next((item for item in bar(name)['tray'] if item['hasMenu']),None)
            if tray:
                pointer(m,tray,'right')
                wait(lambda:any(item['id']==tray['id'] and item['menuOpen'] for item in bar(name)['tray']))
                assert not bar(name)['menu']['visible'],'Tray right-click must not open bar customization'
                subprocess.run([str(directory/'keyboard'),'escape'],check=True)
                wait(lambda:all(not item['menuOpen'] for item in bar(name)['tray']))
                print('PASS native tray context menu open/Escape, no app action invoked, on',name,flush=True)
finally:
    for m in monitors:call('barPanel',m['name'],'close')
    call('clockOptions',str(saved_clock['use24Hour']).lower(),str(saved_clock.get('showSeconds',False)).lower(),str(saved_clock.get('showDate',False)).lower(),saved_clock.get('dateFormat','short'))
    call('clockTool','restore',saved_tools)
    wait(lambda:state()['settingsPersistence']=='ready')
    if active and any(w['address']==active for w in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+active)+'})')
    dispatch('hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'})')
    dispatch('hl.dsp.focus({monitor='+json.dumps(focus)+'})')
