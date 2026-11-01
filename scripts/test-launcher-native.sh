#!/bin/sh
# Opt-in real Wayland input audit; isolated settings, no global keybindings.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AUDIT_TMP=$(mktemp -d /tmp/swiftshell-launcher-keyboard.XXXXXX)
trap 'rm -rf "$AUDIT_TMP"' EXIT HUP INT TERM
cp -RL "$ROOT/shell" "$AUDIT_TMP/shell"
cp "$ROOT/tests/live/launcher-keyboard.qml" "$AUDIT_TMP/shell/LauncherAudit.qml"
mkdir -p "$AUDIT_TMP/config/swiftshell" "$AUDIT_TMP/state" "$AUDIT_TMP/cache"
cp "$ROOT/shell/config/defaults.json" "$AUDIT_TMP/config/swiftshell/settings.json"
export XDG_CONFIG_HOME="$AUDIT_TMP/config" XDG_STATE_HOME="$AUDIT_TMP/state" XDG_CACHE_HOME="$AUDIT_TMP/cache"
qs -p "$AUDIT_TMP/shell/LauncherAudit.qml" >"$AUDIT_TMP/audit.log" 2>&1
rg -q 'Launcher keyboard audit: real input typing and Escape passed' "$AUDIT_TMP/audit.log" || { cat "$AUDIT_TMP/audit.log"; exit 1; }
printf '%s\n' 'Native launcher keyboard: real Wayland input typing and Escape passed.'
