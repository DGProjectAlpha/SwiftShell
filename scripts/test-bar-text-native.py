#!/usr/bin/env python3
"""Opt-in, own-surface text/icon comparison on each connected native output."""
import argparse
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tests/live'))
from fullscreen_guard import require_idle_desktop


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    require_idle_desktop()
    output = args.output_dir or Path(tempfile.mkdtemp(prefix='swiftshell-text-images-'))
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='swiftshell-text-probe-') as temporary:
        folder = Path(temporary)
        shutil.copytree(root / 'shell', folder / 'shell')
        shutil.copyfile(root / 'tests/live/bar-text-rendering.qml', folder / 'shell/TextAudit.qml')
        config = folder / 'config/swiftshell'
        config.mkdir(parents=True)
        shutil.copyfile(root / 'shell/config/defaults.json', config / 'settings.json')
        environment = dict(os.environ, SWIFTSHELL_TEXT_AUDIT_DIR=str(output.resolve()),
                           XDG_CONFIG_HOME=str(folder / 'config'),
                           XDG_STATE_HOME=str(folder / 'state'), XDG_CACHE_HOME=str(folder / 'cache'))
        result = subprocess.run(['qs', '-p', str(folder / 'shell/TextAudit.qml')],
                                env=environment, text=True, capture_output=True, timeout=15)
        logs = result.stdout + result.stderr
        captures = re.findall(r'Text audit: (\S+) DPR=([0-9.]+) captured=true', logs)
        if result.returncode or not captures or 'Text audit timed out' in logs:
            print(logs)
            raise SystemExit('Native text comparison failed.')
        for name, dpr in captures:
            path = output / (name + '.png')
            width, height = struct.unpack('>II', path.read_bytes()[16:24])
            assert abs(width - 900 * float(dpr)) <= 1
            assert abs(height - 180 * float(dpr)) <= 1
            print(f'PASS {name}: DPR {dpr}, own-surface image {width}x{height}; Curve/Qt/native hinting and aliased/AA icons compared.')
    print(f'Comparison images: {output}')


if __name__ == '__main__':
    main()
