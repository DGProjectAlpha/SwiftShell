#!/usr/bin/env python3
"""Effective Hyprland shortcut viewer and scoped SwiftShell-owned bindings.

Opaque Lua callbacks cannot be reconstructed from j/binds. Never remove or
replace those bindings. Only handles created by this helper can be removed.
Managed choices persist in SwiftShell state and are reapplied by its service.
"""
import argparse
import ctypes
import ctypes.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from displayctl import atomic, ipc, read

SHELL = Path(__file__).resolve().parents[1]
PREFIX = 'SwiftShell · '
MODS = {'shift': 1, 'ctrl': 4, 'alt': 8, 'super': 64}
ACTIONS = [
    ('spotlight', 'Spotlight', 'SwiftShell'), ('settings', 'Settings', 'SwiftShell'),
    ('control', 'Control center', 'SwiftShell'), ('terminal', 'Terminal', 'Applications'),
    ('focus-left', 'Focus window left', 'Windows'), ('focus-right', 'Focus window right', 'Windows'),
    ('focus-up', 'Focus window above', 'Windows'), ('focus-down', 'Focus window below', 'Windows'),
    ('move-left', 'Move window left', 'Windows'), ('move-right', 'Move window right', 'Windows'),
    ('move-up', 'Move window above', 'Windows'), ('move-down', 'Move window below', 'Windows'),
    ('float', 'Toggle floating', 'Windows'), ('fullscreen', 'Toggle fullscreen', 'Windows'),
    ('maximize', 'Maximize / restore', 'Windows'),
] + [('workspace-' + str(i), 'Workspace ' + str(i), 'Workspaces') for i in range(1, 11)]
CATALOG = {item[0]: item for item in ACTIONS}


def lua_string(value, **kwargs):
    return json.dumps(value, ensure_ascii=False, **kwargs)


def state_path():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'swiftshell/shortcuts.json'


def settings():
    try:
        saved = json.loads(state_path().read_text()) if state_path().exists() else {'version': 1, 'bindings': {}}
    except (OSError, ValueError):
        raise ValueError('Saved shortcuts are invalid and were left unchanged.') from None
    if not isinstance(saved, dict) or saved.get('version') != 1 or not isinstance(saved.get('bindings'), dict):
        raise ValueError('Saved shortcuts are invalid and were left unchanged.')
    return saved


def normalize(modifiers, key):
    if not isinstance(modifiers, list) or not modifiers or any(m not in MODS for m in modifiers):
        raise ValueError('Use Super, Ctrl or Alt together with a key.')
    mods = [m for m in MODS if m in modifiers]
    if mods == ['shift']:
        raise ValueError('Add Super, Ctrl or Alt so ordinary typing stays available.')
    if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_]{1,32}', key):
        raise ValueError('Choose a supported keyboard key.')
    aliases = {'space': 'Space', 'return': 'Return', 'tab': 'Tab', 'backspace': 'BackSpace', 'delete': 'Delete',
               'left': 'Left', 'right': 'Right', 'up': 'Up', 'down': 'Down', 'home': 'Home', 'end': 'End',
               'pageup': 'Page_Up', 'page_up': 'Page_Up', 'pagedown': 'Page_Down', 'page_down': 'Page_Down', 'minus': 'minus', 'equal': 'equal',
               'comma': 'comma', 'period': 'period', 'slash': 'slash', 'semicolon': 'semicolon',
               'apostrophe': 'apostrophe', 'bracketleft': 'bracketleft', 'bracketright': 'bracketright', 'grave': 'grave'}
    low = key.lower()
    if len(key) == 1: key = key.upper()
    elif re.fullmatch(r'f([1-9]|[12][0-9]|3[0-5])', low): key = low.upper()
    elif low in aliases: key = aliases[low]
    else: raise ValueError('This key is not supported by the recorder.')
    if 'ctrl' in mods and 'alt' in mods and re.fullmatch(r'F(?:[1-9]|1[0-2])', key):
        raise ValueError('This key combination is reserved for recovery consoles.')
    return {'modifiers': mods, 'key': key}


def chord_text(chord):
    return ' + '.join([m.upper() for m in chord['modifiers']] + [chord['key']])


def mask(chord):
    return sum(MODS[m] for m in chord['modifiers'])


def live():
    return json.loads(ipc('j/binds'))


def owner_description(action):
    return PREFIX + CATALOG[action][1]


def physical_codes(key):
    """Resolve all active-layout keycodes, including user code:N bindings."""
    class Names(ctypes.Structure):
        _fields_ = [(name, ctypes.c_char_p) for name in ('rules', 'model', 'layout', 'variant', 'options')]
    libname = ctypes.util.find_library('xkbcommon')
    if not libname:
        raise ValueError('Keyboard layout verification is unavailable. No shortcut was changed.')
    lib = ctypes.CDLL(libname)
    signatures = {
        'xkb_context_new': (ctypes.c_void_p, [ctypes.c_int]),
        'xkb_keymap_new_from_names': (ctypes.c_void_p, [ctypes.c_void_p, ctypes.POINTER(Names), ctypes.c_int]),
        'xkb_keysym_from_name': (ctypes.c_uint32, [ctypes.c_char_p, ctypes.c_int]),
        'xkb_keysym_to_lower': (ctypes.c_uint32, [ctypes.c_uint32]),
        'xkb_keymap_min_keycode': (ctypes.c_uint32, [ctypes.c_void_p]),
        'xkb_keymap_max_keycode': (ctypes.c_uint32, [ctypes.c_void_p]),
        'xkb_keymap_num_layouts_for_key': (ctypes.c_uint32, [ctypes.c_void_p, ctypes.c_uint32]),
        'xkb_keymap_num_levels_for_key': (ctypes.c_uint32, [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32]),
        'xkb_keymap_key_get_syms_by_level': (ctypes.c_int, [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(ctypes.POINTER(ctypes.c_uint32))]),
        'xkb_keymap_unref': (None, [ctypes.c_void_p]),
        'xkb_context_unref': (None, [ctypes.c_void_p]),
    }
    for name, (restype, argtypes) in signatures.items():
        getattr(lib, name).restype = restype; getattr(lib, name).argtypes = argtypes
    keyboards = json.loads(ipc('j/devices')).get('keyboards', [])
    keyboard = next((item for item in keyboards if item.get('main')), None)
    if not keyboard:
        raise ValueError('No active keyboard layout can be verified.')
    names = Names(*(str(keyboard.get(field, '')).encode() or None for field, _ in Names._fields_))
    context = lib.xkb_context_new(0)
    keymap = lib.xkb_keymap_new_from_names(context, ctypes.byref(names), 0) if context else None
    if not keymap:
        if context: lib.xkb_context_unref(context)
        raise ValueError('The active keyboard layout could not be read.')
    result = set()
    target = lib.xkb_keysym_to_lower(lib.xkb_keysym_from_name(key.encode(), 1))
    try:
        for code in range(lib.xkb_keymap_min_keycode(keymap), lib.xkb_keymap_max_keycode(keymap) + 1):
            for layout in range(lib.xkb_keymap_num_layouts_for_key(keymap, code)):
                for level in range(lib.xkb_keymap_num_levels_for_key(keymap, code, layout)):
                    values = ctypes.POINTER(ctypes.c_uint32)()
                    count = lib.xkb_keymap_key_get_syms_by_level(keymap, code, layout, level, ctypes.byref(values))
                    if any(lib.xkb_keysym_to_lower(values[index]) == target for index in range(count)):
                        result.add(code)
        return result
    finally:
        lib.xkb_keymap_unref(keymap); lib.xkb_context_unref(context)


def collision(chord, binds, action=''):
    codes = None
    for bind in binds:
        if bind.get('submap') or bind.get('release'):
            continue
        if int(bind.get('modmask', 0)) != mask(chord):
            continue
        same = str(bind.get('key', '')).casefold() == chord['key'].casefold()
        if bind.get('keycode'):
            if codes is None: codes = physical_codes(chord['key'])
            same = int(bind['keycode']) in codes
        if same:
            if action and bind.get('description') == owner_description(action):
                continue
            return bind.get('description') or 'An existing desktop shortcut'
    return ''


def action_code(action):
    if action not in CATALOG:
        raise ValueError('Choose a supported shortcut action.')
    if action.startswith('focus-'):
        return 'hl.dsp.focus({direction=' + lua_string(action[6:]) + '})'
    if action.startswith('move-'):
        return 'hl.dsp.window.move({direction=' + lua_string(action[5:]) + '})'
    if action.startswith('workspace-'):
        return 'hl.dsp.focus({workspace=' + action[10:] + '})'
    if action == 'float': return 'hl.dsp.window.float({action="toggle"})'
    if action in ('fullscreen', 'maximize'):
        return 'hl.dsp.window.fullscreen({mode=' + lua_string('maximized' if action == 'maximize' else 'fullscreen') + ',action="toggle"})'
    argv = [sys.executable, str(Path(__file__).resolve()), 'invoke', '--id', action]
    return 'hl.dsp.exec_cmd(' + lua_string(shlex.join(argv)) + ')'


def evaluate(code):
    if ipc('eval ' + code).strip() != 'ok':
        raise ValueError('Hyprland did not accept the shortcut change.')


def register(action, chord):
    code = '_G.__swiftshell_shortcuts=_G.__swiftshell_shortcuts or {}; '
    if chord is None:
        code += 'local old=_G.__swiftshell_shortcuts[' + lua_string(action) + ']; '
        code += 'if old then old:remove(); _G.__swiftshell_shortcuts[' + lua_string(action) + ']=nil end'
    else:
        code += 'local nextBind=hl.bind(' + lua_string(chord_text(chord)) + ',' + action_code(action)
        code += ',{description=' + lua_string(owner_description(action)) + '}); assert(nextBind,"Cannot create shortcut"); '
        code += 'local old=_G.__swiftshell_shortcuts[' + lua_string(action) + ']; if old then old:remove() end; '
        code += '_G.__swiftshell_shortcuts[' + lua_string(action) + ']=nextBind'
    evaluate(code)


def backup(saved):
    # Journal before mutation; contains only catalog ids/chords, no private commands.
    path = state_path().with_name('shortcuts-previous.json')
    atomic(path, saved)


def apply(action, modifiers, key):
    if action not in CATALOG: raise ValueError('Choose a shortcut action.')
    chord = normalize(modifiers, key)
    saved = settings()
    old = saved['bindings'].get(action)
    if old == chord: return
    conflict = collision(chord, live(), action)
    if conflict: raise ValueError('Already used by ' + conflict + '. Choose another shortcut.')
    backup(saved)
    register(action, chord)
    try:
        if not any(b.get('description') == owner_description(action) and b.get('modmask') == mask(chord)
                   and b.get('key', '').casefold() == chord['key'].casefold() for b in live()):
            raise ValueError('Shortcut readback did not match. The previous shortcut was restored.')
        saved['bindings'][action] = chord
        atomic(state_path(), saved)
    except Exception:
        register(action, old)
        raise


def remove(action):
    if action not in CATALOG: raise ValueError('Choose a shortcut action.')
    saved = settings()
    if action not in saved['bindings']: return
    old = saved['bindings'][action]
    backup(saved)
    register(action, None)
    try:
        del saved['bindings'][action]
        atomic(state_path(), saved)
    except Exception:
        register(action, old)
        raise


def sync():
    errors = []
    saved = settings()
    observed = live()
    for action, value in saved['bindings'].items():
        try:
            if action not in CATALOG: continue
            chord = normalize(value.get('modifiers'), value.get('key'))
            conflict = collision(chord, observed, action)
            if conflict:
                errors.append(CATALOG[action][1] + ': already used by ' + conflict)
                continue
            register(action, chord)
        except (ValueError, OSError, KeyError, AttributeError):
            errors.append(CATALOG.get(action, (action, action))[1] + ': could not be restored')
    return errors


def restore_previous():
    previous = read(state_path().with_name('shortcuts-previous.json'), None)
    if not isinstance(previous, dict) or previous.get('version') != 1 or not isinstance(previous.get('bindings'), dict):
        raise ValueError('No previous shortcut change is available.')
    current = settings()
    # Validate the entire rollback before changing any binding.
    observed = live()
    for action, value in previous['bindings'].items():
        if action not in CATALOG: raise ValueError('The previous shortcut set is not supported.')
        chord = normalize(value.get('modifiers'), value.get('key'))
        conflict = collision(chord, observed, action)
        if conflict: raise ValueError('Undo would conflict with ' + conflict + '.')
    completed = []
    try:
        for action in set(current['bindings']) | set(previous['bindings']):
            register(action, previous['bindings'].get(action)); completed.append(action)
        atomic(state_path(), previous)
        atomic(state_path().with_name('shortcuts-previous.json'), current)
    except Exception:
        for action in reversed(completed): register(action, current['bindings'].get(action))
        raise


def snapshot(errors=None):
    saved = settings()
    observed = live()
    effective = []
    for index, bind in enumerate(observed):
        key = bind.get('key') or ('code:' + str(bind.get('keycode'))) if bind.get('key') or bind.get('keycode') else 'Any key'
        mods = [name.upper() for name, value in MODS.items() if int(bind.get('modmask', 0)) & value]
        flags = [label for field, label in [('locked', 'Locked'), ('release', 'On release'), ('repeat', 'Repeating'), ('mouse', 'Mouse'), ('longPress', 'Long press')] if bind.get(field)]
        description = bind.get('description') or bind.get('dispatcher') or 'Desktop shortcut'
        managed = next((action for action, value in saved['bindings'].items() if action in CATALOG
            and description == owner_description(action) and mask(value) == int(bind.get('modmask', 0)) and value['key'].casefold() == str(bind.get('key', '')).casefold()), '')
        effective.append({'id': str(index), 'label': description, 'chord': ' + '.join(mods + [key]),
                          'owner': 'SwiftShell' if managed else 'Hyprland', 'managedId': managed,
                          'scope': bind.get('submap') or 'Desktop', 'flags': ' · '.join(flags)})
    catalog = [{'id': action, 'label': label, 'category': category, 'binding': saved['bindings'].get(action),
                'active': any(row['managedId'] == action for row in effective)} for action, label, category in ACTIONS]
    return {'ok': True, 'available': True, 'effective': effective, 'actions': catalog, 'warnings': errors or [],
            'canUndo': state_path().with_name('shortcuts-previous.json').is_file()}


def invoke(action):
    # Runs outside the compositor callback, with fixed commands only.
    if action == 'terminal':
        from defaultappsctl import launch
        launch('terminal'); return
    argv = ['qs', 'ipc', '-p', str(SHELL), 'call', 'swiftshell']
    if action == 'spotlight': argv += ['launcher', 'toggle']
    elif action == 'settings': argv += ['settings', 'shortcuts']
    elif action == 'control':
        monitor = next((m['name'] for m in json.loads(ipc('j/monitors')) if m.get('focused')), '')
        if not monitor: raise ValueError('No focused monitor is available.')
        argv += ['barPanel', monitor, 'control']
    else: raise ValueError('Choose a supported application shortcut.')
    result = subprocess.run(argv, capture_output=True, timeout=5)
    if result.returncode: raise ValueError('SwiftShell is not running.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['snapshot', 'apply', 'remove', 'sync', 'undo', 'invoke'])
    parser.add_argument('--id', default='')
    parser.add_argument('--modifiers', default='[]')
    parser.add_argument('--key', default='')
    args = parser.parse_args()
    try:
        errors = []
        if args.action == 'apply': apply(args.id, json.loads(args.modifiers), args.key)
        elif args.action == 'remove': remove(args.id)
        elif args.action == 'sync': errors = sync()
        elif args.action == 'undo': restore_previous()
        elif args.action == 'invoke':
            invoke(args.id); print(json.dumps({'ok': True})); return
        print(json.dumps(snapshot(errors), separators=(',', ':')))
    except Exception as error:
        message = str(error) if isinstance(error, ValueError) else 'Desktop shortcuts are unavailable.'
        print(json.dumps({'ok': False, 'message': message})); sys.exit(1)


if __name__ == '__main__': main()
