#!/usr/bin/env python3
"""SwiftShell display transactions. Standard library only; no user config edits.

The short-lived CLI is the QML bridge. An independent session watchdog owns the
15-second confirmation deadline and fsynced recovery journal before any modeset.
Only a fixed set of validated display fields can reach Hyprland's Lua API.
"""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import socket
import struct
import subprocess
import sys
import time

TIMEOUT = 15
FIELDS = ('width', 'height', 'refresh', 'scale', 'transform', 'x', 'y', 'enabled')
MODE = re.compile(r'^(\d+)x(\d+)@([\d.]+)Hz$')


def atomic(path, data):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    with temp.open('w') as stream:
        os.chmod(temp, 0o600)
        json.dump(data, stream, separators=(',', ':'))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)
    fd = os.open(path.parent, os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def ipc(request):
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not signature or not re.fullmatch(r'[A-Za-z0-9_.-]+', signature):
        raise ValueError('Hyprland is unavailable.')
    path = Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / signature / '.socket.sock'
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(3)
        connection.connect(str(path))
        connection.sendall(request.encode())
        result = bytearray()
        while chunk := connection.recv(65536):
            result.extend(chunk)
            if len(result) > 8 * 1024 * 1024:
                raise ValueError('Display response exceeded its limit.')
    return result.decode()


def snapshot():
    raw = json.loads(ipc('j/monitors all'))
    outputs = []
    for m in raw:
        modes = []
        for text in m.get('availableModes', []):
            match = MODE.fullmatch(text)
            if match:
                w, h, hz = match.groups()
                modes.append({'width': int(w), 'height': int(h), 'refresh': float(hz)})
        outputs.append(dict(name=m['name'], friendly=m.get('model') or m.get('description') or m['name'],
                            description=m.get('description', ''), width=m['width'], height=m['height'],
                            refresh=m.get('refreshRate', 0), scale=m.get('scale', 1),
                            transform=m.get('transform', 0), x=m.get('x', 0), y=m.get('y', 0),
                            enabled=not m.get('disabled', False), modes=modes,
                            format=m.get('currentFormat', ''), vrr=m.get('vrr', False),
                            mirror=m.get('mirrorOf', 'none'), hardware=m.get('hardwareDetails', {})))
    return outputs


def validate(proposed, current):
    if not isinstance(proposed, list) or not 1 <= len(proposed) <= 16:
        raise ValueError('Choose a connected display layout.')
    available = {m['name']: m for m in current}
    if len(proposed) != len(available):
        raise ValueError('Connected displays changed. Refresh the layout.')
    names = set()
    clean = []
    for item in proposed:
        if not isinstance(item, dict) or item.get('name') not in available or item['name'] in names:
            raise ValueError('Display names must match connected outputs.')
        names.add(item['name'])
        live = available[item['name']]
        values = {'name': item['name']}
        for field in FIELDS:
            value = item.get(field)
            if field == 'enabled':
                if type(value) is not bool:
                    raise ValueError('Invalid display state.')
            elif type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError('Display values must be finite numbers.')
            values[field] = value
        if not .5 <= values['scale'] <= 3 or values['transform'] not in range(8):
            raise ValueError('Choose a supported scale or rotation.')
        if any(type(values[k]) is not int or abs(values[k]) > 32768 for k in ('x', 'y')):
            raise ValueError('Display position is outside the supported desktop.')
        if values['enabled']:
            valid_mode = any(m['width'] == values['width'] and m['height'] == values['height']
                             and abs(m['refresh'] - values['refresh']) < .1 for m in live['modes'])
            # Preserve the exact live mode even when advertised refresh is rounded.
            valid_mode |= all(values[k] == live[k] for k in ('width', 'height', 'refresh'))
            if not valid_mode or values['width'] < 1 or values['height'] < 1:
                raise ValueError('That display mode is not advertised by the monitor.')
            if live.get('mirror', 'none') != 'none':
                raise ValueError('Mirrored outputs are managed by your existing configuration.')
        clean.append(values)
    if not any(m['enabled'] for m in clean):
        raise ValueError('At least one display must stay enabled.')
    for i, a in enumerate(clean):
        if not a['enabled']:
            continue
        aw, ah = logical_size(a)
        # Hyprland rounds effective dimensions; reject scales that it would silently replace.
        if abs(aw-round(aw)) > .02 or abs(ah-round(ah)) > .02:
            raise ValueError('This resolution needs a scale that gives whole logical pixels.')
        for b in clean[i+1:]:
            if not b['enabled']:
                continue
            bw, bh = logical_size(b)
            if a['x'] < b['x']+bw and a['x']+aw > b['x'] and a['y'] < b['y']+bh and a['y']+ah > b['y']:
                raise ValueError('Displays overlap. Move them apart before applying.')
    return clean


def logical_size(item):
    w, h = item['width'], item['height']
    if item['transform'] % 2:
        w, h = h, w
    return w/item['scale'], h/item['scale']


def lua_spec(item, baseline):
    """hl.monitor merges supplied fields into an existing rule (verified 0.57).

    Send only changed fields to preserve color/HDR/ICC/reserved/VRR settings.
    The recovery path supplies the same owned fields from the durable baseline.
    """
    fields = {'output': item['name']}
    if any(item[k] != baseline[k] for k in ('width', 'height', 'refresh')):
        fields['mode'] = f"{item['width']}x{item['height']}@{item['refresh']:.5f}"
    if any(item[k] != baseline[k] for k in ('x', 'y')):
        fields['position'] = f"{item['x']}x{item['y']}"
    for name in ('scale', 'transform'):
        if item[name] != baseline[name]:
            fields[name] = item[name]
    if item['enabled'] != baseline['enabled']:
        fields['disabled'] = not item['enabled']
    def literal(value):
        if isinstance(value, bool):
            return 'true' if value else 'false'
        return json.dumps(value, ensure_ascii=False)
    return 'hl.monitor({' + ','.join(f'{k}={literal(v)}' for k,v in fields.items()) + '})' if len(fields)>1 else ''


def apply_layout(target, baseline):
    previous = {m['name']: m for m in baseline}
    # Enable outputs before disabling any, and keep original unrelated options intact.
    ordered = sorted(target, key=lambda m: not m['enabled'])
    commands = [lua_spec(m, previous[m['name']]) for m in ordered if m['name'] in previous]
    commands = [c for c in commands if c]
    if commands:
        result = ipc('eval ' + ';'.join(commands))
        if result.strip() != 'ok':
            raise ValueError('Hyprland did not accept the display layout.')


def matches(target, observed):
    live = {m['name']: m for m in observed}
    for m in target:
        n = live.get(m['name'])
        if n is None or m['enabled'] != n['enabled']:
            return False
        if m['enabled'] and any(abs(m[k]-n[k]) > (.12 if k=='refresh' else .02) for k in FIELDS if k!='enabled'):
            return False
    return True


def paths():
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', 'none')
    key = hashlib.sha256(signature.encode()).hexdigest()[:16]
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'swiftshell'
    runtime.mkdir(mode=0o700, exist_ok=True)
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'swiftshell' / 'displays'
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    return runtime/f'displays-{key}.sock', state/f'transaction-{key}.json', state/'accepted.json'


def read(path, fallback):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return fallback


def owner_alive(pid, start):
    try:
        return Path(f'/proc/{pid}/stat').read_text().split(') ',1)[1].split()[19] == start
    except OSError:
        return False


def serve():
    address, journal, accepted = paths()
    with address.with_suffix('.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        address.unlink(missing_ok=True)
        server = socket.socket(socket.AF_UNIX)
        server.bind(str(address)); os.chmod(address, 0o600); server.listen(4)
        state = read(journal, {'state':'idle'})
        active = state.get('state') in ('applying','pending','reverting','recovery-failed')
        expires = 0  # A previous pending journal is always recovered before new work.
        idle_since = time.monotonic()
        interrupted = False
        def stop(_signum, _frame):
            nonlocal interrupted
            interrupted = True
        signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGINT, stop)
        def rollback(reason):
            nonlocal state, active
            state['state'] = 'reverting'; atomic(journal, state)
            try:
                # Force restoration of every changed field, including partial apply failures.
                apply_layout(state['before'], state['target'])
                for _ in range(20):
                    if matches(state['before'], snapshot()): break
                    time.sleep(.1)
                else: raise ValueError('Display recovery could not be verified.')
                state = {'state':'reverted', 'message':reason}
                active = False
            except Exception:
                state['state'] = 'recovery-failed'
                state['message'] = 'Recovery needs attention. Retry Revert; the original snapshot is retained.'
            atomic(journal, state)
        while True:
            if active and (time.monotonic() >= expires or interrupted or not owner_alive(state.get('owner',0), state.get('ownerStart',''))):
                rollback('Previous display settings restored.')
                expires = time.monotonic()+2
            if interrupted and not active: break
            if not active and time.monotonic()-idle_since > 10: break
            if not select.select([server], [], [], .2)[0]: continue
            with server.accept()[0] as client:
                client.settimeout(2)
                _, uid, _ = struct.unpack('3i', client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED,12))
                if uid != os.getuid(): continue
                try:
                    data = bytearray()
                    while b'\n' not in data:
                        chunk=client.recv(65536)
                        if not chunk: raise ValueError("Display request disconnected.")
                        data.extend(chunk)
                        if len(data)>65536: raise ValueError('Display request is too large.')
                    request = json.loads(data.split(b'\n')[0])
                    action = request.get('action')
                    idle_since = time.monotonic()
                    if action in ('apply','restore'):
                        if active: raise ValueError('Keep or revert the pending layout first.')
                        before = snapshot()
                        proposed = request.get('outputs') if action=='apply' else read(accepted,{}).get('outputs')
                        target = validate(proposed, before)
                        version = json.loads(ipc('j/version')).get('tag','')
                        if not version.lstrip('v').startswith('0.57.'):
                            raise ValueError('Display Apply requires the verified Hyprland 0.57 Lua API.')
                        owner = int(request['owner'])
                        start = Path(f'/proc/{owner}/stat').read_text().split(') ',1)[1].split()[19]
                        state = {'state':'applying','before':before,'target':target,'owner':owner,'ownerStart':start}
                        atomic(journal,state)  # fsync before first compositor mutation
                        active = True; expires = time.monotonic()+TIMEOUT
                        try:
                            apply_layout(target,before)
                            for _ in range(25):
                                if matches(target,snapshot()): break
                                time.sleep(.1)
                            else: raise ValueError('The monitor did not accept those settings.')
                            state['state']='pending'; atomic(journal,state)
                        except Exception:
                            rollback('The display change failed; previous settings were restored.')
                    elif action=='keep':
                        if not active or state.get('state')!='pending' or time.monotonic()>=expires:
                            raise ValueError('The confirmation period has ended.')
                        if not matches(state['target'],snapshot()): raise ValueError('Display state changed. Revert and try again.')
                        atomic(accepted, {'outputs':state['target']})
                        state={'state':'kept','message':'Display settings kept. Saved layout is available to restore.'}
                        atomic(journal,state); active=False
                    elif action=='revert':
                        if active: rollback('Previous display settings restored.')
                    elif action!='status': raise ValueError('Unknown display action.')
                    response={'ok':True,'state':state['state'],'message':state.get('message',''),
                              'remaining':max(0,math.ceil(expires-time.monotonic())) if active else 0,
                              'outputs':snapshot(),'hasSaved':accepted.exists()}
                except Exception as error:
                    response={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Display operation failed safely.'}
                try: client.sendall((json.dumps(response)+'\n').encode())
                except OSError: pass
        server.close(); address.unlink(missing_ok=True)


def request(action, outputs=None):
    address, journal, accepted = paths()
    if action=='snapshot':
        saved=read(journal,{'state':'idle'})
        return dict(ok=True,outputs=snapshot(),state=saved.get('state','idle'),hasSaved=accepted.exists(),remaining=0)
    if not address.exists():
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'serve'], start_new_session=True,
                         stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,close_fds=True)
        for _ in range(50):
            if address.exists(): break
            time.sleep(.02)
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(12)
        connection.connect(str(address))
        connection.sendall((json.dumps({'action':action,'outputs':outputs,'owner':os.getppid()})+'\n').encode())
        data=bytearray()
        while b'\n' not in data:
            chunk=connection.recv(65536)
            if not chunk: raise ValueError('The display watchdog disconnected.')
            data.extend(chunk)
        return json.loads(data.split(b'\n')[0])


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['snapshot','status','apply','keep','revert','restore','serve'])
    parser.add_argument('--outputs',default='null')
    args=parser.parse_args()
    if args.action=='serve': serve()
    else:
        try: result=request(args.action,json.loads(args.outputs))
        except Exception as error:
            result={'ok':False,'message':str(error) if isinstance(error,ValueError) else 'Could not reach the display service.'}
        print(json.dumps(result,separators=(',',':')))
