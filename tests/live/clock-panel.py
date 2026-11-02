#!/usr/bin/env python3
"""Actual anchored clock tools, guarded pointer clicks and keyboard dismissal."""
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
def call(*args):
    return subprocess.check_output(command + list(args), text=True)
def state():
    return json.loads(call('diagnostics'))
def wait(predicate):
    for _ in range(100):
        if predicate():
            return
        time.sleep(.05)
    raise AssertionError('Native clock did not reach its expected state')
def panel(output):
    for _ in range(40):
        menu = next(bar['menu'] for bar in state()['barSurfaces'] if bar['output'] == output)
        if not menu['visible']:
            return menu
        observed = [item for items in json.loads(ipc('j/layers')).get(output, {}).get('levels', {}).values()
                    for item in items if item.get('namespace') == 'swiftshell-popover']
        geometry = menu['geometry']
        if len(observed) == 1 and all(abs(geometry[field] - observed[0][key]) <= 1
                                      for field, key in [('x', 'x'), ('y', 'y'), ('width', 'w'), ('height', 'h')]):
            return menu
        time.sleep(.03)
    raise AssertionError('Clock geometry disagrees with the observed Hyprland layer')
def details(output):
    return panel(output)['geometry']['details']
def dispatch(expression):
    assert ipc('eval hl.dispatch(' + expression + ')').strip() == 'ok'

for _ in range(60):
    try:
        saved = json.loads(call('clockTool', 'snapshot', ''))
        break
    except json.JSONDecodeError:
        time.sleep(.05)
else:
    raise AssertionError('Clock service did not finish source reload')
monitors = json.loads(ipc('j/monitors'))
original_focus = next(monitor['name'] for monitor in monitors if monitor['focused'])
original_window = json.loads(ipc('j/activewindow')).get('address')
original_cursor = json.loads(ipc('j/cursorpos'))
try:
    with tempfile.TemporaryDirectory(prefix='swiftshell-clock-pointer-') as directory:
        directory = Path(directory)
        for name, source, libraries in [('pointer', 'settings-pointer.c', ['-lwayland-client']),
                                         ('keyboard', 'launcher-keyboard.c', ['-lwayland-client', '-lxkbcommon'])]:
            protocol = root / 'tests/protocols' / ('wlr-virtual-pointer-unstable-v1.xml' if name == 'pointer' else 'virtual-keyboard-unstable-v1.xml')
            subprocess.run(['wayland-scanner', 'client-header', str(protocol), str(directory / f'{name}-client.h')], check=True)
            subprocess.run(['wayland-scanner', 'private-code', str(protocol), str(directory / f'{name}-protocol.c')], check=True)
            subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', '-I' + str(directory), str(root / 'tests/helpers' / source),
                            str(directory / f'{name}-protocol.c'), '-o', str(directory / name)] + libraries, check=True)
        def click(monitor, identity):
            menu = panel(monitor['name'])
            geometry = menu['geometry']
            item = next(item for item in geometry['items'] if item['id'] == identity)
            assert item['enabled'], 'Clock test refuses to click a disabled control'
            x = round(geometry['x'] + item['x'] + item['width'] / 2)
            y = round(geometry['y'] + item['y'] + item['height'] / 2)
            assert geometry['x'] <= x < geometry['x'] + geometry['width']
            assert geometry['y'] <= y < geometry['y'] + geometry['height']
            width, height = map(round, logical_size(monitor))
            arguments = [str(directory / 'pointer'), str(x - monitor['x']), str(y - monitor['y']), str(width), str(height),
                         '0', '0', monitor['name'], str(x), str(y)]
            for _ in range(3):
                result = subprocess.run(arguments)
                if result.returncode == 0:
                    break
                if result.returncode != 6:
                    result.check_returncode()
                time.sleep(.2)
            result.check_returncode()
            time.sleep(.1)
        # Keep genuine existing tools intact; restoration below uses their exact
        # saved timestamps, so an already-running timer is not extended by testing.
        call('clockTool', 'restore', json.dumps({**saved, 'style': 'digital',
             'timer': {'status': 'ready', 'duration': 900000, 'remaining': 900000, 'deadline': 0},
             'stopwatch': {'status': 'ready', 'elapsed': 0, 'startedAt': 0, 'laps': []}}))
        for monitor in monitors:
            name = monitor['name']
            for other in monitors:
                call('barPanel', other['name'], 'close')
            call('barPanel', name, 'calendar')
            wait(lambda: panel(name)['visible'] and details(name)['tab'] == 'clock')
            wait(lambda: panel(name)['blur'])
            click(monitor, 'clockAnalogue')
            wait(lambda: details(name)['style'] == 'analogue')
            click(monitor, 'clockDigital')
            wait(lambda: details(name)['style'] == 'digital')
            click(monitor, 'clockTab-calendar')
            wait(lambda: details(name)['tab'] == 'calendar')
            click(monitor, 'nextMonth')
            click(monitor, 'previousMonth')
            click(monitor, 'clockTab-timer')
            wait(lambda: details(name)['tab'] == 'timer')
            click(monitor, 'timerPrimary')
            wait(lambda: details(name)['timerStatus'] == 'running')
            assert details(name)['timerRemaining'] > 800000
            click(monitor, 'timerPrimary')
            wait(lambda: details(name)['timerStatus'] == 'paused')
            click(monitor, 'timerPrimary')
            wait(lambda: details(name)['timerStatus'] == 'running')
            click(monitor, 'timerReset')
            wait(lambda: details(name)['timerStatus'] == 'ready')
            click(monitor, 'clockTab-stopwatch')
            wait(lambda: details(name)['tab'] == 'stopwatch')
            click(monitor, 'stopwatchPrimary')
            wait(lambda: details(name)['stopwatchElapsed'] > 100)
            click(monitor, 'stopwatchLapReset')
            wait(lambda: details(name)['laps'] == 1)
            click(monitor, 'stopwatchPrimary')
            wait(lambda: details(name)['stopwatchStatus'] == 'paused')
            click(monitor, 'stopwatchLapReset')
            wait(lambda: details(name)['laps'] == 0 and details(name)['stopwatchElapsed'] == 0)
            subprocess.run([str(directory / 'keyboard'), 'escape'], check=True)
            wait(lambda: not panel(name)['visible'])
            print('PASS native clock on', name, ': faces, calendar, timer, stopwatch/laps, real blur and Escape', flush=True)
finally:
    for monitor in monitors:
        call('barPanel', monitor['name'], 'close')
    call('clockTool', 'restore', json.dumps(saved))
    wait(lambda: json.loads(call('clockTool', 'snapshot', '')) == saved)
    clock_file = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'swiftshell/clock-tools.json'
    def restored_on_disk():
        try:
            return json.loads(clock_file.read_text()) == saved
        except (OSError, json.JSONDecodeError):
            return False
    wait(restored_on_disk)
    if original_window and any(window['address'] == original_window for window in json.loads(ipc('j/clients'))):
        dispatch('hl.dsp.focus({window=' + json.dumps('address:' + original_window) + '})')
    dispatch('hl.dsp.cursor.move({x=' + str(original_cursor['x']) + ',y=' + str(original_cursor['y']) + '})')
    dispatch('hl.dsp.focus({monitor=' + json.dumps(original_focus) + '})')
