#!/usr/bin/env python3
"""Actual Settings profile choice/readback; restores only this test's change."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
root=Path(__file__).parents[2]
sys.path.insert(0,str(root/'shell/helpers'))
from displayctl import ipc,logical_size
import powerprofilesctl
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
command=['qs','ipc','-p',str(root/'shell'),'call','swiftshell']
def call(*args):return subprocess.check_output(command+list(args),text=True)
def state():return json.loads(call('diagnostics'))
def wait(predicate):
    for _ in range(120):
        if predicate():return
        time.sleep(.05)
    raise AssertionError('Power profile did not reach its observed state')
def window():return next(w for w in json.loads(ipc('j/clients')) if w.get('title')=='SwiftShell Settings' and w.get('class')=='org.quickshell')
def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
original_state=state();original_profile=powerprofilesctl.run()['active']
original_window=json.loads(ipc('j/activewindow')).get('address');cursor=json.loads(ipc('j/cursorpos'))
monitors=json.loads(ipc('j/monitors'));focus=next(m['name'] for m in monitors if m['focused'])
test_profile=None
try:
    call('settings','power')
    wait(lambda:state()['window'] is not None and not state()['windowBusy'] and state()['window'].get('pageGeometry') and len(state()['window']['pageGeometry']['profiles'])>=2)
    own=window();geometry=state()['window']['pageGeometry']
    test_profile=next((profile['id'] for profile in geometry['profiles'] if profile['id']=='balanced' and profile['id']!=original_profile and profile['enabled']),None)
    if test_profile is None:test_profile=next(profile['id'] for profile in geometry['profiles'] if profile['id']!=original_profile and profile['enabled'])
    with tempfile.TemporaryDirectory(prefix='swiftshell-power-pointer-') as temporary:
        temp=Path(temporary);protocol=root/'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner','client-header',str(protocol),str(temp/'pointer-client.h')],check=True)
        subprocess.run(['wayland-scanner','private-code',str(protocol),str(temp/'pointer-protocol.c')],check=True)
        subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(temp),str(root/'tests/helpers/settings-pointer.c'),str(temp/'pointer-protocol.c'),'-o',str(temp/'pointer'),'-lwayland-client'],check=True)
        def click(profile_id):
            w=window();assert w['pid']==own['pid']
            row=next(row for row in state()['window']['pageGeometry']['profiles'] if row['id']==profile_id)
            x=round(w['at'][0]+row['x']+row['width']/2);y=round(w['at'][1]+row['y']+row['height']/2)
            assert w['at'][0]<=x<w['at'][0]+w['size'][0] and w['at'][1]<=y<w['at'][1]+w['size'][1]
            monitor=next(m for m in monitors if m['x']<=x<m['x']+logical_size(m)[0] and m['y']<=y<m['y']+logical_size(m)[1])
            width,height=map(round,logical_size(monitor))
            args=[str(temp/'pointer'),str(x-monitor['x']),str(y-monitor['y']),str(width),str(height),'0','0',monitor['name'],str(x),str(y)]
            for _ in range(3):
                result=subprocess.run(args)
                if result.returncode==0:return
                if result.returncode!=6:result.check_returncode()
                time.sleep(.15)
            result.check_returncode()
        click(test_profile)
        wait(lambda:state()['window']['pageGeometry']['active']==test_profile and not state()['window']['pageGeometry']['busy'])
        assert powerprofilesctl.run()['active']==test_profile
        click(original_profile)
        wait(lambda:state()['window']['pageGeometry']['active']==original_profile and not state()['window']['pageGeometry']['busy'])
        assert powerprofilesctl.run()['active']==original_profile
    print('PASS actual Settings power-profile pointer selection, D-Bus readback, and exact original profile restoration')
finally:
    actual=powerprofilesctl.run()['active']
    if test_profile and actual==test_profile:powerprofilesctl.run('set',original_profile)
    call('settings',original_state['category']);wait(lambda:not state()['windowBusy'])
    if not original_state['settingsOpen']:call('window','close');wait(lambda:not state()['settingsOpen'])
    wait(lambda:state()['settingsPersistence']=='ready')
    if original_window and any(w['address']==original_window for w in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+original_window)+'})')
    dispatch('hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'})')
    dispatch('hl.dsp.focus({monitor='+json.dumps(focus)+'})')
