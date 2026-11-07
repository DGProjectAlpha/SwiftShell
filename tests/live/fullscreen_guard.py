"""Fail closed before an interactive native test can disturb fullscreen apps."""
import json
import subprocess


def require_idle_desktop(clients=None):
    if clients is None:
        try:
            clients = json.loads(subprocess.check_output(['hyprctl', '-j', 'clients'], text=True, stderr=subprocess.DEVNULL))
        except (OSError, ValueError, subprocess.CalledProcessError):
            raise SystemExit('Cannot verify desktop safety; native interactive test refused.') from None
    if not isinstance(clients, list) or any(not isinstance(client, dict) for client in clients):
        raise SystemExit('Cannot verify desktop safety; native interactive test refused.')
    # Include client-requested fullscreen: focus loss can leave a game believing
    # it is fullscreen even when its compositor fullscreen state became zero.
    if any(client.get('mapped') is not False and any(client.get(key) in (2, 3)
            for key in ('fullscreen', 'fullscreenClient')) for client in clients):
        raise SystemExit('An existing fullscreen app is running. Native interactive test refused before creating windows or changing focus. Stop the game/fullscreen app first.')
