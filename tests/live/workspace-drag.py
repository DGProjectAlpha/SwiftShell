#!/usr/bin/env python3
"""Actual Settings workspace handle drag, persistence, and scoped restoration."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--live', action='store_true', required=True)
parser.parse_args()
root = Path(__file__).parents[2]
sys.path.insert(0, str(root / 'shell/helpers'))
from displayctl import ipc, logical_size
command = ['qs', 'ipc', '-p', str(root / 'shell'), 'call', 'swiftshell']
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'swiftshell/settings.json'

def call(*args):
    return subprocess.check_output(command + list(args), text=True)
def state():
    return json.loads(call('diagnostics'))
def window():
    matches = [client for client in json.loads(ipc('j/clients'))
               if client.get('title') == 'SwiftShell Settings' and client.get('class') == 'org.quickshell']
    assert len(matches) == 1, 'Workspace drag must target one exact SwiftShell Settings client'
    return matches[0]
def wait(predicate):
    for _ in range(100):
        if predicate():
            return
        time.sleep(.05)
    raise AssertionError('Workspace drag did not reach the expected native state')
def page():
    return state()['window']['pageGeometry']
def output_preferences():
    return json.loads(json.loads(config.read_text())['bar'].get('workspaceOutputsJson', '{}'))
def dispatch(expression):
    assert ipc('eval hl.dispatch(' + expression + ')').strip() == 'ok'

original_state = state()
monitors = json.loads(ipc('j/monitors'))
original_focus = next(monitor['name'] for monitor in monitors if monitor['focused'])
original_cursor = json.loads(ipc('j/cursorpos'))
original_window = json.loads(ipc('j/activewindow')).get('address')
selected_output = None
original_override = None
try:
    call('settings', 'workspaces')
    wait(lambda: state()['window'] is not None and not state()['windowBusy']
         and state()['window']['pageStatus'] == 1 and state()['window']['pageGeometry'] is not None)
    selected_output = page()['output']
    assert selected_output in {monitor['name'] for monitor in monitors}, 'Selected workspace output must be connected'
    # Snapshot the latest value immediately before overriding this output. Do not
    # restore another monitor, display modes, bar appearance, or unrelated settings.
    original_override = output_preferences().get(selected_output)
    fixture = ['1', 'gaming', '2']
    expected = ['gaming', '2', '1']
    assert json.loads(call('workspaceOutput', selected_output, ' '+json.dumps(fixture)))['accepted']
    wait(lambda: [row['key'] for row in page()['rows']] == fixture)
    wait(lambda: state()['settingsPersistence'] == 'ready' and output_preferences().get(selected_output) == fixture)
    geometry = window()
    assert geometry.get('floating'), 'Workspace test expects the native floating Settings window'
    assert not state()['window']['maximized'], 'Do not alter a maximized user window for this test'
    with tempfile.TemporaryDirectory(prefix='swiftshell-workspace-drag-') as directory:
        directory = Path(directory)
        protocol = root / 'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner', 'client-header', str(protocol), str(directory / 'pointer-client.h')], check=True)
        subprocess.run(['wayland-scanner', 'private-code', str(protocol), str(directory / 'pointer-protocol.c')], check=True)
        subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', '-I' + str(directory),
                        str(root / 'tests/helpers/settings-pointer.c'), str(directory / 'pointer-protocol.c'),
                        '-o', str(directory / 'pointer'), '-lwayland-client'], check=True)
        rows = page()['rows']
        first, last = rows[0], rows[-1]
        # Diagnostics expose drag-handle centers, not their top-left corners.
        x = round(geometry['at'][0] + first['x'])
        y = round(geometry['at'][1] + first['y'])
        target_x = round(geometry['at'][0] + last['x'])
        target_y = round(geometry['at'][1] + last['y'])
        for px, py in [(x, y), (target_x, target_y)]:
            assert geometry['at'][0] + 8 <= px < geometry['at'][0] + geometry['size'][0] - 8
            assert geometry['at'][1] + 40 <= py < geometry['at'][1] + geometry['size'][1] - 20, 'Drag handles must be inside visible Settings content'
        monitor = next(monitor for monitor in monitors
                       if monitor['x'] <= x < monitor['x'] + logical_size(monitor)[0]
                       and monitor['y'] <= y < monitor['y'] + logical_size(monitor)[1])
        width, height = map(round, logical_size(monitor))
        assert monitor['x'] <= target_x < monitor['x'] + width
        assert monitor['y'] <= target_y < monitor['y'] + height
        assert window()['address'] == geometry['address'] and window()['pid'] == geometry['pid']
        arguments = [str(directory / 'pointer'), str(x - monitor['x']), str(y - monitor['y']),
                     str(width), str(height), str(target_x - x), str(target_y - y), monitor['name'], str(x), str(y)]
        for _ in range(3):
            result = subprocess.run(arguments)
            if result.returncode == 0:
                break
            # Code 6 is a cursor mismatch before any press was sent. Retrying an
            # already-pressed gesture is deliberately forbidden.
            if result.returncode != 6:
                result.check_returncode()
            time.sleep(.2)
        result.check_returncode()
        wait(lambda: [row['key'] for row in page()['rows']] == expected)
        wait(lambda: state()['settingsPersistence'] == 'ready' and output_preferences().get(selected_output) == expected)
        assert set(row['key'] for row in page()['rows']) == set(fixture), 'Named and inactive/empty indicators must survive reordering'
        after = window()
        assert after['address'] == geometry['address'] and after['pid'] == geometry['pid']
        assert after['size'] == geometry['size'] and after['at'] == geometry['at'], 'Dragging a workspace must not resize or move Settings'
        print('PASS native workspace drag on', selected_output, ': actual handle reorder, named/empty retention, disk persistence and unchanged Settings geometry', flush=True)
finally:
    if selected_output is not None:
        assert json.loads(call('workspaceOutput', selected_output, ' '+json.dumps(original_override)))['accepted']
        wait(lambda: state()['settingsPersistence'] == 'ready' and output_preferences().get(selected_output) == original_override)
    call('settings', original_state['category'])
    wait(lambda: not state()['windowBusy'])
    if not original_state['settingsOpen']:
        call('window', 'close')
        wait(lambda: not state()['settingsOpen'])
    wait(lambda: state()['settingsPersistence'] == 'ready')
    if original_window and any(client['address'] == original_window for client in json.loads(ipc('j/clients'))):
        dispatch('hl.dsp.focus({window=' + json.dumps('address:' + original_window) + '})')
    dispatch('hl.dsp.cursor.move({x=' + str(original_cursor['x']) + ',y=' + str(original_cursor['y']) + '})')
    dispatch('hl.dsp.focus({monitor=' + json.dumps(original_focus) + '})')
