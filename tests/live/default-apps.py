#!/usr/bin/env python3
"""Real xdg-mime roundtrip in isolated XDG dirs; never changes session defaults."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-default-apps-') as folder:
    folder=Path(folder)
    env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'),XDG_CONFIG_DIRS=str(folder/'etc'),XDG_DATA_HOME=str(folder/'data'),XDG_DATA_DIRS=str(folder/'system'),XDG_STATE_HOME=str(folder/'state'),XDG_CURRENT_DESKTOP='Hyprland')
    (folder/'config').mkdir()
    apps=folder/'data/applications';apps.mkdir(parents=True)
    for app in ['first','second']:
        (apps/(app+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+app+'\nExec=/usr/bin/true\nMimeType=x-scheme-handler/https;x-scheme-handler/http;text/html;\n')
    def tool(*args):
        result=subprocess.run(args,env=env,text=True,capture_output=True)
        if result.returncode:raise RuntimeError(result.stdout+' '+result.stderr)
        return result.stdout.strip()
    tool('xdg-mime','default','first.desktop','x-scheme-handler/https')
    original=tool('xdg-mime','query','default','x-scheme-handler/https')
    assert original=='first.desktop'
    base=['python3',str(ROOT/'shell/helpers/defaultappsctl.py')]
    changed=json.loads(tool(*base,'choose','--role','browser','--desktop-id','second.desktop'))
    assert changed['ok']
    assert tool('xdg-mime','query','default','x-scheme-handler/https')=='second.desktop'
    restored=json.loads(tool(*base,'reset','--role','browser'))
    assert restored['ok']
    assert tool('xdg-mime','query','default','x-scheme-handler/https')=='first.desktop'
    backups=list((folder/'state/swiftshell/backups').glob('*.json'))
    assert len(backups)==2 and all(p.stat().st_mode & 0o777==0o600 for p in backups)
    print('PASS real xdg-mime selection, verified readback, backup and scoped undo in isolated XDG directories')
