#!/usr/bin/env python3
"""Real pointer popup regression with synthetic APs and a fake helper only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
original_window=json.loads(ipc('j/activewindow')).get('address')
original_cursor=json.loads(ipc('j/cursorpos'))
original_monitors=json.loads(ipc('j/monitors'));monitor=next(item for item in original_monitors if item['focused'])
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
def wait(predicate):
    for _ in range(120):
        try:
            if predicate():return
        except (ValueError,KeyError,subprocess.CalledProcessError):pass
        time.sleep(.05)
    raise AssertionError('Native network auth fixture did not become ready')
with tempfile.TemporaryDirectory(prefix='swiftshell-network-auth-') as temp:
    folder=Path(temp);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
    shutil.copy2(root/'tests/live/network-auth.qml',folder/'shell/NetworkAuth.qml')
    config=folder/'config/swiftshell';config.mkdir(parents=True);shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
    fixture=folder/'shell/helpers/networkctl.py'
    fixture.write_text('''import json,os\nfrom pathlib import Path\np=Path(os.environ['XDG_STATE_HOME'])/'fixture-radio.json'\np.parent.mkdir(parents=True,exist_ok=True)\nwifi=json.loads(p.read_text()) if p.exists() else True\nrequest=json.loads(input())\nif request['action']=='wifi-radio':wifi=request['enabled'];p.write_text(json.dumps(wifi))\nnetworks=[dict(id='AA:BB:CC:DD:EE:'+format(i,'02X'),name='Owned test network '+str(i),security='WPA2',device='wlan-fixture',signal=80,active=False,supported=True) for i in range(40)]\nprint(json.dumps(dict(ok=True,available=True,wifiEnabled=wifi,wifiHardware=True,devices=[dict(id='wlan-fixture',kind='wifi',state='disconnected',connected=False,available=wifi,connection='',addresses=[])],profiles=[],networks=networks if wifi else [])))\n''')
    for protocol,prefix,source,libs in [('wlr-virtual-pointer-unstable-v1.xml','pointer','settings-pointer.c',['-lwayland-client']),('virtual-keyboard-unstable-v1.xml','keyboard','launcher-keyboard.c',['-lwayland-client','-lxkbcommon'])]:
        subprocess.run(['wayland-scanner','client-header',str(root/'tests/protocols'/protocol),str(folder/(prefix+'-client.h'))],check=True)
        subprocess.run(['wayland-scanner','private-code',str(root/'tests/protocols'/protocol),str(folder/(prefix+'-protocol.c'))],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(root/'tests/helpers'/source),str(folder/(prefix+'-protocol.c')),'-o',str(folder/prefix)]+libs,check=True)
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    path=folder/'shell/NetworkAuth.qml';log=(folder/'audit.log').open('w')
    process=subprocess.Popen(['qs','-p',str(path)],env=env,stdout=log,stderr=subprocess.STDOUT)
    qs=['qs','ipc','-p',str(path),'call','networkAudit']
    def call(*args):return subprocess.check_output(qs+list(args),text=True)
    def state():return json.loads(call('state'))
    def own():return next((item for item in json.loads(ipc('j/clients')) if item.get('pid')==process.pid and item.get('title')=='SwiftShell Network Auth Audit'),None)
    def click(rect):
        window=own();assert window and rect
        x=round(window['at'][0]+rect['x']+rect['width']/2);y=round(window['at'][1]+rect['y']+rect['height']/2)
        assert window['at'][0]<=x<window['at'][0]+window['size'][0] and window['at'][1]<=y<window['at'][1]+window['size'][1]
        output=next(item for item in original_monitors if item['x']<=x<item['x']+logical_size(item)[0] and item['y']<=y<item['y']+logical_size(item)[1])
        width,height=map(round,logical_size(output))
        command=[str(folder/'pointer'),str(x-output['x']),str(y-output['y']),str(width),str(height),'0','0',output['name'],str(x),str(y)]
        for _ in range(3):
            result=subprocess.run(command)
            if result.returncode==0:return
            if result.returncode!=6:result.check_returncode()
            time.sleep(.15)
        result.check_returncode()
    try:
        wait(lambda:own() is not None and state()['ready'])
        selector=json.dumps('address:'+own()['address'])
        dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
        dispatch('hl.dsp.window.resize({window='+selector+',x=1000,y=700})')
        dispatch('hl.dsp.window.move({window='+selector+',x='+str(monitor['x']+100)+',y='+str(monitor['y']+80)+'})')
        dispatch('hl.dsp.focus({window='+selector+'})');time.sleep(.25)
        call('scroll','500');wait(lambda:state()['ap'] is not None)
        click(state()['ap']);wait(lambda:state()['authOpen'] and state()['passwordFocused'])
        current=state();rect=current['password']
        assert 0<=rect['x'] and rect['x']+rect['width']<=current['width']
        assert 0<=rect['y'] and rect['y']+rect['height']<=current['height']
        subprocess.run([str(folder/'keyboard'),'escape'],check=True)
        wait(lambda:not state()['authOpen'] and state()['secretEmpty'])
        call('scroll','0');time.sleep(.1)
        click(state()['toggle']);wait(lambda:state()['confirmationOpen'])
        current=state();rect=current['confirmBox'];assert 0<=rect['y'] and rect['y']+rect['height']<=current['height']
        click(current['confirm']);wait(lambda:not state()['confirmationOpen'] and not state()['wifiEnabled'] and state()['ready'])
        print('PASS native scrolled AP click opens a focused visible password popup; Escape clears; radio-off confirmation is visible and changes only fixture state')
    except Exception:
        log.flush()
        shutil.copy2(folder/'audit.log','/tmp/swiftshell-network-auth-qml.log')
        raise
    finally:
        subprocess.run(['qs','kill','-p',str(path)],stdout=subprocess.DEVNULL,check=False)
        process.wait(timeout=5);log.close()
        if original_window and any(item.get('address')==original_window for item in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+original_window)+'})')
        dispatch('hl.dsp.cursor.move({x='+str(original_cursor['x'])+',y='+str(original_cursor['y'])+'})')
        dispatch('hl.dsp.focus({monitor='+json.dumps(monitor['name'])+'})')
