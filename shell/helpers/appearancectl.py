#!/usr/bin/env python3
"""Owned, reversible runtime appearance settings; never edits Hyprland files."""
import argparse
import fcntl
import json
import math
import os
from pathlib import Path
from displayctl import atomic, ipc

OPTIONS = {'rounding': 'decoration:rounding', 'size': 'decoration:blur:size', 'passes': 'decoration:blur:passes', 'border': 'general:border_size'}

def observed():
    return {name: int(json.loads(ipc('j/getoption ' + option))['int']) for name, option in OPTIONS.items()}

def code(values):
    decoration = []
    if 'rounding' in values:
        decoration.append('rounding=' + str(int(values['rounding'])))
    blur = [key + '=' + str(int(values[key])) for key in ('size', 'passes') if key in values]
    if blur:
        decoration.append('blur={' + ','.join(blur) + '}')
    groups=[]
    if 'border' in values:groups.append('general={border_size='+str(int(values['border']))+'}')
    if decoration:groups.append('decoration={'+','.join(decoration)+'}')
    return 'hl.config({'+','.join(groups)+'})'

def configure(values):
    if values and ipc('eval ' + code(values)).strip() != 'ok':
        raise ValueError('Desktop appearance was not accepted.')
    actual = observed()
    if any(actual.get(key) != value for key, value in values.items()):
        raise ValueError('Desktop appearance did not match the requested values.')
    return actual

def validated(payload):
    if not isinstance(payload, dict) or not payload or set(payload) - {'radius', 'strength', 'border'}:
        raise ValueError('Choose a corner radius or blur strength.')
    values = {}
    if 'border' in payload:
        if type(payload['border']) is not int or not 0<=payload['border']<=8:
            raise ValueError('Window border width must be between 0 and 8.')
        values['border']=payload['border']
    if 'radius' in payload:
        radius = payload['radius']
        if isinstance(radius, bool) or not isinstance(radius, (int, float)) or not math.isfinite(radius) or not 0 <= radius <= 24:
            raise ValueError('Corner radius must be between 0 and 24.')
        values['rounding'] = round(radius)
    if 'strength' in payload:
        strength = payload['strength']
        if isinstance(strength, bool) or not isinstance(strength, (int, float)) or not math.isfinite(strength) or not 0 < strength <= 1:
            raise ValueError('Blur strength must be greater than zero and at most one.')
        values.update(size=1 + round(strength * 11), passes=2)
    return values

def checked_values(value, original=False):
    if not isinstance(value, dict) or set(value)-set(OPTIONS):
        raise ValueError('Desktop appearance recovery data is invalid and was left unchanged.')
    limits={'rounding':(0,100 if original else 24),'size':(1,100 if original else 12),'passes':(1,10 if original else 4),'border':(0,100 if original else 8)}
    for key,number in value.items():
        low,high=limits[key]
        if type(number) is not int or not low<=number<=high:
            raise ValueError('Desktop appearance recovery data is invalid and was left unchanged.')
    return value


def recovery(path, actual, signature):
    if not path.exists():
        return {'version':2,'session':signature,'original':actual,'managed':{},'pending':{}}
    try:
        saved=json.loads(path.read_text())
        if not isinstance(saved,dict) or saved.get('version',1) not in (1,2) or not isinstance(saved.get('session'),str):
            raise ValueError()
        checked_values(saved.get('original'),True)
        if saved.get('version',1)==1 and set(saved['original'])==set(OPTIONS)-{'border'}:
            saved['original']['border']=actual['border']
        if set(saved['original'])!=set(OPTIONS):raise ValueError()
        checked_values(saved.get('managed'))
        checked_values(saved.get('pending',{}))
    except (OSError,ValueError,TypeError):
        raise ValueError('Desktop appearance recovery data is invalid and was left unchanged.') from None
    saved['version']=2
    saved.setdefault('pending',{})
    if saved['session']!=signature:
        saved.update(session=signature,original=actual)
    return saved


def run(action, payload=None):
    folder = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'swiftshell'
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = folder/'desktop-appearance.json'
    with (folder/'desktop-appearance.lock').open('a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        actual = observed()
        signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
        saved = recovery(path,actual,signature)
        if action == 'status':
            return {'ok': True, 'observed': actual, 'managed': saved['managed'], 'available': True}
        if action=='reload':
            # The owner reloaded their Lua: these newly observed values become
            # the recovery baseline before managed preferences are reapplied.
            saved['original']=dict(actual)
        original=saved['original']
        owned=dict(saved['managed'],**saved['pending'])
        if action == 'apply':
            wanted = dict(owned,**validated(payload))
        elif action in ('resume','reload'):
            wanted = owned
        elif action == 'restore':
            wanted = {key: original[key] for key in owned}
        else:
            raise ValueError('Unknown appearance action.')
        prior_managed=dict(saved['managed'])
        # Journal desired values BEFORE mutation so restore includes newly owned
        # keys even if the helper dies before its final committed write.
        saved['pending']=dict(wanted) if action!='restore' else dict(owned)
        atomic(path, saved)
        try:
            actual = configure(wanted)
        except Exception:
            configure({key: actual[key] for key in wanted})
            saved['pending']={}
            atomic(path,saved)
            raise
        saved['managed']={} if action=='restore' else dict(prior_managed,**wanted)
        saved['pending']={}
        atomic(path, saved)
        return {'ok': True, 'observed': actual, 'managed': saved['managed'], 'available': True}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['status', 'apply', 'resume', 'reload', 'restore'])
    parser.add_argument('payload', nargs='?', default='{}')
    args = parser.parse_args()
    try:
        result = run(args.action, json.loads(args.payload))
    except Exception as error:
        result = {'ok': False, 'available': False, 'message': str(error) if isinstance(error, ValueError) else 'Desktop appearance is unavailable.'}
    print(json.dumps(result, separators=(',', ':')))
