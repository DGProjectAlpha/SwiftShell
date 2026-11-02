#!/usr/bin/env python3
"""Isolated native FileView/deadline audit; no window, focus or real notification."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--live', action='store_true', required=True)
parser.parse_args()
root = Path(__file__).parents[2]
with tempfile.TemporaryDirectory(prefix='swiftshell-clock-audit-') as directory:
    directory = Path(directory)
    shell = directory / 'shell'
    shutil.copytree(root / 'shell', shell, symlinks=False)
    shutil.copy(root / 'tests/live/clock-tools.qml', shell / 'ClockAudit.qml')
    binary = directory / 'bin'
    binary.mkdir()
    notifier = binary / 'notify-send'
    notifier.write_text('#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\nPath(os.environ["SWIFTSHELL_NOTIFY_MARKER"]).write_text(json.dumps(sys.argv[1:]))\n')
    notifier.chmod(0o700)
    marker = directory / 'notification.json'
    env = dict(os.environ, XDG_STATE_HOME=str(directory / 'state'), XDG_CONFIG_HOME=str(directory / 'config'),
               XDG_CACHE_HOME=str(directory / 'cache'), SWIFTSHELL_NOTIFY_MARKER=str(marker),
               PATH=str(binary) + os.pathsep + os.environ['PATH'])
    def launch(mode):
        result = subprocess.run(['qs', '-p', str(shell / 'ClockAudit.qml')],
                                env=dict(env, SWIFTSHELL_CLOCK_READBACK=mode), text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
        assert result.returncode == 0, result.stdout
        assert 'FAILED' not in result.stdout, result.stdout
        return result.stdout
    assert 'running countdown and stopwatch saved' in launch('0')
    saved = json.loads((directory / 'state/swiftshell/clock-tools.json').read_text())
    assert saved['style'] == 'analogue' and saved['timer']['status'] == 'running'
    assert saved['stopwatch']['status'] == 'running' and len(saved['stopwatch']['laps']) == 1
    assert 'restarted countdown expired and stopwatch retained its lap' in launch('1')
    restored = json.loads((directory / 'state/swiftshell/clock-tools.json').read_text())
    assert restored['timer']['status'] == 'finished'
    assert restored['stopwatch']['status'] == 'paused' and len(restored['stopwatch']['laps']) == 1
    assert restored['stopwatch']['elapsed'] >= saved['stopwatch']['laps'][0]
    notification = json.loads(marker.read_text())
    assert notification[-2:] == ['Timer finished', 'Your countdown has finished.']
    assert '--app-name=SwiftShell' in notification
    print('PASS native clock: atomic state, restart deadline expiry, stopwatch/lap readback, notification argv')
