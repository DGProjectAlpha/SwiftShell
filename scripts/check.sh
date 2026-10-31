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
"$NODE" "$ROOT/tests/settings_files.test.js"
sh "$ROOT/tests/install_flow.sh"

QMLTESTRUNNER=""
for candidate in qmltestrunner qml6testrunner; do
    if command -v "$candidate" >/dev/null 2>&1; then
        QMLTESTRUNNER=$(command -v "$candidate")
        break
    fi
done
if [ -z "$QMLTESTRUNNER" ]; then
    for candidate in /usr/lib/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qml6testrunner; do
        if [ -x "$candidate" ]; then
            QMLTESTRUNNER=$candidate
            break
        fi
    done
fi

if [ -z "$QMLTESTRUNNER" ]; then
    echo "SwiftShell: qmltestrunner was not found; QML instantiation tests were not run" >&2
    echo "SwiftShell: install Qt 6 declarative test tools before treating a startup as checked" >&2
    echo "SwiftShell: Debian/Ubuntu package qt6-declarative-dev-tools; Arch/CachyOS package qt6-declarative" >&2
    exit 1
fi

IMPORTS="$ROOT/tests/stubs"
if [ -d /usr/lib/x86_64-linux-gnu/qt6/qml ]; then
    IMPORTS="$IMPORTS:/usr/lib/x86_64-linux-gnu/qt6/qml"
fi
if [ -d /usr/lib/qt6/qml ]; then
    IMPORTS="$IMPORTS:/usr/lib/qt6/qml"
fi
if [ -n "${QML_IMPORT_PATH:-}" ]; then
    IMPORTS="$IMPORTS:$QML_IMPORT_PATH"
fi
export QML_IMPORT_PATH="$IMPORTS"

QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_implicit_size.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_shell_load.qml" -platform offscreen
