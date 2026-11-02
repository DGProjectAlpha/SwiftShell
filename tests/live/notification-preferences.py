#!/usr/bin/env python3
"""Native atomic preference/restart regression for notification customization only."""
import argparse,json,os,shutil,subprocess,tempfile,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-notification-prefs-') as directory:
 folder=Path(directory);shell=folder/'shell';shutil.copytree(root/'shell',shell)
 config=folder/'config/swiftshell';config.mkdir(parents=True);path=config/'settings.json';shutil.copy2(root/'shell/config/defaults.json',path)
 fixture={'quietHoursEnabled':True,'quietStart':1350,'quietEnd':435,'quietDays':31,'previewMode':'app-only','soundEnabled':True,'soundVolume':.17}
 qml=shell/'PreferenceAudit.qml';qml.write_text('''//@ pragma ShellId swiftshell-notification-preference-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
Scope {
 Component.onCompleted:Quickshell.watchFiles=false
 IpcHandler {
  target:"audit"
  function state():string{return JSON.stringify({ready:SettingsStore.persistenceState==="ready",preferences:SettingsStore.snapshot().notifications})}
  function save(value:string):bool{return SettingsStore.setNotificationPreferences(JSON.parse(value))}
 }
}
''')
 env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
 command=['qs','ipc','-p',str(qml),'call','audit']
 def call(*args):return subprocess.check_output(command+list(args),env=env,text=True,stderr=subprocess.DEVNULL).strip()
 def state():return json.loads(call('state'))
 def wait(predicate):
  for _ in range(150):
   try:
    if predicate():return
   except (ValueError,subprocess.CalledProcessError):pass
   time.sleep(.05)
  raise AssertionError('Native notification preferences did not settle')
 for phase in ['save','restart']:
  with (folder/'runtime.log').open('a') as log:
   process=subprocess.Popen(['qs','-p',str(qml)],env=env,stdout=log,stderr=subprocess.STDOUT)
   try:
    wait(lambda:state()['ready'])
    if phase=='save':
     assert call('save',json.dumps(fixture))=='true'
     wait(lambda:state()['ready'] and all(json.loads(path.read_text())['notifications'].get(key)==value for key,value in fixture.items()))
     before=path.read_bytes();assert call('save',json.dumps({'quietDays':0}))=='false';time.sleep(.2);assert path.read_bytes()==before
    else:
     assert all(state()['preferences'][key]==value for key,value in fixture.items())
     print('PASS actual notification preferences atomic save, invalid-value rejection and complete process-restart readback')
   finally:
    process.terminate()
    try:process.wait(timeout=3)
    except subprocess.TimeoutExpired:process.kill();process.wait()
