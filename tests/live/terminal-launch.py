#!/usr/bin/env python3
"""Run a synthetic Terminal=true desktop entry through native LauncherModel."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

parser=argparse.ArgumentParser()
parser.add_argument('--live', action='store_true', required=True)
parser.parse_args()
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-terminal-native-') as folder:
    folder=Path(folder)
    shell=folder/'shell'
    shutil.copytree(root/'shell',shell)
    applications=folder/'data/applications'
    applications.mkdir(parents=True)
    marker=folder/'terminal-result.json'
    script=folder/'marker.py'
    script.write_text('import json,os,sys\nfrom pathlib import Path\nPath(sys.argv[1]).write_text(json.dumps({"tty":os.isatty(0),"arguments":sys.argv[2:]}))\n')
    applications.joinpath('swiftshell-owned-terminal.desktop').write_text(
        '[Desktop Entry]\nType=Application\nName=SwiftShell terminal fixture\nTerminal=true\n'
        f'Exec=python3 {script} {marker} "literal space" "$(not-a-command)"\n')
    shell.joinpath('TerminalAudit.qml').write_text('''//@ pragma ShellId swiftshell-terminal-audit
import QtQuick
import Quickshell
import "services"
ShellRoot {
    property bool launched:false
    Timer {interval:100;repeat:true;running:true;onTriggered:{
        const entry=DesktopEntries.byId("swiftshell-owned-terminal")
        if(entry && !parent.launched){parent.launched=true;LauncherModel.launchApplication(entry.id,entry.name)}
    }}
}
''')
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),
             XDG_DATA_HOME=str(folder/'data'),XDG_CACHE_HOME=str(folder/'cache'))
    # Keep system desktop entries available for the selected/fallback terminal.
    with (folder/'runtime.log').open('w') as log:
        process=subprocess.Popen(['qs','-p',str(shell/'TerminalAudit.qml')],env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            for _ in range(200):
                if marker.exists():break
                if process.poll() is not None:raise AssertionError('The native terminal fixture exited unexpectedly.')
                time.sleep(.05)
            assert marker.exists(),'The Terminal=true entry did not reach a terminal.'
            result=json.loads(marker.read_text())
            assert result=={'tty':True,'arguments':['literal space','$(not-a-command)']},result
            print('PASS native Terminal=true launcher: real PTY, literal arguments, no updater execution')
        finally:
            process.terminate()
            try:process.wait(timeout=3)
            except subprocess.TimeoutExpired:process.kill();process.wait()
