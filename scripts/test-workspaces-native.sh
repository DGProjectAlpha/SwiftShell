#!/bin/sh
# Opt-in live Quickshell test: hidden window, temporary settings, no dispatch.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AUDIT_TMP=$(mktemp -d /tmp/swiftshell-workspace-settings.XXXXXX)
trap 'rm -rf "$AUDIT_TMP"' EXIT HUP INT TERM
cp -RL "$ROOT/shell" "$AUDIT_TMP/shell"
cp "$ROOT/tests/live/settings-workspaces.qml" "$AUDIT_TMP/shell/SettingsAudit.qml"
mkdir -p "$AUDIT_TMP/config/swiftshell" "$AUDIT_TMP/state" "$AUDIT_TMP/cache"
cp "$ROOT/shell/config/defaults.json" "$AUDIT_TMP/config/swiftshell/settings.json"
export XDG_CONFIG_HOME="$AUDIT_TMP/config" XDG_STATE_HOME="$AUDIT_TMP/state" XDG_CACHE_HOME="$AUDIT_TMP/cache"
qs -p "$AUDIT_TMP/shell/SettingsAudit.qml" >"$AUDIT_TMP/write.log" 2>&1
rg -q 'Workspace settings audit: save completed' "$AUDIT_TMP/write.log" || { cat "$AUDIT_TMP/write.log"; exit 1; }
python3 - "$AUDIT_TMP/config/swiftshell/settings.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    settings = json.load(stream)
assert json.loads(settings['bar']['workspaceOutputsJson']) == {'DP-1':['1','2','3','gaming'],'HDMI-A-1':None}
assert settings['settingsWindow']['category'] == 'workspaces'
assert settings['clock']['showSeconds'] and settings['clock']['showDate']
assert settings['clock']['dateFormat'] == 'iso' and not settings['clock']['use24Hour']
assert settings['bar']['searchLabel']
assert settings['launcher']['defaultMode'] == 'favorites'
assert json.loads(settings['bar']['moduleSidesJson']) == {'clock':'center'}
assert json.loads(settings['bar']['hiddenOutputsJson']) == {'DP-1':['tray']}
assert settings['bar']['surfaceMode'] == 'solid'
assert settings['bar']['surfaceColor'] == '#dedede'
assert json.loads(settings['bar']['surfaceOutputsJson']) == {'DP-1':{'mode':'frosted','color':'#222222','opacity':0.4}}
PY
SWIFTSHELL_AUDIT_READBACK=1 qs -p "$AUDIT_TMP/shell/SettingsAudit.qml" >"$AUDIT_TMP/read.log" 2>&1
rg -q 'Workspace settings audit: restart readback passed' "$AUDIT_TMP/read.log" || { cat "$AUDIT_TMP/read.log"; exit 1; }
printf '%s\n' 'Native workspace settings: hidden SettingsWindow loaded; atomic save and restart readback passed.'
