#!/usr/bin/env python3
"""Opt-in native bar geometry/save test; hidden windows and temporary XDG dirs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tests/live'))
from fullscreen_guard import require_idle_desktop


def main():
    require_idle_desktop()
    with tempfile.TemporaryDirectory(prefix='swiftshell-bar-settings-') as temporary:
        folder = Path(temporary)
        shutil.copytree(root / 'shell', folder / 'shell')
        shutil.copyfile(root / 'tests/live/bar-settings.qml', folder / 'shell/BarSettingsAudit.qml')
        config = folder / 'config/swiftshell'
        config.mkdir(parents=True)
        shutil.copyfile(root / 'shell/config/defaults.json', config / 'settings.json')
        environment = dict(os.environ, XDG_CONFIG_HOME=str(folder / 'config'),
                           XDG_STATE_HOME=str(folder / 'state'), XDG_CACHE_HOME=str(folder / 'cache'))
        for readback, marker in [('0', 'native size isolation and save passed'),
                                 ('1', 'native restart readback passed')]:
            environment['SWIFTSHELL_AUDIT_READBACK'] = readback
            result = subprocess.run(['qs', '-p', str(folder / 'shell/BarSettingsAudit.qml')],
                                    env=environment, text=True, capture_output=True, timeout=20)
            output = result.stdout + result.stderr
            if result.returncode or marker not in output or 'Bar settings audit FAILED' in output:
                print(output)
                raise SystemExit('Native bar settings audit failed.')
        document = json.loads((config / 'settings.json').read_text())
        sizes = json.loads(document['bar']['layoutOutputsJson'])
        assert any(value.get('height') == 42 for value in sizes.values())
        assert document['bar']['height'] == 28
        print('PASS native BarWindow size/reservation isolation, hidden Settings categories, atomic save and restart readback; no windows mapped.')


if __name__ == '__main__':
    main()
