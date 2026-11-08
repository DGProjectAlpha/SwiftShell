#!/usr/bin/env python3
"""One right-click and one outside click must unmap the bar popout and blur."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'shell/helpers'))
sys.path.insert(0, str(ROOT / 'tests/live'))
from displayctl import ipc, logical_size
from fullscreen_guard import require_idle_desktop


def run(output, expect_closed=True):
    command = ['qs', 'ipc', '-p', str(ROOT / 'shell'), 'call', 'swiftshell']

    def call(*args):
        return subprocess.check_output(command + list(args), text=True, timeout=5)

    def bar():
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                selected = next(item for item in json.loads(call('diagnostics'))['barSurfaces'] if item['output'] == output)
                if not expect_closed or 'motion' in selected['menu']:
                    return selected
            except (ValueError, StopIteration, subprocess.CalledProcessError):
                pass
            time.sleep(.05)
        raise AssertionError('The selected bar did not finish reloading.')

    monitor = next(item for item in json.loads(ipc('j/monitors')) if item['name'] == output)
    assert bar()['rendering']['acceptsInput'], 'Target bar is not accepting input; no click sent.'
    cursor = json.loads(ipc('j/cursorpos'))
    active = json.loads(ipc('j/activewindow')).get('address')
    width, height = map(round, logical_size(monitor))
    assert bar()['edge'] == 'top', 'This targeted regression requires a top-edge bar.'
    # Click the empty left bar inset, outside the popout and its widgets. A
    # wallpaper click need not change keyboard focus and clear a focus grab.
    # This hits the real bar dismissal handler without interacting with apps.
    away = (1, max(1, round(bar()['height']/2)))
    with tempfile.TemporaryDirectory(prefix='swiftshell-popover-click-') as temporary:
        folder = Path(temporary)
        protocol = ROOT / 'tests/protocols/wlr-virtual-pointer-unstable-v1.xml'
        subprocess.run(['wayland-scanner', 'client-header', str(protocol), str(folder/'pointer-client.h')], check=True)
        subprocess.run(['wayland-scanner', 'private-code', str(protocol), str(folder/'pointer-protocol.c')], check=True)
        subprocess.run(['cc', '-Wall', '-Wextra', '-Werror', '-I'+str(folder),
                        str(ROOT/'tests/helpers/settings-pointer.c'), str(folder/'pointer-protocol.c'),
                        '-o', str(folder/'pointer'), '-lwayland-client'], check=True)

        def click(x, y, button):
            for _ in range(3):
                result = subprocess.run([str(folder/'pointer'), str(x), str(y), str(width), str(height), '0', '0', output,
                                         str(monitor['x']+x), str(monitor['y']+y), button])
                if result.returncode == 0:
                    return
                if result.returncode != 6:
                    result.check_returncode()
                time.sleep(.1)
            result.check_returncode()

        try:
            # The second scoped close also clears an already invisible stale popout.
            call('barPanel', output, 'close'); call('barPanel', output, 'close')
            time.sleep(.2)
            assert not bar()['menu']['visible'], 'Target popout did not start closed.'
            click(round(width*.45), max(1, round(bar()['height']/2)), 'right')
            for _ in range(30):
                if bar()['menu']['visible']:
                    break
                time.sleep(.03)
            assert bar()['menu']['visible'], 'Right-click did not open the target popout.'
            opened = bar()['menu']['blur']
            time.sleep(.25)
            click(*away, 'left')
            time.sleep(.5)
            menu = bar()['menu']
            motion = menu.get('motion', {})
            closed = (not menu['visible'] and not menu['blur'] and motion.get('phase') == 'closed'
                      and motion.get('opacity', 1) <= .001 and not motion.get('grab') and not motion.get('interactive'))
            print(json.dumps({'output': output, 'openedWithBlur': opened,
                              'afterOneOutsideClick': {'visible': menu['visible'], 'blur': menu['blur'], 'motion': menu.get('motion')}}))
            assert closed == expect_closed, {'visible': menu['visible'], 'blur': menu['blur'], 'motion': menu.get('motion')}
        finally:
            call('barPanel', output, 'close'); call('barPanel', output, 'close')
            ipc('eval hl.dispatch(hl.dsp.cursor.move({x='+str(cursor['x'])+',y='+str(cursor['y'])+'}))')
            if active and any(item['address'] == active for item in json.loads(ipc('j/clients'))):
                ipc('eval hl.dispatch(hl.dsp.focus({window='+json.dumps('address:'+active)+'}))')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    require_idle_desktop()
    run(args.output)
