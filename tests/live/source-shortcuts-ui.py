#!/usr/bin/env python3
"""Actual source-backed shortcut recorder and Undo using a private no-op action."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).parents[2]
sys.path.insert(0,str(ROOT/'shell/helpers'))
from displayctl import ipc
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()

def wait(predicate,message):
    for _ in range(120):
        try:
            result=predicate()
            if result:return result
        except (subprocess.CalledProcessError,ValueError):pass
        time.sleep(.05)
    raise AssertionError(message)

before=json.loads(ipc('j/binds'))
assert not any(b.get('modmask')==68 and str(b.get('key')).casefold()=='f30' for b in before),'Private source audit chord is occupied.'
assert not any(b.get('modmask')==68 and str(b.get('key')).casefold()=='f12' for b in before),'Test chord is already occupied.'
active=json.loads(ipc('j/activewindow')).get('address')
live_command=['qs','ipc','-p',str(ROOT/'shell'),'call','swiftshell']
launcher_before=json.loads(subprocess.check_output(live_command+['diagnostics'],text=True))['launcherOpen']
assert not launcher_before,'Close Spotlight before running the shortcut capture audit.'
with tempfile.TemporaryDirectory(prefix='swiftshell-shortcuts-native-') as folder:
    folder=Path(folder);shell=folder/'shell';shutil.copytree(ROOT/'shell',shell)
    qml=(ROOT/'tests/live/shortcuts-audit.qml').read_text()
    qml=qml.replace('actions:Services.ShortcutsService.actions','actions:Services.ShortcutsService.actions,effective:Services.ShortcutsService.effective')
    qml=qml.replace('page.startRecording("settings")','page.startRecording(Services.ShortcutsService.effective.find(function(row){return row.label==="SwiftShell source UI audit"}).sourceId,"Private desktop action")')
    qml=qml.replace('Services.ShortcutsService.apply("settings",page.draftModifiers,page.draftKey)','Services.ShortcutsService.apply(page.recordingId,page.draftModifiers,page.draftKey)')
    qml=qml.replace('Services.ShortcutsService.remove("settings")','Services.ShortcutsService.undo()')
    (shell/'Audit.qml').write_text(qml)
    qmdir=shell/'services/qmldir'
    if 'ShortcutsService ' not in qmdir.read_text():qmdir.write_text(qmdir.read_text()+'\nsingleton ShortcutsService 1.0 ShortcutsService.qml\n')
    for name in ['config/swiftshell','state','cache']:(folder/name).mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'shell/config/defaults.json',folder/'config/swiftshell/settings.json')
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    source=folder/'config/hypr/hyprland.lua';source.parent.mkdir(parents=True)
    original='hl.bind("CTRL + SUPER + F30",function() end,{description="SwiftShell source UI audit"})\n'
    source.write_text(original);source.chmod(0o640)
    protocol=ROOT/'tests/protocols/virtual-keyboard-unstable-v1.xml' 
    subprocess.run(['wayland-scanner','client-header',str(protocol),str(folder/'keyboard-client.h')],check=True)
    subprocess.run(['wayland-scanner','private-code',str(protocol),str(folder/'keyboard-protocol.c')],check=True)
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-I'+str(folder),str(ROOT/'tests/helpers/shortcuts-keyboard.c'),str(folder/'keyboard-protocol.c'),'-lwayland-client','-lxkbcommon','-o',str(folder/'keyboard')],check=True)
    command=['qs','ipc','-p',str(shell/'Audit.qml'),'call','audit']
    def call(*args):return subprocess.check_output(command+list(args),text=True,stderr=subprocess.DEVNULL)
    def state():return json.loads(call('status'))
    def dispatch(code):assert ipc('eval hl.dispatch('+code+')').strip()=='ok'
    log=open(folder/'audit.log','w')
    assert ipc('eval '+original).strip()=='ok'
    process=subprocess.Popen(['qs','-p',str(shell/'Audit.qml')],env=env,stdout=log,stderr=log)
    applied=False
    try:
        def own():return next((w for w in json.loads(ipc('j/clients')) if w.get('pid')==process.pid and w.get('title')=='SwiftShell Shortcut Audit'),None)
        window=wait(own,'Audit window did not map')
        selector=json.dumps('address:'+window['address'])
        dispatch('hl.dsp.window.float({window='+selector+',action="enable"})')
        dispatch('hl.dsp.focus({window='+selector+'})')
        wait(lambda:not state()['busy'],'Shortcut service did not become ready')
        call('record');wait(lambda:state()['recording']['active'],'Compositor did not enable shortcut inhibition')
        subprocess.run([str(folder/'keyboard'),'toggle'],check=True)
        wait(lambda:state()['recording']['key']=='Space','Captured Super+Space did not reach recorder')
        assert state()['recording']['modifiers']==['super'],state()['recording']
        assert not json.loads(subprocess.check_output(live_command+['diagnostics'],text=True))['launcherOpen'],'Recording executed the existing global shortcut!'
        subprocess.run([str(folder/'keyboard'),'managed'],check=True)
        wait(lambda:state()['recording']['key']=='F12','Captured managed chord did not reach recorder')
        assert state()['recording']['modifiers']==['ctrl','super']
        call('apply');applied=True
        wait(lambda:not state()['busy'] and any(a['label']=='SwiftShell source UI audit' and a['chord'].endswith('F12') for a in state()['effective']),'Managed shortcut did not apply')
        assert not state()['error'],state()['error']
        assigned=[b for b in json.loads(ipc('j/binds')) if b.get('description')=='SwiftShell source UI audit']
        assert len(assigned)==1 and assigned[0]['modmask']==68 and assigned[0]['key']=='F12'
        call('remove');wait(lambda:not state()['busy'] and any(a['label']=='SwiftShell source UI audit' and a['chord'].endswith('F30') for a in state()['effective']),'Managed shortcut did not remove')
        applied=False
        assert source.read_text()==original and source.stat().st_mode&0o777==0o640
        assert [b for b in json.loads(ipc('j/binds')) if b.get('description')!='SwiftShell source UI audit']==before,'Existing Hyprland shortcuts changed!'
        print('PASS native source recorder: Super+Space inhibited, real Ctrl+Super+F12 source apply and exact Undo; unrelated bindings unchanged')
    except Exception:
        log.flush();print((folder/'audit.log').read_text(),file=sys.stderr);raise
    finally:
        if applied:
            subprocess.run(['python3',str(shell/'helpers/shortcutsctl.py'),'undo'],env=env,stdout=subprocess.DEVNULL,check=False)
        subprocess.run(['qs','kill','-p',str(shell/'Audit.qml')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
        try:process.wait(timeout=4)
        except subprocess.TimeoutExpired:process.terminate();process.wait(timeout=4)
        log.close()
        assert ipc('eval hl.unbind("CTRL + SUPER + F30"); hl.unbind("CTRL + SUPER + F12")').strip()=='ok'
        assert json.loads(ipc('j/binds'))==before
        if active and any(w.get('address')==active for w in json.loads(ipc('j/clients'))):dispatch('hl.dsp.focus({window='+json.dumps('address:'+active)+'})')
