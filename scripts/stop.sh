#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CONFIG="$ROOT/shell"
# shellcheck source=lib/common.sh
. "$ROOT/scripts/lib/common.sh"

if command -v qs >/dev/null 2>&1; then
    QS=qs
elif command -v quickshell >/dev/null 2>&1; then
    QS=quickshell
else
    echo "SwiftShell: qs is not installed, so there is no SwiftShell instance to stop." >&2
    exit 0
fi

echo "SwiftShell: stopping the prototype launched from this checkout"
if swiftshell_qs_kill_config "$QS" "$CONFIG"; then
    exit 0
fi

echo "SwiftShell: qs kill did not confirm a stopped instance." >&2
echo "Inspect running shells with: qs list --all" >&2
echo "Stop one instance with: qs kill --id <instance-id>" >&2
echo "Do not stop every quickshell process; Noctalia is one of them." >&2
exit 1
