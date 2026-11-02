#!/usr/bin/env python3
"""Actual FileView external reload and protection; isolated settings, no surface."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
parser=argparse.ArgumentParser()
parser.add_argument('--live',action='store_true',required=True)
parser.parse_args()
root=Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-external-settings-') as directory:
    folder=Path(directory)
    shutil.copytree(root/'shell',folder/'shell',symlinks=False)
    shutil.copy2(root/'tests/live/settings-external.qml',folder/'shell/ExternalAudit.qml')
    (folder/'shell/external-editor.py').write_text('''import json,os,pathlib,sys
path=pathlib.Path(os.environ['XDG_CONFIG_HOME'])/'swiftshell/settings.json'
raw=path.read_text()
# Preserve FileView's exact serializer formatting to exercise identical-write
# suppression after a real external reload, not just semantic JSON equality.
raw=raw.replace('"use24Hour": false','"use24Hour": true')
mode=sys.argv[1]
if mode=='future':raw=raw.replace('"version": 3','"version": 99')
if mode=='malformed':raw='{broken external settings'
temporary=path.with_suffix('.external.tmp')
temporary.write_text(raw);temporary.replace(path)
(path.parent/'expected-external.txt').write_text(raw)
''')
    for scenario in ['canonical','malformed','future']:
        config=folder/scenario/'config/swiftshell'
        config.mkdir(parents=True)
        shutil.copy2(root/'shell/config/defaults.json',config/'settings.json')
        env=dict(os.environ,XDG_CONFIG_HOME=str(config.parent),XDG_STATE_HOME=str(folder/scenario/'state'),XDG_CACHE_HOME=str(folder/scenario/'cache'),SWIFTSHELL_EXTERNAL_CASE=scenario)
        result=subprocess.run(['qs','-p',str(folder/'shell/ExternalAudit.qml')],env=env,capture_output=True,text=True,timeout=10)
        output=result.stdout+result.stderr
        marker='canonical readback and subsequent save passed' if scenario=='canonical' else 'protected content retained live preferences'
        assert result.returncode==0 and marker in output,output
        if scenario=='canonical':
            settings=json.loads((config/'settings.json').read_text())
            assert settings['clock']['use24Hour'] is False
            assert settings['launcher']['pinnedIds']==['owned-first.desktop','owned-second.desktop']
        else:
            assert (config/'settings.json').read_text()==(config/'expected-external.txt').read_text()
        print('PASS native external settings:',scenario,'reload, live-state protection and disk readback')
