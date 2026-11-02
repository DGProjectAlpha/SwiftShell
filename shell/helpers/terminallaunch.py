#!/usr/bin/env python3
"""Launch parsed desktop commands in a terminal, without shell evaluation."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import configparser
from defaultappsctl import desktop_entries, preferences

# Each emulator has a different option separating its own arguments from argv.
OPTIONS = {'konsole': ['--separate', '-e'], 'kitty': ['--'], 'foot': ['--'],
           'alacritty': ['-e'], 'wezterm': ['start', '--'],
           'gnome-terminal': ['--'], 'xfce4-terminal': ['--disable-server', '-x'],
           'xterm': ['-e'], 'ghostty': ['-e']}


def terminal_prefix():
    selected = preferences()['roles'].get('terminal', {}).get('id', '')
    if selected:
        entry = desktop_entries().get(selected)
        if not entry:
            raise ValueError('The selected terminal is unavailable. Choose one in Default Apps.')
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.read(entry['path'], encoding='utf-8')
        command = shlex.split(parser['Desktop Entry'].get('Exec', ''))
        # Preserve fixed desktop arguments, but never carry file-code placeholders.
        if not command or any('%' in arg for arg in command):
            raise ValueError('This terminal launcher is unsupported. Choose another in Default Apps.')
        binary = Path(command[0]).name
        if binary not in OPTIONS or not shutil.which(command[0]):
            raise ValueError('This terminal launcher is unsupported. Choose another in Default Apps.')
        return command + OPTIONS[binary]
    if shutil.which('xdg-terminal-exec'):
        return ['xdg-terminal-exec']
    for binary in OPTIONS:
        if shutil.which(binary):
            return [binary] + OPTIONS[binary]
    raise ValueError('No supported terminal was found. Install or select a terminal first.')


def launch(payload):
    argv = payload.get('command')
    cwd = payload.get('workingDirectory') or None
    if (not isinstance(argv, list) or not argv or len(argv) > 256 or
            any(not isinstance(arg, str) or '\0' in arg or len(arg) > 32768 for arg in argv) or not argv[0]):
        raise ValueError('The application command is invalid.')
    if cwd is not None and (not isinstance(cwd, str) or not os.path.isdir(cwd)):
        raise ValueError('The application working folder is unavailable.')
    prefix = terminal_prefix()
    subprocess.Popen(prefix + argv, cwd=cwd, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    return {'ok': True}


def main():
    try:
        raw = sys.stdin.readline(1024 * 1024 + 1)
        if len(raw) > 1024 * 1024:
            raise ValueError('The application command is too large.')
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError('The application command is invalid.')
        result = launch(payload)
    except ValueError as error:
        result = {'ok': False, 'message': str(error)}
    except (OSError, configparser.Error):
        result = {'ok': False, 'message': 'The terminal could not be started.'}
    print(json.dumps(result))


if __name__ == '__main__':
    main()
