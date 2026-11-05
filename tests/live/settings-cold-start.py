#!/usr/bin/env python3
"""Fresh Quickshell processes verify persisted preferences without a reboot or surfaces."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live',action='store_true',required=True)
    parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='swiftshell-cold-start-') as directory:
        folder=Path(directory)
        shutil.copytree(root/'shell',folder/'shell')
        shutil.copy2(root/'tests/live/settings-cold-start.qml',folder/'shell/ColdAudit.qml')
        config=folder/'config/swiftshell'
        config.mkdir(parents=True)
        shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
        env=dict(os.environ,XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/'state'),XDG_CACHE_HOME=str(folder/'cache'))
        for mode in ['write','read','read']:
            env['SWIFTSHELL_COLD_READ']='1' if mode=='read' else '0'
            result=subprocess.run(['qs','-p',str(folder/'shell/ColdAudit.qml')],env=env,capture_output=True,text=True,timeout=12)
            assert result.returncode==0 and f'Cold settings {mode} PASS' in result.stdout+result.stderr,result.stdout+result.stderr
            assert 'FAILED' not in result.stdout+result.stderr
        saved=json.loads((config/'settings.json').read_text())
        assert saved['appearance']['accentColor']=='#7296a8'
        assert saved['weather']['enabled'] is False  # Never requests a real location.
        assert saved['bar']['fullscreenPeek'] is True
        assert saved['weather']['units']=='imperial'
        print('PASS native cold starts: accent, opacity, fullscreen peek, sections, weather and per-output visibility')


if __name__=='__main__':
    main()
