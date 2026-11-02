#!/usr/bin/env python3
"""Typed power-profiles-daemon access; never edits services or CPU sysfs."""
import argparse
import json
import subprocess

ENDPOINTS = (
    ('org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles'),
    ('net.hadess.PowerProfiles', '/net/hadess/PowerProfiles'),
)
LABELS = {'power-saver': 'Power Saver', 'balanced': 'Balanced', 'performance': 'Performance'}
DESCRIPTIONS = {
    'power-saver': 'Reduce energy use and favor quieter operation.',
    'balanced': 'Balance responsiveness and energy use.',
    'performance': 'Favor speed when hardware and cooling allow it.',
}


def command(args):
    result = subprocess.run(['busctl', '--system', '--json=short', '--allow-interactive-authorization=no'] + list(args),
                            capture_output=True, text=True, timeout=6, check=False)
    if result.returncode:
        raise ValueError('System power profiles are unavailable or access was denied.')
    return result.stdout


def value(properties, name, default=None):
    entry = properties.get(name, {})
    return entry.get('data', default) if isinstance(entry, dict) else default


def discover():
    for endpoint in ENDPOINTS:
        name, path = endpoint
        try:
            response = json.loads(command(['call', name, path, 'org.freedesktop.DBus.Properties', 'GetAll', 's', name]))
            data = response.get('data', [])
            if response.get('type') != 'a{sv}' or not isinstance(data, list) or not data or not isinstance(data[0], dict):
                continue
            properties = data[0]
            active = value(properties, 'ActiveProfile', '')
            profiles = value(properties, 'Profiles', [])
            if active not in LABELS or not isinstance(profiles, list):
                continue
            ids = [value(profile, 'Profile', '') for profile in profiles if isinstance(profile, dict)]
            ids = [profile for profile in LABELS if profile in ids]
            if not ids:
                continue
            inhibited = value(properties, 'PerformanceInhibited', '')
            degraded = value(properties, 'PerformanceDegraded', '')
            holds = value(properties, 'ActiveProfileHolds', [])
            return endpoint, {'available': True, 'active': active,
                'profiles': [{'id': profile, 'label': LABELS[profile], 'description': DESCRIPTIONS[profile],
                    'enabled': profile != 'performance' or not bool(inhibited)} for profile in ids],
                'inhibited': str(inhibited) if isinstance(inhibited, str) else '',
                'degraded': str(degraded) if isinstance(degraded, str) else '',
                'holds': len(holds) if isinstance(holds, list) else 0}
        except (ValueError, OSError, subprocess.SubprocessError):
            continue
    raise ValueError('System power profiles are not available on this computer.')


def run(action='snapshot', profile=''):
    if action not in ('snapshot', 'set'):
        raise ValueError('Unknown power-profile action.')
    if action == 'set' and profile not in LABELS:
        raise ValueError('Choose an available power profile.')
    endpoint, report = discover()
    if action == 'set':
        option = next((option for option in report['profiles'] if option['id'] == profile), None)
        if not option or not option['enabled']:
            raise ValueError('This power profile is currently unavailable.')
        if report['active'] != profile:
            name, path = endpoint
            command(['set-property', name, path, name, 'ActiveProfile', 's', profile])
            _, report = discover()
            if report['active'] != profile:
                return dict(report, ok=False, message='The profile did not become active. Another application may be holding a power profile.')
    return dict(report, ok=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['snapshot', 'set'])
    parser.add_argument('profile', nargs='?', default='')
    args = parser.parse_args()
    try:
        result = run(args.action, args.profile)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result = {'ok': False, 'available': False,
                  'message': str(error) if isinstance(error, ValueError) else 'System power profiles are unavailable.'}
    print(json.dumps(result, separators=(',', ':')))
