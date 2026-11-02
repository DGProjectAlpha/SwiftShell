#!/usr/bin/env python3
"""One very quiet owned Qt sound; isolated preferences, no system volume changes."""
import argparse,json,os,shutil,subprocess,tempfile
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-notification-sound-') as directory:
 folder=Path(directory);shutil.copytree(root/'shell',folder/'shell')
 config=folder/'config/swiftshell';config.mkdir(parents=True)
 prefs=json.loads((root/'shell/config/defaults.json').read_text());prefs['notifications']['soundVolume']=.02
 (config/'settings.json').write_text(json.dumps(prefs))
 qml=folder/'shell/SoundAudit.qml';qml.write_text('''//@ pragma ShellId swiftshell-notification-sound-audit
import QtQuick
import Quickshell
import "notifications"
import "services"
ShellRoot {
 id:root
 property bool played:false
 property bool started:false
 function play(){if(played || SettingsStore.persistenceState!=="ready" || !sound.available)return;played=true;if(!sound.playNotification())Qt.quit()}
 NotificationSound {
  id:sound
  onAvailableChanged:if(available)Qt.callLater(root.play)
  onPlayingChanged:{if(playing)root.started=true;else if(root.started){console.info("Sound native audit: Qt output started and completed at isolated low volume");Qt.quit()}}
 }
 Connections {target:SettingsStore;function onPersistenceStateChanged(){Qt.callLater(root.play)}}
 Timer {interval:10000;running:true;onTriggered:Qt.quit()}
}
''')
 env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
 result=subprocess.run(['qs','-p',str(qml)],env=env,capture_output=True,text=True,timeout=12)
 output=result.stdout+result.stderr
 assert result.returncode==0 and 'Sound native audit: Qt output started and completed' in output,'Native notification sound did not complete; inspect its isolated Quickshell log locally.'
 assert 'TypeError' not in output and 'ReferenceError' not in output
print('PASS real Qt notification sound ready/start/completion at isolated 2% volume; system volume unchanged')
