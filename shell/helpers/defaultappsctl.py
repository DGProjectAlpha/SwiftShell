#!/usr/bin/env python3
"""XDG default applications and SwiftShell preferences, with scoped undo.

Only desktop ids discovered in standard application directories can be selected.
Desktop commands are never evaluated by this helper. XDG changes use xdg-mime;
launching uses gio's desktop-file parser or xdg-open, never a shell.
"""
import argparse
import base64
import configparser
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import subprocess
import sys
from urllib.parse import urlparse
from displayctl import atomic

ROLES = {
    'browser': ('Web browser', ['x-scheme-handler/https', 'x-scheme-handler/http', 'text/html'], ['WebBrowser']),
    'email': ('Email', ['x-scheme-handler/mailto'], ['Email']),
    'calendar': ('Calendar', ['text/calendar'], ['Calendar']),
    'terminal': ('Terminal', [], ['TerminalEmulator']),
    'files': ('File manager', ['inode/directory'], ['FileManager']),
    'images': ('Images', ['image/png', 'image/jpeg', 'image/webp'], ['Graphics']),
    'media': ('Media player', ['video/mp4', 'audio/mpeg', 'video/webm'], ['Player']),
    'pdf': ('PDF documents', ['application/pdf'], ['Viewer']),
}
ID = re.compile(r'^[A-Za-z0-9_+.-]+\.desktop$')


def state_path():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'swiftshell/default-apps.json'


def preferences():
    try:
        saved = json.loads(state_path().read_text()) if state_path().exists() else {'version': 1, 'roles': {}}
    except (OSError, ValueError):
        raise ValueError('Application preferences are invalid and were left unchanged.') from None
    if not isinstance(saved, dict) or saved.get('version') != 1 or not isinstance(saved.get('roles'), dict):
        raise ValueError('Application preferences use an unsupported format and were left unchanged.')
    return saved


def config_home():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))


def data_dirs():
    home = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    return [home] + [Path(p) for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p]


def desktop_entries():
    entries, seen = {}, set()
    language = (os.environ.get('LC_MESSAGES') or os.environ.get('LANG') or '').split('.')[0]
    for folder in data_dirs():
        application_dir = folder / 'applications'
        if not application_dir.is_dir():
            continue
        for path in sorted(application_dir.rglob('*.desktop')):
            desktop_id = str(path.relative_to(application_dir)).replace('/', '-')
            if desktop_id in seen or not ID.fullmatch(desktop_id):
                continue
            seen.add(desktop_id)  # A hidden user entry also masks the system entry.
            try:
                if path.stat().st_size > 256 * 1024:
                    continue
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.optionxform = str
                parser.read(path, encoding='utf-8')
                entry = parser['Desktop Entry']
                if entry.get('Type') != 'Application' or entry.get('Hidden', '').lower() == 'true':
                    continue
                if not entry.get('Exec') or entry.get('NoDisplay', '').lower() == 'true':
                    continue
                executable = entry.get('TryExec', '')
                if executable and not (Path(executable).is_file() if '/' in executable else shutil.which(executable)):
                    continue
                name = entry.get('Name[' + language + ']', entry.get('Name[' + language.split('_')[0] + ']', entry.get('Name', desktop_id)))
                entries[desktop_id] = dict(id=desktop_id, name=name, icon=entry.get('Icon', ''),
                    path=str(path), exec=entry.get('Exec',''), mimes=entry.get('MimeType', '').split(';'), categories=entry.get('Categories', '').split(';'))
            except (OSError, UnicodeError, configparser.Error, KeyError):
                continue
    return entries


def command(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=6)
    except (OSError, subprocess.SubprocessError):
        raise ValueError('The desktop application service is unavailable.') from None
    if result.returncode != 0:
        raise ValueError('The desktop application service could not complete this change.')
    return result.stdout.strip()


def query(mime):
    return command(['xdg-mime', 'query', 'default', mime])


def candidates(role, entries):
    _, mimes, categories = ROLES[role]
    return sorted((entry for entry in entries.values() if
        any(m in entry['mimes'] for m in mimes) or
        (role in ('terminal', 'calendar') and any(c in entry['categories'] for c in categories))), key=lambda e: (e['name'].casefold(), e['id']))


def mime_files():
    dirs = [config_home()] + [Path(p) for p in os.environ.get('XDG_CONFIG_DIRS', '/etc/xdg').split(':') if p]
    dirs += [directory / 'applications' for directory in data_dirs()]
    desktops = [name.lower() for name in os.environ.get('XDG_CURRENT_DESKTOP', '').split(':') if re.fullmatch(r'[A-Za-z0-9_-]+', name)]
    return list(dict.fromkeys(folder / name for folder in dirs for name in
        [*(desktop + '-mimeapps.list' for desktop in desktops), 'mimeapps.list', 'defaults.list']))


def own_mime_files():
    roots = [config_home(), data_dirs()[0] / 'applications']
    return [path for path in mime_files() if path.parent in roots]


def backup():
    # These files may contain private application paths: retain locally, mode 0600.
    folder = state_path().parent / 'backups'
    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    path = folder / ('default-apps-' + now + '.json')
    files = {}
    for mime_file in own_mime_files():
        if mime_file.is_file():
            raw = mime_file.read_bytes()
            if len(raw) > 2 * 1024 * 1024:
                raise ValueError('An application defaults file is too large to back up safely.')
            files[str(mime_file)] = base64.b64encode(raw).decode('ascii')
    atomic(path, {'version': 1, 'files': files, 'preferences': preferences()})
    return path


def remove_owned_default(mime, desktop_id):
    # Preserve comments, unrelated keys, associations and externally changed values.
    for path in own_mime_files():
        if not path.is_file():
            continue
        target = path.resolve()
        raw = target.read_text()
        section, lines, changed = '', [], False
        for line in raw.splitlines(keepends=True):
            if line.strip().startswith('[') and line.strip().endswith(']'):
                section = line.strip()[1:-1]
            if section == 'Default Applications' and '=' in line:
                key, value = line.split('=', 1)
                if key.strip() == mime and value.strip().strip(';') == desktop_id:
                    changed = True
                    continue
            lines.append(line)
        if changed:
            temp = target.with_name(target.name + '.swiftshell-tmp')
            with temp.open('w') as stream:
                os.chmod(temp, 0o600)
                stream.write(''.join(lines)); stream.flush(); os.fsync(stream.fileno())
            os.replace(temp, target)


def assign(mime, desktop_id, expected=''):
    if desktop_id:
        config_home().mkdir(parents=True, exist_ok=True, mode=0o700)
        command(['xdg-mime', 'default', desktop_id, mime])
    else:
        remove_owned_default(mime, expected)


def terminal_command(entry):
    try:parts=shlex.split(entry.get('exec',''))
    except ValueError:raise ValueError('The terminal application has an invalid launch command.') from None
    args=[]
    for part in parts:
        if part in ('%f','%F','%u','%U','%i','%c','%k'):continue
        part=part.replace('%%','%')
        if '%' in part or any(ord(char)<32 for char in part):raise ValueError('The terminal application uses unsupported launch arguments.')
        args.append(part)
    if not args:raise ValueError('The terminal application has no launch command.')
    return shlex.join(args)


def desktop_terminal(entries):
    import hyprsource
    try:matched=hyprsource.terminal_binding()
    except (OSError,ValueError,UnicodeError):return '',None
    if matched is None:return '',None
    configured=matched['variable']['value']
    try:executable=shlex.split(configured)[0]
    except (ValueError,IndexError):return '',matched
    for entry in candidates('terminal',entries):
        try:program=shlex.split(terminal_command(entry))[0]
        except (ValueError,IndexError):continue
        if program==executable or shutil.which(program) and shutil.which(program)==shutil.which(executable):return entry['id'],matched
    return '',matched


def rollback_terminal(change):
    if change and change.get('transaction'):
        import hyprsource
        hyprsource.recover(hyprsource.state_root()/(change['transaction']+'.json'))


def choose(role, desktop_id):
    if role not in ROLES or not isinstance(desktop_id, str) or not ID.fullmatch(desktop_id):
        raise ValueError('Choose an installed application.')
    entries = desktop_entries()
    app = next((item for item in candidates(role, entries) if item['id'] == desktop_id), None)
    if app is None:
        raise ValueError('This application does not support that role or is no longer installed.')
    settings = preferences()
    roles = settings.setdefault('roles', {})
    previous_role = roles.get(role, {})
    changed_mimes = [mime for mime in ROLES[role][1] if mime in app['mimes']]
    before = {mime: query(mime) for mime in changed_mimes}
    backup()
    applied = []
    terminal_change=None
    try:
        if role=="terminal":
            import hyprsource
            terminal_change=hyprsource.sync_terminal(terminal_command(app))
        for mime in changed_mimes:
            assign(mime, desktop_id)
            applied.append(mime)
            if query(mime) != desktop_id:
                raise ValueError('Another desktop preference overrides this choice. No change was kept.')
        previous = dict(previous_role.get('previous', {}))
        for mime, value in before.items():
            previous.setdefault(mime, value)
        # Preserve ownership of secondary types changed by an earlier selection.
        assigned = dict(previous_role.get('assigned', {}))
        assigned.update({mime: desktop_id for mime in changed_mimes})
        roles[role] = {'id': desktop_id, 'previous': previous, 'assigned': assigned}
        if terminal_change and terminal_change.get('supported'):
            original=previous_role.get('desktopTerminal',{}).get('originalCommand',terminal_change['previousCommand'])
            roles[role]['desktopTerminal']={'originalCommand':original,'assignedCommand':terminal_command(app)}
        atomic(state_path(), settings)
    except Exception:
        rollback_terminal(terminal_change)
        for mime in reversed(applied):
            assign(mime, before[mime], desktop_id)
        raise


def reset(role):
    if role not in ROLES:
        raise ValueError('Choose an application role.')
    settings = preferences()
    saved = settings.get('roles', {}).get(role)
    if not saved:
        return
    assigned = saved.get('assigned', {})
    if any(query(mime) != desktop_id for mime, desktop_id in assigned.items()):
        raise ValueError('Another application changed these defaults. Refresh before changing them again.')
    backup()
    restored = []
    terminal_change=None
    try:
        if role=="terminal" and saved.get('desktopTerminal'):
            import hyprsource
            matched=hyprsource.terminal_binding()
            if matched is None or matched['variable']['value']!=saved['desktopTerminal']['assignedCommand']:
                raise ValueError('Your desktop terminal was changed elsewhere. Refresh before undoing this selection.')
            terminal_change=hyprsource.sync_terminal(saved['desktopTerminal']['originalCommand'])
        for mime, desktop_id in assigned.items():
            assign(mime, saved['previous'].get(mime, ''), desktop_id)
            restored.append(mime)
        del settings['roles'][role]
        atomic(state_path(), settings)
    except Exception:
        rollback_terminal(terminal_change)
        for mime in restored:
            assign(mime, assigned[mime])
        raise


def snapshot():
    entries = desktop_entries()
    saved = preferences().get('roles', {})
    desktop_terminal_id,terminal_source=desktop_terminal(entries)
    roles = []
    for role, (label, mimes, _) in ROLES.items():
        options = candidates(role, entries)
        current = query(mimes[0]) if mimes else ''
        if role in ('terminal', 'calendar') and saved.get(role, {}).get('id') in entries:
            current = saved[role]['id']
        if role=='terminal' and desktop_terminal_id:current=desktop_terminal_id
        selected = entries.get(current)
        roles.append(dict(id=role, label=label, current=current, currentName=selected['name'] if selected else
            ('Not selected' if not current else current.removesuffix('.desktop')),
            desktopLinked=role=='terminal' and bool(desktop_terminal_id),desktopAvailable=role=='terminal' and terminal_source is not None,
            shellOnly=not mimes or (selected is not None and not any(mime in selected['mimes'] for mime in mimes)),
            canReset=role in saved, choices=[{key: item[key] for key in ('id', 'name', 'icon')} for item in options]))
    return {'ok': True, 'roles': roles, 'available': shutil.which('xdg-mime') is not None}


def launch(role, target=''):
    if role not in ROLES:
        raise ValueError('Choose an application role.')
    if target:
        parsed = urlparse(target)
        allowed = {'browser': ('http', 'https'), 'email': ('mailto',), 'calendar': ('webcal', 'calendar')}
        if role not in allowed or parsed.scheme not in allowed[role] or any(ord(c) < 32 for c in target) or len(target) > 8192:
            raise ValueError('This link is not supported by the selected application role.')
        command(['xdg-open', target])
        return
    entries = desktop_entries()
    saved = preferences().get('roles', {}).get(role, {})
    current = saved.get('id', '') if role in ('terminal', 'calendar') else ''
    if role=='terminal':current=desktop_terminal(entries)[0] or current
    if not current and ROLES[role][1]:
        current = query(ROLES[role][1][0])
    if current not in entries:
        raise ValueError('Choose a default ' + ROLES[role][0].lower() + ' in Settings first.')
    command(['gio', 'launch', entries[current]['path']])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['snapshot', 'choose', 'reset', 'launch'])
    parser.add_argument('--role', default='')
    parser.add_argument('--desktop-id', default='')
    parser.add_argument('--target', default='')
    args = parser.parse_args()
    try:
        if args.action == 'choose': choose(args.role, args.desktop_id)
        elif args.action == 'reset': reset(args.role)
        elif args.action == 'launch':
            launch(args.role, args.target)
            print(json.dumps({'ok': True})); return
        print(json.dumps(snapshot(), separators=(',', ':')))
    except Exception as error:
        message = str(error) if isinstance(error, ValueError) else 'Application preferences are unavailable.'
        print(json.dumps({'ok': False, 'message': message})); sys.exit(1)


if __name__ == '__main__': main()
