#!/usr/bin/env python3
"""Private-bus native themed DBusMenu regression; synthetic actions only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
root=Path(__file__).parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.add_argument('--inside',action='store_true')
args=parser.parse_args()
if not args.inside:
    raise SystemExit(subprocess.run(['dbus-run-session','--',sys.executable,__file__,'--live','--inside'],env=dict(os.environ,QT_QPA_PLATFORMTHEME='generic',QT_QUICK_CONTROLS_STYLE='Basic',NO_AT_BRIDGE='1')).returncode)
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size

def wait(predicate,description='native tray menu state'):
    for _ in range(120):
        try:
            if predicate():return
        except (ValueError,KeyError,subprocess.SubprocessError):pass
        time.sleep(.05)
    raise AssertionError(description+' did not become ready')

def fixture_state():
    text=subprocess.check_output(['busctl','--user','call','org.swiftshell.TrayFixture','/Menu','org.swiftshell.TrayFixture','State'],text=True,stderr=subprocess.DEVNULL)
    return json.loads(json.loads(text.removeprefix('s ').strip()))

monitors=json.loads(ipc('j/monitors'))
original_cursor=json.loads(ipc('j/cursorpos'))
original_monitor=next(monitor['name'] for monitor in monitors if monitor['focused'])
original_window=json.loads(ipc('j/activewindow')).get('address')
fixture=None;process=None
try:
    with tempfile.TemporaryDirectory(prefix='swiftshell-themed-tray-') as directory:
        folder=Path(directory);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
        shutil.copy2(root/'tests/live/tray-menu.qml',folder/'shell/TrayMenuAudit.qml')
        config=folder/'config/swiftshell';config.mkdir(parents=True)
        shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
        fixture=subprocess.Popen([sys.executable,str(root/'tests/helpers/tray-menu-fixture.py')],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        wait(lambda:fixture.poll() is None and fixture_state() is not None,'private DBusMenu fixture')
        for protocol,prefix,source,libraries in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
            subprocess.run(['wayland-scanner','client-header',str(root/'tests/protocols'/protocol),str(folder/(prefix+'-client.h'))],check=True)
            subprocess.run(['wayland-scanner','private-code',str(root/'tests/protocols'/protocol),str(folder/(prefix+'-protocol.c'))],check=True)
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers'/source),str(folder/(prefix+'-protocol.c')),'-o',str(folder/prefix)]+libraries,check=True)
        for monitor in monitors:
            log_path=folder/(monitor['name']+'.log')
            with log_path.open('w') as log:
                process=subprocess.Popen(['qs','-p',str(folder/'shell/TrayMenuAudit.qml')],env=dict(os.environ,XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'),SWIFTSHELL_TRAY_OUTPUT=monitor['name']),stdout=log,stderr=subprocess.STDOUT)
                command=['qs','ipc','-p',str(folder/'shell/TrayMenuAudit.qml'),'call','audit']
                def call(*arguments):return subprocess.check_output(command+list(arguments),text=True,stderr=subprocess.DEVNULL)
                def state():return json.loads(call('state'))
                def menu():
                    for _ in range(50):
                        result=state()['menu']
                        if not result.get('visible'):return result
                        observed=[item for level in json.loads(ipc('j/layers')).get(monitor['name'],{}).get('levels',{}).values() for item in level if item.get('namespace')=='swiftshell-tray-menu']
                        if len(observed)==1 and all(abs(result[field]-observed[0][key])<=1 for field,key in [('x','x'),('y','y'),('width','w'),('height','h')]):return result
                        time.sleep(.03)
                    raise AssertionError('Themed tray geometry did not settle against the actual compositor layer')
                def click(index):
                    geometry=menu();entry=next(item for item in geometry['items'] if item['index']==index)
                    x=round(geometry['x']+entry['x']+entry['width']/2);y=round(geometry['y']+entry['y']+entry['height']/2)
                    assert geometry['x']<=x<geometry['x']+geometry['width'] and geometry['y']<=y<geometry['y']+geometry['height']
                    width,height=map(round,logical_size(monitor))
                    arguments=[str(folder/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(width),str(height),'0','0',monitor['name'],str(x),str(y)]
                    for _ in range(3):
                        result=subprocess.run(arguments)
                        if result.returncode==0:return
                        if result.returncode!=6:result.check_returncode()
                        time.sleep(.2)
                    result.check_returncode()
                def open_menu():
                    assert call('openMenu').strip()=='true'
                    wait(lambda:menu().get('visible') and len(menu().get('items',[]))>=6,'themed menu layout')
                    time.sleep(.1)
                wait(lambda:state()['ready'] and state()['count']==1 and state()['menuAvailable'],'native StatusNotifier menu handle')
                open_menu()
                assert menu()['blurApplied'],'Native rounded backdrop region must be attached'
                assert menu()['radius']>0 and menu()['color']!='#ffffff'
                initial=fixture_state()
                click(1);time.sleep(.15)
                assert fixture_state()['events']==initial['events'],'Disabled menu action must not trigger'
                assert menu()['visible']
                checked=next(item for item in menu()['items'] if item['index']==3)
                radio=next(item for item in menu()['items'] if item['index']==4)
                assert checked['buttonType']==1 and checked['checkState']==(2 if initial['checked'] else 0)
                assert radio['buttonType']==2 and radio['checkState']==2
                capture=Path('/tmp')/('swiftshell-themed-tray-'+monitor['name']+'.png')
                capture.unlink(missing_ok=True)
                assert call('capture',str(capture)).strip()=='true'
                try:wait(capture.is_file,'owned menu frame capture')
                except AssertionError:
                    log.flush();print(log_path.read_text(),file=sys.stderr);raise
                click(5);wait(lambda:menu().get('depth')==2 and len(menu().get('items',[]))==3,'actual native submenu')
                wait(lambda:[6,'opened'] in fixture_state()['events'],'native submenu opened lifecycle')
                assert 0 in fixture_state()['opens'],'Native root preparation must receive AboutToShow'
                click(-1);wait(lambda:menu().get('depth')==1,'submenu Back')
                click(3);wait(lambda:not state()['open'],'action dismissal')
                wait(lambda:fixture_state()['checked']!=initial['checked'],'real checkbox DBus action')
                assert [4,'clicked'] in fixture_state()['events']
                open_menu();click(5);wait(lambda:menu().get('depth')==2)
                click(0);wait(lambda:not state()['open'])
                assert [7,'clicked'] in fixture_state()['events'],'Nested action must reach the original application entry'
                open_menu()
                subprocess.run([str(folder/'keyboard'),'escape'],check=True)
                wait(lambda:not state()['open'],'Escape releases native menu')
                dark_color=None
                for mode in ['light','dark']:
                    call('theme',mode);wait(lambda:state()['ready'] and state()['light']==(mode=='light'),'shared tray theme')
                    open_menu()
                    assert menu()['blurApplied'] and menu()['radius']>0
                    if mode=='light':dark_color=menu()['color']
                    else:assert menu()['color']!=dark_color,'Theme changes must recolor the real menu surface'
                    capture=Path('/tmp')/('swiftshell-themed-tray-'+monitor['name']+'-'+mode+'.png')
                    capture.unlink(missing_ok=True)
                    assert call('capture',str(capture)).strip()=='true';wait(capture.is_file,'owned themed menu frame')
                    subprocess.run([str(folder/'keyboard'),'escape'],check=True);wait(lambda:not state()['open'])
                # This coordinate lies in the owned test bar, outside its tray icon.
                # It exercises the bar dismissal signal without clicking a client.
                open_menu()
                x=monitor['x']+124;y=monitor['y']+118
                width,height=map(round,logical_size(monitor))
                subprocess.run([str(folder/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(width),str(height),'0','0',monitor['name'],str(x),str(y)],check=True)
                wait(lambda:not state()['open'],'blank-bar dismissal')
                print('PASS native themed tray:',monitor['name'],'real enabled/disabled/check/radio/submenu actions, dark/light shared frost, Escape, blank-bar dismissal and compositor geometry',flush=True)
                process.terminate();process.wait(timeout=5);process=None
                assert not any(item.get('namespace')=='swiftshell-tray-menu' for output in json.loads(ipc('j/layers')).values() for level in output.get('levels',{}).values() for item in level),'Fixture must release every menu layer'
                log_text=log_path.read_text()
                assert not any(marker in log_text for marker in ['ReferenceError','TypeError','Binding loop']),log_text
except Exception:
    if 'log_path' in locals() and log_path.is_file():print(log_path.read_text(),file=sys.stderr)
    if process and process.poll() is not None:
        print('Native fixture process exited unexpectedly.',file=sys.stderr)
    raise
finally:
    if process and process.poll() is None:process.terminate();process.wait(timeout=5)
    if fixture and fixture.poll() is None:fixture.terminate();fixture.wait(timeout=5)
    if original_window and any(client.get('address')==original_window for client in json.loads(ipc('j/clients'))):
        ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+original_window)+'}))')
    ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(original_cursor['x'])+',y='+str(original_cursor['y'])+'}))')
    ipc('eval hl.dispatch(hl.dsp.focus({monitor='+json.dumps(original_monitor)+'}))')
