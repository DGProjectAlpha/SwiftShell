#!/usr/bin/env python3
"""Isolated real NetworkManager service audit; never changes connectivity."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
parser=argparse.ArgumentParser();parser.add_argument('--live',action='store_true',required=True);parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-network-devices-') as temp:
    folder=Path(temp);shutil.copytree(root/'shell',folder/'shell',symlinks=False)
    shutil.copy2(root/'tests/live/network-devices.qml',folder/'shell/NetworkAudit.qml')
    config=folder/'config/swiftshell';config.mkdir(parents=True)
    shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
    result=subprocess.run(['qs','-p',str(folder/'shell/NetworkAudit.qml')],env=env,capture_output=True,text=True,timeout=12)
    output=result.stdout+result.stderr
    # Failure diagnostics may include selected private connection data in toolkit
    # internals; only report a generic failure rather than dumping process logs.
    assert result.returncode==0 and 'Network native audit: read-only snapshot and manager ownership passed' in output,'Native NetworkManager audit failed; inspect its isolated Quickshell log locally.'
print('PASS actual NetworkManager snapshot, stdin helper transport and manager view ownership; no connectivity changes')
