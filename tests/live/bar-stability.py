#!/usr/bin/env python3
"""Opt-in native hidden-bar lifetime regression with isolated preferences."""
import argparse
from pathlib import Path
import os,shutil,subprocess,tempfile,re,sys
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-flicker-before-') as folder:
 folder=Path(folder);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
 bar=folder/'shell/bar/ModuleStrip.qml';text=re.sub(r'                required property var (modelData|entry)', lambda m:'                Component.onCompleted: console.info("AUDIT module created")\n                Component.onDestruction: console.info("AUDIT module destroyed")\n'+m.group(0),bar.read_text(),count=1);bar.write_text(text)
 workspace=folder/'shell/bar/WorkspaceIndicators.qml';workspace.write_text(re.sub(r'            required property var (modelData|entry)',lambda m:'            Component.onCompleted: console.info("AUDIT workspace created")\n            Component.onDestruction: console.info("AUDIT workspace destroyed")\n'+m.group(0),workspace.read_text(),count=1))
 (folder/'shell/Audit.qml').write_text('''//@ pragma ShellId swiftshell-flicker-audit
import QtQuick
import Quickshell
import "services" as Services
import "bar" as Bar
ShellRoot {
 property int step:0
 Bar.BarWindow {modelData:Quickshell.screens.find(function(s){return s.name==="DP-1"}) || Quickshell.screens[0];visible:false}
 Timer {interval:100;repeat:true;running:true;onTriggered:{
  if(Services.SettingsStore.persistenceState!=="ready")return
  if(++step<=15) {
   Services.SettingsStore.setBarSurface("","frosted","#161616",.2+step*.01)
   const changed=JSON.parse(JSON.stringify(Services.HyprlandModel.liveWorkspaces))
   for(let i=0;i<changed.length;i++) if(changed[i].monitorName==="DP-1") changed[i].urgent=step%2===0
   Services.HyprlandModel.liveWorkspaces=changed
   if(step===7) Services.SettingsStore.setHiddenModules(["battery"])
   if(step===8) Services.SettingsStore.setHiddenModules([])
  }
  else {console.info("AUDIT finished");Qt.quit()}
 }}
 Timer {interval:10000;running:true;onTriggered:{console.info("AUDIT timed out");Qt.quit()}}
}''')
 config=folder/'config/swiftshell';config.mkdir(parents=True);shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
 result=subprocess.run(['qs','-p',str(folder/'shell/Audit.qml')],capture_output=True,text=True,timeout=15,env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache')))
 log=result.stdout+result.stderr
 print('Native hidden bar, 15 appearance changes: created',log.count('AUDIT module created'),'destroyed',log.count('AUDIT module destroyed'),'settings loads',log.count('settings loaded'),'workspace creations',log.count('AUDIT workspace created'),'finished','AUDIT finished' in log)
 assert 'AUDIT finished' in log,log
 assert log.count('AUDIT module created')==9,log
 assert log.count('AUDIT workspace created')==4,log
