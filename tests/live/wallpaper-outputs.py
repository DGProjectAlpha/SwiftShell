#!/usr/bin/env python3
"""Opt-in native background-surface regression; preferences remain isolated."""
import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import zlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--live', action='store_true', required=True)
parser.parse_args()
ROOT = Path(__file__).resolve().parents[2]


def png(path, rgb):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 2, 2, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress((b'\0' + bytes(rgb) * 2) * 2)) + chunk(b'IEND', b''))


def wait(predicate):
    for _ in range(120):
        try:
            value = predicate()
            if value:
                return value
        except (subprocess.CalledProcessError, ValueError):
            pass
        time.sleep(.05)
    raise AssertionError('Wallpaper state failed to settle')


with tempfile.TemporaryDirectory(prefix='swiftshell-wallpaper-audit-') as temporary:
    folder = Path(temporary)
    shell = folder / 'shell'
    shutil.copytree(ROOT / 'shell', shell)
    red, blue = folder / 'red.png', folder / 'blue.png'
    png(red, [100, 0, 0])
    png(blue, [0, 0, 100])
    monitors = json.loads(subprocess.check_output(['hyprctl', '-j', 'monitors'], text=True))
    outputs = [monitor['name'] for monitor in monitors]
    assert len(outputs) >= 2, 'Two connected outputs required'
    config = folder / 'config/swiftshell'
    config.mkdir(parents=True)
    defaults = json.loads((ROOT / 'shell/config/defaults.json').read_text())
    defaults['wallpaper'].update(path=str(blue), outputsJson=json.dumps({outputs[0]: str(red)}), slideshow=False)
    (config / 'settings.json').write_text(json.dumps(defaults))
    qml = shell / 'WallpaperAudit.qml'
    qml.write_text('''//@ pragma ShellId swiftshell-wallpaper-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "wallpaper"
Scope {
 Component.onCompleted: Quickshell.watchFiles = false
 WallpaperHost { id: host }
 IpcHandler {
  target: "audit"
  function state(): string { return JSON.stringify({ready:SettingsStore.persistenceState,outputs:host.diagnostics()}) }
  function choose(output:string,path:string):void { SettingsStore.setOutputWallpaper(output,path) }
 }
}''')
    env = dict(os.environ, XDG_CONFIG_HOME=str(folder / 'config'), XDG_STATE_HOME=str(folder / 'state'),
               XDG_CACHE_HOME=str(folder / 'cache'), QT_QPA_PLATFORM='wayland')
    command = ['qs', 'ipc', '-p', str(qml), 'call', 'audit']
    def call(*args):
        return subprocess.check_output(command + list(args), env=env, text=True, stderr=subprocess.DEVNULL).strip()
    def settled():
        state = json.loads(call('state'))
        rows = state['outputs']
        return rows if state['ready'] == 'ready' and len(rows) == len(outputs) and all(
            row['ready'] and row['sourceMatches'] and not row['failed'] and row['screen'] == row['output']
            for row in rows) else None
    with (folder / 'runtime.log').open('w') as log:
        for cold_start in range(2):
            process = subprocess.Popen(['qs', '-p', str(qml)], env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                rows = wait(settled)
                assert next(row for row in rows if row['output'] == outputs[0])['override']
                for path in (str(blue), str(red), ''):
                    call('choose', outputs[1], path)
                    rows = wait(lambda: (r := settled()) and next(x for x in r if x['output'] == outputs[1])['override'] == bool(path) and r)
                assert all(not row['fallback'] for row in rows)
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    runtime = (folder / 'runtime.log').read_text()
    assert not any(error in runtime for error in ('TypeError', 'ReferenceError', 'Binding loop', 'Failed to load configuration'))
    print('PASS: two native cold starts; per-output images, replacement, shared fallback and source/connector matching on all connected outputs; isolated preferences only')
