#!/bin/sh
# Isolated native FileView identical-write and queued-write regression.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AUDIT_TMP=$(mktemp -d /tmp/swiftshell-save-cycle.XXXXXX)
trap 'rm -rf "$AUDIT_TMP"' EXIT HUP INT TERM
cp -RL "$ROOT/shell" "$AUDIT_TMP/shell"
cp "$ROOT/tests/live/settings-save-cycle.qml" "$AUDIT_TMP/shell/SaveAudit.qml"
mkdir -p "$AUDIT_TMP/config/swiftshell" "$AUDIT_TMP/state" "$AUDIT_TMP/cache"
cp "$ROOT/shell/config/defaults.json" "$AUDIT_TMP/config/swiftshell/settings.json"
export XDG_CONFIG_HOME="$AUDIT_TMP/config" XDG_STATE_HOME="$AUDIT_TMP/state" XDG_CACHE_HOME="$AUDIT_TMP/cache"
qs -p "$AUDIT_TMP/shell/SaveAudit.qml" >"$AUDIT_TMP/audit.log" 2>&1
rg -q 'Settings save cycle: duplicate and rapid writes passed' "$AUDIT_TMP/audit.log" || { cat "$AUDIT_TMP/audit.log"; exit 1; }
python3 - "$AUDIT_TMP/config/swiftshell/settings.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    settings = json.load(stream)
assert abs(settings['bar']['surfaceOpacity'] - .39) < .00001
assert settings['clock']['use24Hour'] is False
PY
printf '%s\n' 'Native settings: duplicate writes, rapid edits, and final disk readback passed.'
python3 - "$AUDIT_TMP/config/swiftshell/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as stream:
    settings = json.load(stream)
settings['version'] = 2
with open(path, 'w') as stream:
    json.dump(settings, stream)
PY
qs -p "$AUDIT_TMP/shell/SaveAudit.qml" >"$AUDIT_TMP/migration.log" 2>&1
rg -q 'Settings save cycle: duplicate and rapid writes passed' "$AUDIT_TMP/migration.log" || { cat "$AUDIT_TMP/migration.log"; exit 1; }
python3 - "$AUDIT_TMP/config/swiftshell/settings.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    settings = json.load(stream)
with open(sys.argv[1] + '.bak-swiftshell') as stream:
    backup = json.load(stream)
assert settings['version'] == 3 and backup['version'] == 2
assert abs(settings['bar']['surfaceOpacity'] - .39) < .00001
assert settings['clock']['use24Hour'] is False
PY
printf '%s\n' 'Native settings: backed-up v2 migration and subsequent duplicate/rapid saves passed.'
