#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CONFIG="$ROOT/shell"
CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
SETTINGS_DIR="$CONFIG_HOME/swiftshell"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

if [ ! -f "$CONFIG/shell.qml" ]; then
    echo "SwiftShell: missing shell entrypoint at shell/shell.qml" >&2
    exit 1
fi

if command -v qs >/dev/null 2>&1; then
    BIN=qs
elif command -v quickshell >/dev/null 2>&1; then
    BIN=quickshell
else
    echo "SwiftShell: qs or quickshell was not found on PATH." >&2
    echo "Install Quickshell, then rerun scripts/launch.sh." >&2
    echo "On CachyOS, install the quickshell package with pacman, then rerun scripts/launch.sh." >&2
    echo "This script does not install packages or change Hyprland or Noctalia." >&2
    exit 127
fi

mkdir -p "$SETTINGS_DIR"
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
mkdir -p "$STATE_HOME/swiftshell"
if [ ! -e "$SETTINGS_FILE" ]; then
    cp "$CONFIG/config/defaults.json" "$SETTINGS_FILE"
fi

echo "SwiftShell: launching the M1 prototype"
echo "SwiftShell: stop it with scripts/stop.sh"
exec "$BIN" --path "$CONFIG" --no-duplicate
