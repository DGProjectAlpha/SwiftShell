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
parser.add_argument('--fullscreen-output', help='Existing fullscreen output for the startup regression')
parser.add_argument('--desktop-workspace', type=int, help='Existing empty workspace on that output; restored after each test')
args = parser.parse_args()
if bool(args.fullscreen_output) != bool(args.desktop_workspace):
    parser.error('Supply both --fullscreen-output and --desktop-workspace')
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
    original_monitor = next((m['name'] for m in monitors if m.get('focused')), outputs[0])
    fullscreen_monitor = next((m for m in monitors if m['name'] == args.fullscreen_output), None)
    original_workspace = None
    if args.fullscreen_output:
        assert fullscreen_monitor, 'Requested output is disconnected'
        workspaces = json.loads(subprocess.check_output(['hyprctl', '-j', 'workspaces'], text=True))
        desktop = next((w for w in workspaces if w.get('id') == args.desktop_workspace), None)
        assert desktop and desktop['monitor'] == args.fullscreen_output and desktop['windows'] == 0, 'Desktop test workspace must exist and be empty on that output'
        original_workspace = fullscreen_monitor['activeWorkspace']['name']
        assert next(w for w in workspaces if w['name'] == original_workspace)['hasfullscreen'], 'Requested output must already be fullscreen'

    def focus(**selector):
        key, value = next(iter(selector.items()))
        code = 'hl.dispatch(hl.dsp.focus({' + key + '=' + json.dumps(value) + '}))'
        assert subprocess.check_output(['hyprctl', 'eval', code], text=True).strip() == 'ok'
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
                if original_workspace:
                    blocked = next(row for row in rows if row['output'] == args.fullscreen_output)
                    assert blocked['waitingForDesktop'] and not blocked['visible'], 'Wallpaper mapped beneath fullscreen at startup'
                    focus(workspace=args.desktop_workspace)
                    wait(lambda: (r := settled()) and next(x for x in r if x['output'] == args.fullscreen_output)['visible'])
                    def opaque_layer():
                        layers = json.loads(subprocess.check_output(['hyprctl', '-j', 'layers'], text=True))
                        return any(layer['pid'] == process.pid and layer['namespace'] == 'swiftshell-wallpaper' and layer['alpha'] == 1
                                   for layer in layers[args.fullscreen_output]['levels']['0'])
                    wait(opaque_layer)
                for path in (str(blue), str(red), ''):
                    call('choose', outputs[1], path)
                    rows = wait(lambda: (r := settled()) and next(x for x in r if x['output'] == outputs[1])['override'] == bool(path) and r)
                assert all(not row['fallback'] for row in rows)
            finally:
                try:
                    if original_workspace:
                        focus(workspace=original_workspace)
                        focus(monitor=original_monitor)
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
    if original_workspace:
        print('PASS: fullscreen startup defers mapping; leaving fullscreen maps the owned background with compositor alpha=1; original workspace/focus restored')
