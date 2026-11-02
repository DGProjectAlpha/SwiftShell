#!/usr/bin/env python3
"""Read-only actual StatusNotifier model audit; hidden window, isolated settings."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
reply=subprocess.check_output(['busctl','--user','get-property','org.kde.StatusNotifierWatcher','/StatusNotifierWatcher','org.kde.StatusNotifierWatcher','RegisteredStatusNotifierItems'],text=True)
match=re.match(r'as (\d+)',reply);assert match,'StatusNotifier watcher did not report its registered item count'
expected=int(match.group(1))
with tempfile.TemporaryDirectory(prefix='swiftshell-native-tray-') as directory:
    folder=Path(directory);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
    shutil.copy2(root/'tests/live/tray-native.qml',folder/'shell/TrayAudit.qml')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
    result=subprocess.run(['qs','-p',str(folder/'shell/TrayAudit.qml')],capture_output=True,text=True,timeout=8,env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'),SWIFTSHELL_TRAY_COUNT=str(expected)))
    output=result.stdout+result.stderr
    assert result.returncode==0 and 'Native tray audit: all registered native objects rendered' in output,output
print('PASS native StatusNotifier model: every published item rendered in native object order; registered count',expected)
