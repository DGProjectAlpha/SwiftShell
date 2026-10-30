# Testing

The cloud environment used to add this prototype has no Hyprland session, no monitors, and no Noctalia installation. Checks here cover logic, source structure, and the installer in a temporary home directory. They do not show pixels.

## Commands

From the repository root:

```sh
python3 tests/static_check.py
node tests/logic.test.js
sh tests/install_flow.sh
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml/tst_implicit_size.qml -platform offscreen
```

`scripts/check.sh` also runs `tests/qml/tst_shell_load.qml`. That file needs `tests/stubs` on `QML_IMPORT_PATH` ahead of the system Qt Quick directory (`/usr/lib/qt6/qml` on Arch and CachyOS, `/usr/lib/x86_64-linux-gnu/qt6/qml` on Debian and Ubuntu). The script adds both when the directory exists.

Or all of the above, including the shell-load test:

```sh
scripts/check.sh
```

`scripts/check.sh` expects `node`, `python3`, and `qmltestrunner` (or `qml6testrunner`) on `PATH`. The runner is also found at `/usr/lib/qt6/bin/qmltestrunner`. Debian and Ubuntu package that binary in `qt6-declarative-dev-tools`. Arch and CachyOS package it in `qt6-declarative`. The script exits if the runner is missing. That run instantiates Qt objects. It does not start Quickshell.

## Pull and test on CachyOS

These commands use the checkout as the Quickshell config. They do not install over Noctalia, and they do not edit Hyprland.

```sh
git fetch origin
git checkout cursor/qml-implicit-size-915d
git pull origin cursor/qml-implicit-size-915d
```

After the branch is merged, `git checkout main` and `git pull origin main` is the same tree.

Stop a previous copy of this checkout, then start it:

```sh
scripts/stop.sh
scripts/launch.sh
```

`scripts/launch.sh` runs `qs --path` on this checkout's `shell/` directory with `--no-duplicate`. Leave that process in the foreground. A startup that gets past the old property errors prints:

```text
SwiftShell: M1 prototype started
SwiftShell: calendar and control center panels are available
```

Stop it with `scripts/stop.sh`. If that cannot see the instance, run `qs list --all` and then `qs kill --id` with the instance id whose config path is this checkout. Do not kill every `qs` process. Noctalia is one of them.

The optional Qt check, which still does not start the shell:

```sh
scripts/check.sh
```

On CachyOS that needs `qmltestrunner` from `qt6-declarative` in addition to the `quickshell` package used by `scripts/launch.sh`. A passing `scripts/check.sh` is not a Hyprland startup. The startup test is `scripts/launch.sh`.

To try the installed copy instead of the checkout, run `./install.sh` again after the pull and then `swiftshell start`. That updates SwiftShell's own files and leaves an existing settings file in place. It does not replace another shell.

## What the checks cover

`tests/logic.test.js` exercises the plain JavaScript used by the QML:

- 12-hour and 24-hour formatting, including midnight and an invalid date
- connector matching for `HDMI-A-1`
- workspace fallback to 4, 5, and 6
- active highlighting only when the workspace is on the bar's monitor
- focused-title selection
- settings validation, repair, and the defaults file
- palette contrast for the dark and light scrims, including the unsampled wallpaper tint
- byte-to-unit color conversion, separate alpha, and the light gradient at 1.0 rather than 255
- motion durations and reduced motion
- calendar month grids, locale week start, ISO week numbers, leap years, year wrap, and a single today cell
- calendar width in logical pixels
- popup placement in logical pixels for 1920×1080 at scale 1.5 and 2560×1440 at scale 1.0
- rejection of a zero-size item map
- popup phases, including Escape, outside click, repeated toggles, panel switches, interrupted fades, monitor loss, and process stop
- one open popover id at a time
- audio volume clamping, unmute behavior, output labels, and refusal to write a different or missing sink
- the stored blur preference remaining a scrim, not an effect

`tests/static_check.py` checks that the QML files exist, local imports resolve, braces and parentheses balance, and the tree does not spawn `hyprctl`, a `Timer`, or a `Process`. It rejects a QML object nested directly in `QtObject`, which has no default property, including through a component whose root type is `QtObject`. Property values such as `property Item child: Item {}` are allowed. It rejects assignment to a read-only property on the Qt 6.4 types used here, including `implicitWidth` and `implicitHeight` on `Column`, `Row`, `Grid`, `Flow`, `Loader`, `Text`, `TextInput`, `TextEdit`, `Image`, `BorderImage`, and `AnimatedImage`, and the same properties when a project component's root type is one of those. It also rejects other read-only properties those types publish, such as `Loader.status`, `Text.contentWidth`, and `MouseArea.pressed`. Reading `implicitWidth` in another binding is allowed. Grouped writes such as `anchors.top` and `border.width`, and signal handlers such as `onImplicitWidthChanged`, are allowed. `Item`, `Rectangle`, `MouseArea`, `FocusScope`, and the layout types can still be given an implicit size. When `QtQuick/plugins.qmltypes` is installed, the check also requires that file to mark `QQuickImplicitSizeItem.implicitWidth` read-only and `QQuickItem.implicitWidth` writable. It also checks the transparent color, 28px token, HDMI-A-1 default, shell id, `Scope` bar host, `Singleton` service roots, the transparent popup surface, and that wallpaper sampling is not claimed. Shell scripts are scanned for edits to Hyprland config, service units, and package installation outside the explicit Arch dependency path.

`tests/qml/tst_implicit_size.qml` instantiates those Qt types with `qmltestrunner`. It expects the same read-only error Quickshell reported for the calendar column, the control-center column, and a `Loader`, and it checks that an `Item` wrapper keeps a 210px calendar-shaped panel and a 248×40 control-shaped panel.

`tests/qml/tst_shell_load.qml` loads the shell documents with `tests/stubs/` standing in for Quickshell. The stubs are not Quickshell. Under that loader, the calendar, control center, audio section, popup host, and bar widgets instantiate. The calendar grid rows are 28px tall, the control center is 248px wide, and the volume slider inside a 248px column is 248×28. The popup host grows when the calendar opens and again when the control center replaces it. `shell.qml` still stops at `WlrLayershell.namespace` because that attached object is not something a QML file can imitate. The error from that line is not a read-only property assignment. This does not load Quickshell and it does not show a window on a monitor.

`tests/install_flow.sh` runs `./install.sh`, activation, deactivation, and uninstallation in a temporary `HOME` with stub `qs` and `Hyprland` commands. It checks that a second install keeps settings, that occupied config names and foreign launchers are refused, and that Hyprland and other shell files in that temporary home stay unchanged. Stop is checked twice: a stub whose help lists `--any-display` must receive that flag, and a stub that matches Quickshell 0.2.0 must be stopped with `kill --path` alone. It does not install packages and it does not open a Wayland session.

## What was run for the M2 stability change

On 30 Oct 2026, about 3:03 PM America/New_York, in the cloud workspace, with no Hyprland session:

```text
python3 tests/static_check.py
node tests/logic.test.js
sh tests/install_flow.sh
/usr/lib/qt6/bin/qmllint --ignore-settings -I /usr/lib/x86_64-linux-gnu/qt6/qml shell/**/*.qml
```

Node was v22.23.4 and Python was 3.12.3. Static checks passed for 20 QML files, including the nesting fixtures and the real `Scope` / `Singleton` roots. Logic tests passed, including color units, calendar leap years, both reference screen sizes, popup phase interruptions, and audio sink identity. Install tests passed, including the Quickshell 0.2 stop path that must not pass `--any-display`, and a failed `qs kill` that must still print the miss warning.

`qmllint` 6.4.2 from Ubuntu `qt6-declarative-dev-tools` was run after installing `qml6-module-qtquick`, `qml6-module-qtquick-layouts`, `qml6-module-qtqml`, and `qml6-module-qtcore`. With that import path, Qt Quick itself resolves. Quickshell is not installed, so `PanelWindow`, `PopupWindow`, `HyprlandFocusGrab`, `Pipewire`, and the other Quickshell types stay unresolved. Those warnings do not show whether Quickshell would load the files. The same run caught `Accessible.value`, which Qt 6.4's attached `Accessible` type does not have. That binding was removed. `Loader.item` is typed as `QObject` in the 6.4 qmltypes, so `item.implicitHeight` is reported even though the loaded object is an `Item` at runtime. `jsroot.qmltypes` was not in the installed set. `qs` is not installed. The shell was not launched. Blur, focus grab, fractional-scale placement, PipeWire volume, and panel animation were not seen on a compositor.

## What was run for the implicit-size fix

On 30 Oct 2026, at 6:39 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

That script ran `python3 tests/static_check.py`, `node tests/logic.test.js`, `sh tests/install_flow.sh`, and `qmltestrunner` 6.4.2 on `tests/qml/tst_implicit_size.qml` and `tests/qml/tst_shell_load.qml` with `QT_QPA_PLATFORM=offscreen`. Static checks passed for 20 QML files, including the read-only property fixtures and the `plugins.qmltypes` agreement for `QQuickImplicitSizeItem`. Logic tests passed. Install tests passed, 12 cases. Both QML suites passed, 6 tests each. The shell-load suite instantiated the calendar, control center, audio slider, popup surface, and popup host. `shell.qml` under the same stubs stopped at `BarWindow.qml:27` (`WlrLayershell` attached object). `qmllint` 6.4.2 was run again and still does not report the read-only implicit-size override; unresolved Quickshell types remain when the real module is absent. Quickshell was not started. The panels were not seen on a compositor.

## What these checks do not prove

- The bar is transparent on a real wallpaper.
- Text remains readable at 1.0 and 1.5 scale.
- `HDMI-A-1` matches the Qt screen name on the target machine.
- Hyprland IPC accepts `workspace 4` through the installed Quickshell build.
- Hotplug destroys and recreates the window.
- `reserveSpace: false` leaves Noctalia's exclusive zone unchanged.
- The shell exits without taking Hyprland down.
- `./install.sh` behaves the same way on a real Arch or CachyOS account.
- Qt accepts `Scope`, `Singleton`, `PopupWindow`, and `HyprlandFocusGrab` as used here. That follows the Quickshell 0.2 type pages, and it was not loaded with `qs`.
- The popup stays inside the HDMI-A-1 output at scale 1.5, and the scrim stays readable on the real wallpaper. Blur is unsupported on Quickshell 0.2.0 and was not observed.
- PipeWire reports the default sink and accepts volume and mute writes.
- Escape and an outside click close the panel without leaving a focus grab behind.
- The optional top gradient remains inside the bar and does not steal clicks from windows below it.
- `WlrLayershell.namespace` parses on the installed Quickshell. The 0.2 page documents that property and says it must be set before the layer surface connects.
- `qs kill --help` on the installed binary matches the 0.2.0 parser or the later `--any-display` flag. The probe was tested with stubs only.
- Quickshell loaded `shell.qml`. The instantiation test uses QML stand-ins. `WlrLayershell.namespace` still stops that stand-in at `BarWindow.qml` because an attached object cannot be declared in QML. On the CachyOS run, startup had already passed that line and failed later on read-only implicit size.

Those need a Hyprland session on the target machine. Do not mark them passed from a cloud log.

## Install, launch, and stop

Development launch from a checkout is `scripts/launch.sh` and `scripts/stop.sh`. The distributable install path is `docs/install.md`.

1. Install Quickshell with the Hyprland module using the distro package, or pass `--install-deps` to `./install.sh` on an Arch-based system.
2. Leave the existing shell and Hyprland config in place.
3. From this checkout, `scripts/launch.sh` runs the source tree. `./install.sh` installs a separate copy.
4. The launcher creates `$XDG_CONFIG_HOME/swiftshell` (or `~/.config/swiftshell`) and copies default settings only if that file is absent.
5. Quickshell is started with `qs --path` and `--no-duplicate`. Ctrl-C stops a foreground development launch.
6. `scripts/stop.sh` stops the source-tree path. `swiftshell stop` stops the installed path.

If stop cannot find the instance:

```sh
qs list --all
qs kill --id <instance-id>
```

Read the instance id from `qs list` before killing anything. A blanket process kill can stop the shell that was already running.

To reserve space for maximized windows on HDMI-A-1, set `bar.reserveSpace` to `true` in the settings file and restart the prototype. Leave it `false` while another shell is also drawing on that output.

Clock format is `clock.use24Hour` in the same file. `true` prints `09:04`. `false` prints `9:04 AM`.

## Recovery

Stopping SwiftShell releases its layer surface. These milestones do not write Hyprland or another shell's files, so there is no compositor config to roll back. If a bar remains after stop, run `qs list --all` and kill only the instance whose config path is this checkout's `shell/shell.qml` or the installed `swiftshell/app` directory.
