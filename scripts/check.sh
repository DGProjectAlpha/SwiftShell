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
"$NODE" "$ROOT/tests/workspaces.test.js"
"$NODE" "$ROOT/tests/displays.test.js"
"$NODE" "$ROOT/tests/bar-surfaces.test.js"
"$NODE" "$ROOT/tests/bar-layouts.test.js"
"$NODE" "$ROOT/tests/bar-ergonomics.test.js"
"$NODE" "$ROOT/tests/clock-tools.test.js"
"$NODE" "$ROOT/tests/notifications.test.js"
"$NODE" "$ROOT/tests/overview.test.js"
"$NODE" "$ROOT/tests/spotlight-providers.test.js"
"$NODE" "$ROOT/tests/desktop-tools.test.js"
python3 "$ROOT/tests/test_desktoptools.py"
python3 "$ROOT/tests/test_terminallaunch.py"
python3 "$ROOT/tests/test_performancectl.py"
python3 "$ROOT/tests/test_screenshotctl.py"
python3 "$ROOT/tests/test_clipboardwindow.py"
python3 "$ROOT/tests/test_networkctl.py"
python3 "$ROOT/tests/test_powerprofiles.py"
python3 "$ROOT/tests/test_settingswrite.py"
python3 "$ROOT/tests/test_appearancectl.py"
python3 "$ROOT/tests/test_wallpaper_sample.py"
python3 "$ROOT/tests/test_defaultapps.py"
python3 "$ROOT/tests/test_shortcutsctl.py"
python3 "$ROOT/tests/test_overviewctl.py"
python3 "$ROOT/tests/test_displays.py"
python3 "$ROOT/tests/test_windowctl.py"
"$NODE" "$ROOT/tests/settings_files.test.js"
sh "$ROOT/tests/install_flow.sh"

QMLTESTRUNNER=""
# Prefer Qt 6 explicitly: /usr/bin/qmltestrunner may belong to Qt 5 on CachyOS.
for candidate in /usr/lib/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qml6testrunner qml6testrunner qmltestrunner; do
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
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_displays.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_keyed_models.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_color_picker.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_clock_tools.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_clock_context.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_notifications.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_overview.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_spotlight.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_desktop_tools.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_performance.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_clipboard.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_screenshots.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_workspace_drag.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_settings_responsive.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_appearance_queue.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_network_devices.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_power_profiles.qml" -platform offscreen
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_tray.qml" -platform offscreen

DIALOGS_AVAILABLE=0
FOLDER_MODEL_AVAILABLE=0
OLD_IFS=$IFS
IFS=:
for import_root in $IMPORTS; do
    if [ -f "$import_root/QtQuick/Dialogs/qmldir" ]; then
        DIALOGS_AVAILABLE=1
    fi
    if [ -f "$import_root/Qt/labs/folderlistmodel/qmldir" ]; then
        FOLDER_MODEL_AVAILABLE=1
    fi
done
IFS=$OLD_IFS

if [ "$DIALOGS_AVAILABLE" = 1 ]; then
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_dialogs.qml" -platform offscreen
else
    echo "SwiftShell: QtQuick.Dialogs is unavailable; the explicit path-entry fallback was tested, but native image selection was not compiled." >&2
fi

if [ "$DIALOGS_AVAILABLE" = 1 ] && [ "$FOLDER_MODEL_AVAILABLE" = 1 ]; then
    QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QMLTESTRUNNER" -input "$ROOT/tests/qml/tst_wallpaper_picker.qml" -platform offscreen
else
    echo "SwiftShell: native slideshow folder selection was not compiled because QtQuick.Dialogs or Qt.labs.folderlistmodel is unavailable." >&2
fi
