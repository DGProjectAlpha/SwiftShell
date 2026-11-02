#!/usr/bin/env python3
"""Actual checkbox save and scoped SwiftShell restart, with preference restoration."""
import argparse,json,os,subprocess,sys,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2];sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def wait(predicate):
    for _ in range(120):
        try:
            if predicate():return
        except (json.JSONDecodeError,subprocess.CalledProcessError,KeyError,TypeError):pass
        time.sleep(.05)
    raise AssertionError('Bar persistence did not reach its expected state')
def bar(name):return next(bar for bar in state()['barSurfaces'] if bar['output']==name)
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'swiftshell/settings.json'
def prefs():return json.loads(config.read_text())['bar']
monitors=json.loads(ipc('j/monitors'));monitor=monitors[0];name=monitor['name']
saved_state=state();saved=prefs();overrides=json.loads(saved.get('hiddenOutputsJson','{}'));original_override=overrides.get(name)
current=overrides.get(name,saved.get('hiddenModules',[]));expected=list(current)
if 'search' in expected:expected.remove('search')
else:expected.append('search')
focus=next(m['name'] for m in monitors if m['focused']);cursor=json.loads(ipc('j/cursorpos'))
try:
    call('launcher','close')
    for m in monitors:call('barPanel',m['name'],'close')
    with tempfile.TemporaryDirectory(prefix='swiftshell-bar-save-') as temporary:
        folder=Path(temporary);protocol=root/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'pointer-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'pointer-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers/settings-pointer.c'),str(folder/'pointer-protocol.c'),'-o',str(folder/'pointer'),'-lwayland-client'],check=True)
        def click(x,y,button):
            w,h=map(round,logical_size(monitor));x,y=round(x),round(y)
            args=[str(folder/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(w),str(h),'0','0',name,str(x),str(y),button]
            for _ in range(3):
                result=subprocess.run(args)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                time.sleep(.15)
            result.check_returncode()
        click(monitor['x']+logical_size(monitor)[0]*.35,monitor['y']+bar(name)['height']/2,'right')
        wait(lambda:bar(name)['menu']['visible'] and bar(name)['menu']['id']=='customize')
        time.sleep(.2)
        menu=bar(name)['menu']['geometry'];item=next(item for item in menu['items'] if item['module']=='search')
        click(menu['x']+item['x']+item['width']/2,menu['y']+item['y']+item['height']/2,'left')
        wait(lambda:state()['settingsPersistence']=='ready' and json.loads(prefs()['hiddenOutputsJson']).get(name)==expected)
    call('barPanel',name,'close')
    subprocess.run(['qs','kill','-p',str(root/'shell')],check=True)
    for _ in range(100):
        if 'Config path: '+str(root/'shell/shell.qml') not in subprocess.check_output(['qs','list','--all'],text=True):break
        time.sleep(.05)
    else:raise AssertionError('Matching SwiftShell instance did not stop')
    subprocess.run(['qs','-p',str(root/'shell'),'--no-duplicate','--daemonize'],check=True)
    wait(lambda:state()['settingsPersistence']=='ready' and len(state()['barSurfaces'])==len(monitors))
    call('developmentWatching','false')
    actual=sum(bar(name)['modules'].values(),[])
    assert ('search' not in actual)==('search' in expected)
    assert json.loads(prefs()['hiddenOutputsJson'])[name]==expected
    print('PASS actual bar checkbox, atomic disk save, full SwiftShell restart and per-output visibility readback',flush=True)
finally:
    if original_override is None:call('moduleInherit',name)
    else:call('moduleVisibility',name,' '+json.dumps(original_override))
    wait(lambda:state()['settingsPersistence']=='ready' and json.loads(prefs()['hiddenOutputsJson']).get(name)==original_override)
    if saved_state['settingsOpen']:call('settings',saved_state['category']);wait(lambda:state()['settingsOpen'] and not state()['windowBusy'])
    assert ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'}))').strip()=='ok'
    assert ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(focus)+'}))').strip()=='ok'
