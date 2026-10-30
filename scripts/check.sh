#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
python3 "$ROOT/tests/static_check.py"

if command -v node >/dev/null 2>&1; then
    NODE=node
else
    echo "SwiftShell: node was not found; logic tests were not run" >&2
    exit 1
fi

"$NODE" "$ROOT/tests/logic.test.js"
