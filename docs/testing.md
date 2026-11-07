# Testing

Automated logic, QML and installer checks are separate from native desktop acceptance. Dated local evidence below records actual Quickshell/Hyprland tests; older cloud-only entries remain historical and do not imply hardware coverage.

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

`scripts/check.sh` expects `node`, `python3`, and `qmltestrunner` (or `qml6testrunner`) on `PATH`, plus the QtTest QML module imported by the test documents. The runner is also found at `/usr/lib/qt6/bin/qmltestrunner`. Debian and Ubuntu package the binary in `qt6-declarative-dev-tools` and the QML module in `qml6-module-qttest`. Arch and CachyOS package both in `qt6-declarative`. The script exits if the runner or required test module is missing. That run instantiates Qt objects. It does not start Quickshell.

The mock QML gate now rejects every component error except a short path-specific list for unavailable C++ attached Quickshell types and optional modules. When `QtQuick.Dialogs` is installed, `tst_dialogs.qml` requires `ImageDialog.qml` to compile. When it is absent, the check prints an explicit diagnostic and exercises the path-entry fallback; it does not silently claim native image selection was compiled. GitHub CI installs the Qt Quick, Window, Layouts, WorkerScript, Core, Dialogs, and QtTest runtime modules explicitly; Window is required by QtTest's `TestCase.qml` on Ubuntu.

The folder-picker gate additionally requires `Qt.labs.folderlistmodel`; CI installs its runtime module and compiles both picker components. This workspace lacks Dialogs and folderlistmodel, so opening a native dialog, enumerating permissions, and reacting to removed files are **NOT RUN** here.

The installer suite also constructs a temporary system-package layout. It verifies that status, start, and activation use that shared app root, the desktop entry uses the system command, uninstall removes only per-user activation state, and settings purge cannot remove package-owned files. It does not run `makepkg`, pacman, or an installed Arch package.

## Release-candidate wallpaper checks

`scripts/check.sh` passed after the slideshow and contrast repair. The logic suite changes interval, transition duration, ordering, and image lists without replacing a still-valid current item; disables motion during a transition; skips a failed current image; verifies URL encoding; applies Cover and Contain sampling to synthetic pixels; rejects an oversized PNG before inflate; and stops a compressed-output expansion at its declared budget. The QML gate compiled the changed documents with stubs. A real crossfade, mixed-refresh outputs, hotplug during a fade, Qt texture reuse, and automatic contrast on DP-1/HDMI-A-1 are **NOT RUN**.

## Release-candidate notification checks

`scripts/check.sh` passed after the native-lifecycle repair. Logic coverage includes banner/history/drop dispositions, in-place id replacement, a replacement becoming hidden, de-duplicated quiet history, DND with critical bypass, bounded bursts, and native dismiss/expire stand-ins. The strict QML gate compiles the host up to its intentionally unstubbed layer-shell attachment. Claiming `org.freedesktop.Notifications`, observing native replacement signals, action delivery, release behavior, and focused-output placement are **NOT RUN** because this workspace has no Quickshell session or user D-Bus notification traffic.

## Pull and test on CachyOS

These commands use the checkout as the Quickshell config. They do not install over Noctalia, and they do not edit Hyprland.

```sh
git fetch origin
git checkout cursor/m2-runtime-915d
git pull origin cursor/m2-runtime-915d
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
SwiftShell: calendar, control center, and launcher are available
```

Stop it with `scripts/stop.sh`. If that cannot see the instance, run `qs list --all` and then `qs kill --id` with the instance id whose config path is this checkout. Do not kill every `qs` process. Noctalia is the separate `noctalia` executable, not one of those `qs` instances. Do not stop it from this repository.

The optional Qt check, which still does not start the shell:

```sh
scripts/check.sh
```

On CachyOS that needs `qmltestrunner` from `qt6-declarative` in addition to the `quickshell` package used by `scripts/launch.sh`. A passing `scripts/check.sh` is not a Hyprland startup. The startup test is `scripts/launch.sh`.

To try the installed copy instead of the checkout, run `./install.sh` again after the pull and then `swiftshell start`. That updates SwiftShell's own files and leaves an existing settings file in place. It does not replace another shell.

## What the checks cover

`tests/logic.test.js` exercises the plain JavaScript used by the QML:

- 12-hour and 24-hour formatting, including midnight and an invalid date
- connector matching for `HDMI-A-1`, description matching, automatic focus, and fallback when a saved monitor is gone
- empty workspace ids staying empty, live ids per monitor, and explicit ids that still include a missing workspace
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
- centered Spotlight frames for 2560×1440, 1920×1080, and a 1280×720 logical size, including a list tall enough to clamp
- launcher request tokens that ignore the first value, then open, close, and open again
- search, theme-icon lookup, Tab-style selection, and a cleared keyboard grab after close

`tests/static_check.py` checks that the QML files exist, local imports resolve, braces and parentheses balance, and the tree does not spawn `hyprctl`, a `Timer`, or a `Process`. It rejects a QML object nested directly in `QtObject`, which has no default property, including through a component whose root type is `QtObject`. Property values such as `property Item child: Item {}` are allowed. It rejects assignment to a read-only property on the Qt 6.4 types used here, including `implicitWidth` and `implicitHeight` on `Column`, `Row`, `Grid`, `Flow`, `Loader`, `Text`, `TextInput`, `TextEdit`, `Image`, `BorderImage`, and `AnimatedImage`, and the same properties when a project component's root type is one of those. It also rejects other read-only properties those types publish, such as `Loader.status`, `Text.contentWidth`, and `MouseArea.pressed`. Reading `implicitWidth` in another binding is allowed. Grouped writes such as `anchors.top` and `border.width`, and signal handlers such as `onImplicitWidthChanged`, are allowed. `Item`, `Rectangle`, `MouseArea`, `FocusScope`, and the layout types can still be given an implicit size. When `QtQuick/plugins.qmltypes` is installed, the check also requires that file to mark `QQuickImplicitSizeItem.implicitWidth` read-only and `QQuickItem.implicitWidth` writable. It also checks the transparent color, 28px token, empty monitor and workspace defaults, shell id, `Scope` bar host, `Singleton` service roots, the transparent popup surface, and that wallpaper sampling is not claimed. It fails when a shell file uses a project QML type that its imports do not provide. The fixture is `BarLabel` without `import "../components"`, which is the startup error `BarLabel is not a type`. Shell scripts are scanned for edits to Hyprland config, service units, and package installation outside the explicit Arch dependency path.

`tests/qml/tst_implicit_size.qml` instantiates those Qt types with `qmltestrunner`. It expects the same read-only error Quickshell reported for the calendar column, the control-center column, and a `Loader`, and it checks that an `Item` wrapper keeps a 210px calendar-shaped panel and a 248×40 control-shaped panel.

`tests/qml/tst_shell_load.qml` loads the shell documents with `tests/stubs/` standing in for Quickshell. The stubs are not Quickshell. Under that loader, the calendar, control center, audio section, popup host, and bar widgets instantiate. The calendar grid rows are 28px tall, the control center is 248px wide, and the volume slider inside a 248px column is 248×28. The popup host grows when the calendar opens and again when the control center replaces it. `shell.qml`, `BarHost.qml`, `BarWindow.qml`, `LauncherWindow.qml`, and `LauncherModel.qml` are compiled too. The test fails if any of those error strings contain `BarLabel`. `shell.qml` and `BarWindow.qml` can still stop at `WlrLayershell.namespace` because that attached object is not something a QML file can imitate. This does not load Quickshell and it does not show a window on a monitor.

`tests/install_flow.sh` runs `./install.sh`, activation, deactivation, and uninstallation in a temporary `HOME` with stub `qs` and `Hyprland` commands. It checks that a second install keeps settings, that occupied config names and foreign launchers are refused, and that Hyprland and other shell files in that temporary home stay unchanged. Stop is checked twice: a stub whose help lists `--any-display` must receive that flag, and a stub that matches Quickshell 0.2.0 must be stopped with `kill --path` alone. The `--install-deps --yes` case uses a PATH that contains only symlinked host tools plus stub `sudo` and `pacman`. It does not include `/usr/bin`, `/bin`, `qs`, `Hyprland`, or `hyprctl`. A decoy `qs` sits beside that PATH and must not run. A second case puts good `qs` and `Hyprland` stubs on that same isolated PATH and requires that `sudo` is not called. A sudo stub that exits 99 must stop a `--strict` install before files are written, and a non-strict install must keep the files and print the failure. The suite does not install packages and it does not open a Wayland session.

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

That script ran `python3 tests/static_check.py`, `node tests/logic.test.js`, `sh tests/install_flow.sh`, and `qmltestrunner` 6.4.2 on `tests/qml/tst_implicit_size.qml` and `tests/qml/tst_shell_load.qml` with `QT_QPA_PLATFORM=offscreen`. Static checks passed for 20 QML files, including the read-only property fixtures and the `plugins.qmltypes` agreement for `QQuickImplicitSizeItem`. Logic tests passed. Install tests passed, 12 cases. Both QML suites passed, 6 tests each. The shell-load suite instantiated the calendar, control center, audio slider, popup surface, and popup host. `shell.qml` under the same stubs stopped at `BarWindow.qml` (`WlrLayershell` attached object). `qmllint` 6.4.2 was run again and still does not report the read-only implicit-size override; unresolved Quickshell types remain when the real module is absent. Quickshell was not started. The panels were not seen on a compositor.

## What was run for the M2 runtime stabilization

On 30 Oct 2026, at 7:14 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 20 QML files. `node tests/logic.test.js` passed, including the Lua dispatch expression, the QML list-like workspace ids, the single exclusion property, and the popup focus order. `sh tests/install_flow.sh` passed 14 cases. The missing-deps case requested `sudo pacman -S` for `quickshell` and `hyprland` without `/usr/bin` on `PATH`. The present-deps case did not call sudo. The sudo-exit-99 case refused a strict install and continued a non-strict install. `qmltestrunner` 6.4.2 passed `tst_implicit_size.qml` and `tst_shell_load.qml`, 6 tests each, with `QT_QPA_PLATFORM=offscreen`. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. That warning is from the offscreen Qt platform, not from the shell. Quickshell was not started. Workspace clicks, the binding loop, the exclusive zone, and the text-input line were not observed on a compositor.

## What was run for the M3 launcher

On 30 Oct 2026, at 7:23 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 22 QML files. Logic tests passed. The run printed `launcher rank 400 apps: 1.96 ms`. Install tests passed, 15 cases, including a launcher request that writes the state file and leaves the temporary Hyprland binds file unchanged. `qmltestrunner` 6.4.2 passed both QML suites, 6 tests each. The shell-load suite still uses Quickshell stubs. It is not a Quickshell integration test. No desktop entry was executed. `loginctl` was not executed. The launcher window was not shown.

## What was run for M3 stabilization

On 30 Oct 2026, at 8:08 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 22 QML files, including the `BarLabel` import fixture. Logic tests passed, including a delayed empty desktop-entry model, Dolphin and Helium desktop text, search past the 12-row empty grid, icon-theme lookup, reservation toggling, and the launcher input plan. The run printed `launcher rank 400 apps: 2.45 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed for `tst_implicit_size.qml` and Totals: 7 passed for `tst_shell_load.qml`. The added shell-load case compiles `BarWindow.qml` and fails if the error text contains `BarLabel`. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. That warning is from the offscreen Qt platform. The shell-load suite uses Quickshell stubs. It did not start `qs`, execute a desktop entry, run `loginctl`, or show the launcher.

## What was run for M3.2

On 30 Oct 2026, at 8:31 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 22 QML files. Logic tests passed, including focused-monitor selection, a disconnected saved monitor, live workspace ids, explicit ids that still include a missing workspace, centered frames for 2560×1440, 1920×1080, and 1280×720, repeated launcher request tokens, Dolphin search, icon lookup, Tab-style selection, and a cleared keyboard grab. The run printed `launcher rank 400 apps: 2.33 ms`. Install tests passed, 15 cases, including a launcher request that leaves the temporary Hyprland binds file unchanged. `qmltestrunner` 6.4.2 reported Totals: 6 passed for `tst_implicit_size.qml` and Totals: 7 passed for `tst_shell_load.qml`. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. That warning is from the offscreen Qt platform. The shell-load suite uses Quickshell stubs. It did not start `qs`, show Spotlight, launch an application, or press Super+Space.

## What was run for M4.0

On 30 Oct 2026, at 8:55 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 27 QML files. Logic tests passed, including version 1 migration, a refused invalid file, unknown keys kept by `migrationDecision`, window size clamping, and a settings session that stays one instance. Blur stays unavailable. The run printed `launcher rank 400 apps: 3.15 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed for `tst_implicit_size.qml` and Totals: 8 passed for `tst_shell_load.qml`. The added case compiles the settings window and the Appearance page against the Quickshell stub and checks that the page names the translucent scrim. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. That warning is from the offscreen Qt platform. The shell-load suite did not start `qs`, show the settings window, move it, or resize it.

## What was run for M4.1

On 30 Oct 2026, at 9:02 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 27 QML files. Logic tests passed, including settings search, density rounding, appearance undo, and reset. The run printed `launcher rank 400 apps: 4.66 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed for `tst_implicit_size.qml` and Totals: 8 passed for `tst_shell_load.qml`. The settings page case checks that an opacity query shows the opacity row and hides the blur note. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. That warning is from the offscreen Qt platform. The run did not show the window or scroll it.

## What was run for M4.2

On 30 Oct 2026, at 9:10 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 28 QML files. Logic tests passed, including bar heights 22, 28, and 52, derived font and icon size, module hide, and reorder. The run printed `launcher rank 400 apps: 2.12 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. The run did not draw the bar or measure the reserved strip.

## What was run for bar screens, audio tracking, and the package file list

On 30 Oct 2026, at 11:05 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files, including the package file list. Logic tests passed for `focused`, `primary`, and `all` bar placement, and for a tray menu point. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. No bar moved between monitors, no stream volume was written, and the package was not built.

## What was run for notification lifetime

On 30 Oct 2026, at 11:00 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. The notification host is allowed one non-repeating timer. Logic tests passed, including `expireTimeout` 0, a five-second default, and `dismiss` / `expire` calls on a stand-in object. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The notification server was not created and no other owner was contacted.

## What was run for the theme token repair

On 30 Oct 2026, at 10:57 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files and rejected unknown `Theme` names. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The shell-load case creates the battery, media, and tray modules with empty services and again with a 42% battery, a playing player, and one tray item. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. The modules were not drawn on a monitor.

## What was run for the settings backup repair

On 30 Oct 2026, at 10:55 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed, including an exact v1 backup string, a refusal to replace a usable backup, and a refusal to migrate malformed JSON. `tests/settings_files.test.js` wrote those cases under a temporary directory and read the bytes back. Install tests passed, 16 cases. One case restores a JSON backup, unwraps a `document` string without printing it, and leaves settings in place when the backup is not JSON. `launcher rank 400 apps: 1.26 ms`. `launcher rank 1000 apps: 1.73 ms`. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. Quickshell itself did not load the settings file.

## What was run for M8.2

On 30 Oct 2026, at 10:26 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed. `launcher rank 400 apps: 1.12 ms`. `launcher rank 1000 apps: 1.55 ms`. Install tests passed, 16 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. This pass adds the alpha notes. It does not mark any hardware row as passed. The product is not stable.

## What was run for M8.1

On 30 Oct 2026, at 10:25 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed. `launcher rank 400 apps: 1.28 ms`. `launcher rank 1000 apps: 1.68 ms`. Install tests passed, 16 cases. The new case installs into a temporary home, runs `swiftshell doctor`, and checks that a settings body is not printed, that a decoy compositor command is not run, and that the Hyprland and Noctalia decoy files are unchanged. `rollback-settings` restores only the SwiftShell backup. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. Doctor was not run on a Hyprland session.

## What was run for M7.2

On 30 Oct 2026, at 10:23 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed, including a 100-notification burst that stays at 4 banners and 40 history rows, a 1000-app rank, and a search view capped at 24 rows. High contrast stores `high` and still loses to a manual hex and to automatic png text. `launcher rank 400 apps: 1.16 ms`. `launcher rank 1000 apps: 1.62 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The appearance page case finds the High contrast label. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No CPU, GPU, suspend, or hotplug measurement was taken.

## What was run for M7.1

On 30 Oct 2026, at 10:21 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Bounce, elastic, back, and spring animations are rejected. The popover card does not set rectangular clipping. Logic tests passed, including the corner-clip report. `launcher rank 400 apps: 1.15 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The appearance page case checks the scrim sentence and the line that the radius is not a rounded blur mask. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No panel was shown, and no label was measured on a display.

## What was run for M6.2

On 30 Oct 2026, at 9:53 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed, including a hidden application that is dropped even when critical, a quiet application that stays in history unless the notification is critical, and a policy that rejects a path and an unknown value. `launcher rank 400 apps: 1.16 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The notifications page case checks that sounds are not played. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No notification sound was triggered.

## What was run for M6.1

On 30 Oct 2026, at 9:51 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 52 QML files. Logic tests passed, including a notification dropped while ownership is off, a replaced id, a non-critical banner held in history while do not disturb is on, a critical banner that still shows, and a refused ownership value. `launcher rank 400 apps: 1.14 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The notifications page case checks that SwiftShell is not the owner. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. The notification server object was not created. No bus name was claimed.

## What was run for M5.2

On 30 Oct 2026, at 9:46 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 49 QML files. Logic tests passed, including a refused pair of an already paired device, a cancelled pairing, a charging estimate, a discharging device with no estimate, and the sentences that Wi-Fi secrets are not stored and that software dimming is not called hardware brightness. `launcher rank 400 apps: 1.28 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The network page case checks both of those sentences. The Bluetooth page case checks that a scan is not started. The power page case checks the second confirmation. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No adapter, battery, or session action was changed. Bluetooth and UPower were the test stubs.

## What was run for M5.1

On 30 Oct 2026, at 9:44 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 42 QML files. Logic tests passed, including sink and source filtering, a rejected node id, an application stream name, a playing MPRIS player, a tray item that cannot be activated, and an older five-module bar order that gains Media and Tray without an error. `launcher rank 400 apps: 1.17 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The audio page case checks the PipeWire sentence and that a microphone query hides the player row. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No audio device, player, or tray icon was changed. PipeWire, MPRIS, and the tray were the test stubs.

## What was run for M4.7

On 30 Oct 2026, at 9:39 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 37 QML files. Logic tests passed, including Escape cancel, a refused confirm before a key, a duplicate named as already used by Spotlight, and a stored Super+Z that is not installed as a compositor bind. `launcher rank 400 apps: 1.29 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The shortcuts page case checks the sentence that saving does not install the chord. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No bind file was read or written.

## What was run for M4.6

On 30 Oct 2026, at 9:34 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 36 QML files. Logic tests passed, including a 2560×1440 plus 1920×1080 arrangement, a negative coordinate, a portrait preview, snap, overlap, and a refused last-output disable. `launcher rank 400 apps: 1.32 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The displays page case checks the sentence that changes are not sent. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. No display mode was changed.

## What was run for M4.5

On 30 Oct 2026, at 9:30 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 35 QML files. Logic tests passed, including the slideshow states, a shuffle that does not repeat the current image, a png round-trip, the packaged crimson top edge, split-edge scrim, hysteresis from black to white, and a desaturated accent. `launcher rank 400 apps: 1.37 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. The run did not start `qs`, play a crossfade, or sample a jpeg. This Qt build cannot list a folder.

## What was run for M4.4

On 30 Oct 2026, at 9:21 PM America/New_York, in the cloud workspace, with no Hyprland session and no `qs` binary:

```text
scripts/check.sh
```

Exit status 0. Static checks passed for 32 QML files. Logic tests passed, including packaged and rejected wallpaper paths, cover and contain crop rectangles for 2560×1440, 1920×1080, a wide crop, a portrait crop, and an 8K decode cap of 3840. `launcher rank 400 apps: 2.39 ms`. Install tests passed, 15 cases, including a regular-file copy of the crimson PNG. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. The wallpaper page case checks the coexistence sentence and that a cover query hides the path row. `QStandardPaths: XDG_RUNTIME_DIR not set` was printed. The run did not start `qs`, show a background layer, or open a file dialog. `QtQuick.Dialogs` is not installed in this workspace.

## What was run for M4.3

On 30 Oct 2026, at 9:12 PM America/New_York, `scripts/check.sh` exited 0. Static checks passed for 28 QML files. Logic tests passed, including the material report: blur unavailable, fallback scrim, not hardware-verified. `launcher rank 400 apps: 2.08 ms`. Install tests passed, 15 cases. `qmltestrunner` 6.4.2 reported Totals: 6 passed and Totals: 8 passed. No checkerboard screenshot was taken. Hyprland blur rules were not read or written.

## Settings window hardware check

After the M3.2 checks, and only with SwiftShell launched by `scripts/launch.sh`:

1. Copy `~/.config/swiftshell/settings.json` aside if it contains keys that are not in `docs/architecture.md`. A version 1 file is backed up to `settings.json.bak-swiftshell` and rewritten as version 2 on launch. `HDMI-A-1` and workspaces `[4, 5, 6]` are known keys.
2. Open Spotlight, choose Settings, and confirm one normal window appears. Hyprland's own move bind should move it. Resize it from the compositor, close it, and open it again. The size should come back. Escape should close it.
3. Open Settings again from the control center button, and once more from Spotlight while it is already open. There should still be one window.
4. Change dark, light, high contrast, text size, text weight, density, panel opacity, corner radius, shadow, icon scale, motion scale, reduced motion, and the top gradient. The bar, Spotlight, and the settings window should follow without a restart. Restart with `scripts/stop.sh` and `scripts/launch.sh` and confirm the same values. Undo should restore the previous values. Reset should restore the appearance defaults. There is no blur slider. Wallpaper tint should say it is not sampled. Search should hide controls that do not match, and Escape in a filled search field should clear it before the next Escape closes the window.
5. Confirm `~/.config/hypr` and the Noctalia config are unchanged.
6. Open Settings, Top bar. Set the height to 22 and to 52. The text, workspace marks, and reserved strip should follow. Hide Clock and move Search earlier. Restart and confirm the order. Set the height back to 28.
7. Open Settings, Wallpaper. The preview should show the crimson image. Choose a png, or type its path, and confirm Cover crops and Contain shows the whole picture on each output. Point one output at a different file and restart. Remove that file and confirm the crimson image returns. Turn Draw wallpaper off and confirm another wallpaper program is still running. `~/.config/hypr` must stay unchanged.
8. Add two png files to the slideshow, set the fade to 400, and confirm the pictures crossfade and the second one is not the same as the first when shuffle is on. Turn on automatic text on the crimson image and on a white png. Text should be light on the crimson image and dark on the white one. A black-and-white split should show the bar fade. Turn automatic text off and confirm a manual hex color remains. A jpeg should still display and should say it is not sampled.
9. Open Settings, Displays. The rectangles should match the connected outputs, including a portrait or a negative position if one is connected. Dragging should move only the preview. Apply stays unavailable. `~/.config/hypr` must stay unchanged.
10. Open Settings, Shortcuts. Record Super+Z for Settings, press Enter, and confirm the row shows Super+Z after a restart. Press Escape while listening and confirm nothing is stored. Record the same chord on Control center and confirm it is refused. The compositor's own binds, including Super+Space, must be unchanged.
11. Play audio. The control center slider should move the default sink, unmute when raised above zero, and list the microphone when PipeWire has a default source. Start a player and confirm Play, Pause, Next, and Previous match what that player allows. A tray icon should activate on click. With no player and no tray icons, the bar should not grow. `~/.config/hypr` must stay unchanged.
12. Open Settings, Network. It should say the shell does not store Wi-Fi secrets and does not call software dimming hardware brightness. There should be no scan button. Open Bluetooth. Known devices can connect or disconnect. Closing the page must not leave a scan running, because this shell does not start one. On a laptop, the battery percent should match the session. Confirm Lock once and confirm it does not lock; confirm it a second time and it should lock. A desktop with no battery should show Unavailable and the bar should not grow.
13. Open Settings, Notifications. It should say SwiftShell is not the owner. Show preview should show a card labeled Preview and should not post a desktop notification. Own notifications should ask again before anything changes. After the second confirmation, if another program already owns notifications, SwiftShell should say the server was not created and that program should keep receiving them. Release should return ownership. Do not disturb should hide an ordinary banner and still show a critical one. `~/.config/hypr` must stay unchanged.

This checklist is not done in the cloud run.

## What the CachyOS session already showed

With Noctalia stopped, Noctalia itself being the `noctalia` executable:

- SwiftShell loaded and the bar rendered. The calendar and control center opened.
- After the Lua dispatch change, workspace switching worked on the real session, including the click that used to log `return hl.dispatch(workspace 5)` / `')' expected near '5'`. That dispatcher is unchanged here.
- Before that change, startup logged `Binding loop detected for property "targetScreens"` and `settings need attention: bar.workspaceIds` for `[4, 5, 6]`.
- Windows overlapped the bar while `bar.reserveSpace` was false. Whether `true` keeps tiled and maximized windows below the bar is not yet confirmed on that session.
- Popup interaction logged `qt.qpa.wayland.textinput: Trying to disable ... but 0x0 is focused`.
- The launcher opened and did not find installed applications, including Dolphin and Helium. Icons were monograms.
- One startup failed with `BarWindow.qml[126:13]: BarLabel is not a type` because the Search label had no `import "../components"`. That import is on `main`. A local checkout may still have the same line as an uncommitted edit.
- `tests/install_flow.sh` failed with `grep: .../sudo.log: No such file or directory` and `not ok - pacman was not requested` on a machine where `qs` and `Hyprland` were already on `PATH`. The hermetic test was rewritten after that. It has not been re-run on CachyOS.

## Updating a checkout that already contains the BarLabel line

From the SwiftShell checkout:

```sh
git status --short
git diff -- shell/bar/BarWindow.qml
```

If the only local change in that file is `import "../components"`, `main` already has that line. Put the rest of the tree aside only if `git status` shows other edits, then fast-forward:

```sh
git stash push -u -m "local swiftshell edits"
git pull --ff-only origin main
git stash pop
```

When `BarWindow.qml` conflicts, keep a single `import "../components"` directly above `import "../popovers"`. Drop the stash afterward only if `git stash show -p` was that one import and the working tree already has it:

```sh
git stash drop
```

If `git status` was clean except that import, this is enough:

```sh
git checkout -- shell/bar/BarWindow.qml
git pull --ff-only origin main
```

`git pull` does not rewrite `~/.config/swiftshell/settings.json`. A file created from the old defaults still has `"reserveSpace": false`. For standalone use, set that key to `true`. Leave it `false` while Noctalia is also drawing on HDMI-A-1. The running shell reloads the file.

## Hardware retest

From this checkout, after the update above:

```sh
scripts/stop.sh
scripts/launch.sh
```

Leave the process in the foreground. Then:

1. Click workspaces 4, 5, and 6, including one with no windows. The log must not contain `')' expected near`. The focused workspace on HDMI-A-1 should match the indicator. DP-1's workspaces 1–3 should stay on DP-1.
2. Move a window to another HDMI-A-1 workspace and confirm the active mark follows it.
3. Confirm startup does not log `Binding loop detected for property "targetScreens"` or `settings need attention: bar.workspaceIds`.
4. Confirm the log says `bar reserves 28 logical px` when `reserveSpace` is true. Tiled and maximized windows should sit below that strip. Toggle a true fullscreen window and confirm it still covers the bar. Set `reserveSpace` to false, confirm the log says `overlay`, and confirm windows can cover the bar again. Set it back to true without restarting and confirm the strip returns. New settings files default to true. An older file may still say false.
5. Open the calendar, press Escape, open the control center, and click outside it. Confirm the grab is gone and the previously focused application receives the keyboard. Note whether the text-input line is still printed. Do not hide it with a logging rule.
6. Stop with `scripts/stop.sh`. If the instance is not found, `qs list --all` and `qs kill --id` for this checkout only. Start Noctalia the way it was started before. Do not `pkill` Quickshell.

Launcher, after the M2 checks above:

7. Click Search on the bar. The field should take keys immediately. Type `dolphin` and `helium` and confirm both rows appear, with theme icons rather than only a letter, then press Enter on one and confirm that application starts. Press Escape and confirm the previously focused application has the keyboard. Click the dim area around the card and confirm that also closes it.
8. Press Tab and Shift+Tab through a long result list and confirm the selected row stays on screen. Type ordinary letters, including j and k, and confirm they stay in the field. Alt+J and Alt+K may move the selection. Open and close the launcher several times, and unplug HDMI-A-1 while it is open if that is safe to try. It must not remain an invisible full-screen grab.
9. With an empty field, confirm pinned ids from `launcher.pinnedIds` and, after one successful launch, that id on the next empty open. Settings should close Spotlight and open one settings window, not the control center. Lock, Suspend, Restart, and Shut down should do nothing on the first Enter and should ask for confirmation on the second. Do not confirm a power action unless that is intended.
10. Run `scripts/request-launcher.sh` while SwiftShell is running and confirm the launcher opens. Run it again and confirm the launcher closes and the previously focused application has the keyboard. Confirm Super+Space still does what it did before. The handoff is `docs/launcher-shortcut.md`. Do not apply it as part of this check unless you have made the backup described there.
11. Leave `~/.config/swiftshell/settings.json` in place. If it names `HDMI-A-1` and workspaces 4–6, the bar should stay on that output with those indicators. Focus a window on DP-1 and click Search. The card should be centered on DP-1. Focus HDMI-A-1 and request the launcher again. The card should be centered on HDMI-A-1. Scroll a long result list and confirm the search field stays on screen. Unplug a monitor only if that is safe, and confirm no full-screen grab remains.

`scripts/check.sh` on CachyOS needs `qmltestrunner` from `qt6-declarative`. A passing run is not this checklist.

## What these checks do not prove

- The bar is transparent on a real wallpaper.
- Text remains readable at 1.0 and 1.5 scale.
- `HDMI-A-1` matches the Qt screen name on the target machine.
- Hyprland IPC accepts `hl.dsp.focus({ workspace = 4 })` through the installed Quickshell build. The old `workspace 4` string was rejected. The replacement was clicked successfully on the CachyOS session after that fix. This tree does not change the expression. A cloud test is not that click.
- Hotplug destroys and recreates the window without a `targetScreens` binding loop. The loop was observed before this change. The property is no longer a binding. Silence on startup is not yet rechecked.
- `reserveSpace: true` reserves 28 logical pixels, Quickshell scales that to native pixels, and toggling the setting updates the zone without a restart. Overlap was seen while the flag was false. The `Normal` write has not been watched on the outputs. True fullscreen covering a `Top` layer has not been rechecked.
- The shell exits without taking Hyprland down.
- `./install.sh --install-deps` on a real Arch account. The hermetic test now fails if `/usr/bin` is on that test's PATH. It still does not run real `pacman`.
- Qt accepts `Scope`, `Singleton`, `PopupWindow`, and `HyprlandFocusGrab` as used here. The calendar and control center did open on CachyOS before this branch. This branch's focus-order change was not part of that launch.
- The popup stays inside the HDMI-A-1 output at scale 1.5, and the scrim stays readable on the real wallpaper. Blur is unsupported on Quickshell 0.2.0 and was not observed.
- Spotlight is centered on the focused monitor, the search field stays fixed while results scroll, and a second request closes it. The geometry is unit-tested in logical pixels. It was not shown on DP-1 or HDMI-A-1. Super+Space was not edited.
- PipeWire reports the default sink and accepts volume and mute writes.
- Escape and an outside click close the panel and return keyboard focus. The text-input diagnostic was seen. It is explained above and was not reproduced after the focus-order change.
- The optional top gradient remains inside the bar and does not steal clicks from windows below it.
- `WlrLayershell.namespace`, `WlrLayer.Top`, and `WlrKeyboardFocus.None` parse on the installed Quickshell. The 0.2 page documents those members. The namespace line had already been passed on the CachyOS startup that reached the calendar.
- `qs kill --help` on the installed binary matches the 0.2.0 parser or the later `--any-display` flag. The probe was tested with stubs only.
- Quickshell loaded `shell.qml`. The instantiation test uses QML stand-ins. `WlrLayershell.namespace` still stops that stand-in at `BarWindow.qml` because an attached object cannot be declared in QML. The stand-in fails the file if its error text contains `BarLabel`. That is the missing-import regression. It is not a `qs` launch. On CachyOS, startup reached the bar before the `BarLabel` failure, and the manual import let it continue. Dolphin and Helium appearing in search, theme icons, and focus return have not been rechecked.

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

A new settings file reserves the bar. If `~/.config/swiftshell/settings.json` still says `"reserveSpace": false`, set it to `true` for standalone use. The running shell reloads that file. Leave it `false` while Noctalia is also drawing on that output.

Clock format is `clock.use24Hour` in the same file. `true` prints `09:04`. `false` prints `9:04 AM`.

## Recovery

Stopping SwiftShell releases its layer surface. These milestones do not write Hyprland or another shell's files, so there is no compositor config to roll back. If a bar remains after stop, run `qs list --all` and kill only the instance whose config path is this checkout's `shell/shell.qml` or the installed `swiftshell/app` directory.

## Local per-monitor workspace repair (2026-10-31)

Verified on CachyOS: Quickshell 0.3.2, Qt 6.12.0, Hyprland 0.57.0.
DP-1: HP X32, scale 1; HDMI-A-1: PM161Q C, scale 1.25.

- `scripts/check.sh`: static checks, logic and observed-workspace regressions,
  settings file tests, 17 install tests, and Qt 6 QML suites pass. The checker
  now prefers the explicit Qt 6 runner over `/usr/bin/qmltestrunner` (Qt 5 here).
  Native notification plugin absence in qmltestrunner remains an explicitly
  recognized unavailable dependency; that component is not thereby runtime-tested.
- `qs -p shell/WorkspaceAudit.qml`: a windowless read-only audit reports
  DP-1 `1,2,3,gaming`, active `gaming`; HDMI-A-1 `4,5,6`, active `4`;
  focused DP-1. The probe exits itself and never dispatches a workspace action.
- `scripts/test-workspaces-native.sh`: hidden native SettingsWindow instantiates;
  real atomic save and subsequent process restart/readback pass using temporary
  XDG settings. This caught and regresses a synchronous JsonAdapter stale write.
- With owner approval only SwiftShell was restarted. Its actual root loaded,
  both output bars were instantiated, and diagnostics showed no new workspace
  snapshot failures or QML load failures. Existing launcher Keys/non-Item,
  missing launcher-request file, and deprecated Settings sizing warnings are
  separate known diagnostics, not suppressed or repaired here.

Visual checks still required on the running desktop:

1. Open Settings → Top bar → All. Open Workspaces and choose Automatic for
   each output, especially if an old global ID selection exists. DP-1 should
   show 1, 2, 3, gaming; HDMI-A-1 should show 4, 5, 6. Confirm readable labels
   and sensible spacing at scales 1 and 1.25.
2. Click numeric, named and empty workspaces on both bars. Each monitor should
   keep its own active mark even when focus is on the other monitor. Existing
   assignments must stay on their original outputs. Use Tab/Enter through the
   Settings controls; the transparent bars deliberately do not grab keyboard focus.
3. On DP-1 choose Override, save `1, 3, gaming`, and verify only its row changes.
   Save an empty list to hide that row, then Automatic to restore discovery.
   Duplicate entries should produce an error. Editing while focus/workspace
   events occur must not discard the draft or steal editor focus.
4. Top bar → Focused should follow the monitor receiving focus. Select an actual
   named monitor, then All; the old explicit selection must no longer override
   All. Primary means the first Qt screen, not an invented compositor primary.
5. After an owner-controlled restart, confirm the override and placement remain.
   Automatic follows actual ownership when a workspace moves externally. If
   convenient and safe, unplug/reconnect an output and verify its preference is
   retained and the remaining output's row remains correct.

These click, rendering, focus-follow and hotplug checks have **not** been automated
or claimed as visual passes. The native hidden-window test does not prove them.

Recovery: stop only this checkout with `scripts/stop.sh`. Revert the workspace
repair commit (do not hard reset), then `scripts/launch.sh`. The additive preference
can remain: old code preserves unknown keys in its extension bag. No compositor
configuration needs restoring. A pre-repair source copy was also retained in
`/tmp/swiftshell-before-workspaces/shell` for this session; it is not a durable backup.

## Live Displays transactions (2026-10-31)

Phase 1 verified with `python3 tests/live/display-transactions.py --live` on both
connected outputs. Passed Apply/Keep, explicit Revert, advertised 1280×720@60
mode changes, scale changes, 90-degree rotation, 15-second timeout recovery, and
recovery after the controlling process exited. Original monitor modes, scales,
positions, orientation and color formats were checked after every test and
restored at completion. No user Hyprland Lua file was written.

`scripts/check.sh` passes, including seven Python validation/journal tests,
logical mixed-scale geometry, and a QML pointer-drag regression that loads the
actual DisplaysPage and asserts rectangles retain their dimensions during a drag.
The native page was opened via `qs ipc -p shell call swiftshell settings displays`;
a window-bounded capture confirmed discovery, friendly names, mode lists and the
arrangement. This initial window remained tiled; floating behavior belongs to
Phase 2. Hardware APIs were checked against installed stubs and exact Hyprland
0.57.0 source (monitor-rule parser preserves unspecified fields on exact rules).

The external Python watchdog owns the confirmation deadline and fsyncs the
original state before applying. It survives Quickshell exit, watches the owner's
PID/start time, and reverts on timeout, owner death or failed verification. A
pending journal is recovered before accepting new work. Revert failures retain
the snapshot and retry; disconnected outputs cannot be restored until reconnected.
Do not delete the journal during recovery. `python3 shell/helpers/displayctl.py
revert` explicitly asks the watchdog to recover a pending transaction.

Kept layouts are in SwiftShell's own state directory and restored explicitly
with **Restore saved layout**. They are not automatically applied at login or
written into Hyprland configuration. HDR/color/ICC/reservations stay under the
existing compositor configuration; mirrored displays cannot be edited here.

## Native Settings redesign completion (2026-11-01)

Target: CachyOS, RTX 4070, Quickshell 0.3.2, Qt 6.12.0, Hyprland
0.57.0 Lua. DP-1 scale 1 and HDMI-A-1 scale 1.25. This is local desktop
execution, not a mocked compositor pass.

- `scripts/check.sh`: passed; 62 QML files checked, JavaScript suites, display
  and scoped-window Python tests, 17 installer checks, QML suites 6/13/5/4/4
  passed with zero failures or skips. Output `/tmp/swiftshell-final-check.log`.
- `python3 tests/live/settings-pages.py --live`: all eleven actual Settings
  categories reached Loader.Ready, with no native integration errors.
- `python3 tests/live/settings-window.py --live --output HDMI-A-1`: native title
  drag preserved size; all four edges and four corners resized; real maximize
  and restore, minimize and reactivation, close/reopen and saved geometry passed.
  DP-1 passed the same native gestures during the preceding implementation run.
  Tests restore the window's original geometry and fit the test window to the
  smaller logical display before exercising outward resize gestures.
- `python3 tests/live/settings-blur.py --live`: controlled checkerboard fixture
  fully covered each bounded capture. Actual blur on/off mean horizontal edge
  contrast: HDMI-A-1 0.016/2.142; DP-1 0.052/2.015. Radius 6/12, shadow opacity
  0/0.4 and softness 4/24 each produced measured pixel changes on both outputs.
  Private desktop pixels were not captured. Original appearance preferences and
  window position were restored. Captures are ephemeral `/tmp` artifacts.
- `scripts/test-workspaces-native.sh`: hidden real SettingsWindow loaded; atomic
  per-output workspace save and independent-process restart readback passed in
  temporary XDG directories. No user settings were replaced.
- `qs log -i qe1ejptnt --tail 100 --no-color`: no Settings TypeError,
  ReferenceError or failed component loads. Existing launcher non-Item Keys,
  missing launcher request file and Qt Wayland text-input warnings remain; this
  milestone does not claim they are repaired.

User visual acceptance: open every sidebar page, check readability over your
wallpaper, resize between compact and full navigation, use keyboard Tab and
search, and compare Appearance blur/radius/shadow extremes. In Displays, drag a
monitor and confirm it moves without distortion; Apply a desired supported layout,
then test Revert or leave the countdown unconfirmed before using Keep. Reopen
Settings after − to restore it. Hotplug, HDR/ICC editing, mirroring, full keyboard
accessibility audit, other drivers/compositors and notification ownership takeover
were not validated by this Settings milestone. User-authored Lua, Noctalia,
autostart and system services were left unchanged.

## Launcher invocation foundation (2026-11-01, roadmap C0)

The read-only effective binding audit found one ordinary Super+Space binding:
`Toggle application launcher`, executing the user's existing Noctalia command.
No bind, user Lua file or Noctalia process was changed. A one-line handoff was
prepared separately and passed `luac -p`; applying it needs explicit approval.

- `scripts/check.sh` passed after the direct IPC and Item keyboard-handler fix.
  Installer regression covers scoped checkout IPC, installed selection, failure
  when no shell responds, no stale token write, and unchanged Hyprland files.
- `python3 tests/live/launcher-invocation.py --live`: three open/close cycles on
  each output passed, with the actual input focused and correct focused monitor.
  The test restored monitor focus and closed only SwiftShell's launcher.
- `scripts/test-launcher-native.sh` executed on both HDMI-A-1 and DP-1: a real
  native LauncherWindow accepted typing and Escape dismissed it. QtTest sends
  keyboard events to the real native input; this is not a physical global-chord
  test. Temporary XDG settings isolated the audit from user preferences.
- Only SwiftShell instance qe1ejptnt was stopped; updated instance 6f8i1qtnt
  launched successfully. The previous non-Item Keys warning is gone. The legacy
  missing launcher.request warning remains because older token callers remain
  supported. Qt Wayland text-input warnings remain under investigation.

C0's physical Super+Space handoff and reboot persistence acceptance are pending
approval. This increment does not claim that changing the request command alone
changes the existing compositor binding. Full Spotlight redesign belongs to C1.


## Approved Super+Space handoff (2026-11-01, roadmap C0)

Owner approval covered backup and the prepared single-line command change. The
original binds.lua was copied and byte-verified before any write. The final backup
is `binds.lua.bak-swiftshell-launcher-20261101T132508Z` in the same user config
directory. Lua syntax validation passed before atomic replacement. Automatic
Hyprland reload reported no errors, preserved all 94 binding metadata records
(normalizing opaque Lua callback addresses only), and preserved both output modes,
transforms, scales and positions. Two initial strict comparison attempts restored
the original command before the harmless callback-address difference was explained.

`python3 tests/live/launcher-shortcut.py --live` passed actual compositor binding
invocation through native virtual-keyboard events on HDMI-A-1 and DP-1. Each output
passed two open/repeat-toggle cycles plus open/Escape. No duplicate Super+Space
binding exists. The test closes only SwiftShell’s launcher and restores original
monitor focus. New C transport compiles with `-Wall -Wextra -Werror`; the upstream
wlroots protocol retains its copyright and license. No virtual keyboard daemon,
system service, package installation or administrator privileges were needed.

The command is persisted in the approved user file and survives configuration
reload. Reboot and a human physical-keypress were not performed. No Noctalia
process/configuration, other shortcut, autostart, service or core OS file changed.

## Bar surface modes (2026-11-01, roadmap B1)

`scripts/check.sh` passed: 64 QML files; all JavaScript suites, 8 display and 7
window-helper Python cases, 17 installer checks, QML totals 6/13/6/4/4, zero
failures/skips. `scripts/test-workspaces-native.sh` now also verifies global and
per-output bar appearance across an actual independent-process restart in temporary
XDG directories. This caught and regresses the JsonAdapter serialization timing
issue when several surface/workspace settings change synchronously.

`python3 tests/live/bar-surfaces.py --live` passed all three actual modes on both
outputs, asserted other bars stayed unchanged, and restored original overrides.
A raised controlled checkerboard fully shielded the bounded capture behind the
real production bar. Mean horizontal edge contrast, transparent/solid/frosted:
HDMI-A-1 19.786/13.386/3.341; DP-1 29.880/19.941/6.009. The real layer blur is
observable while foreground remains sharp. No layer rule or global compositor
blur setting was required. Crops are `/tmp/swiftshell-bar-<output>-<mode>.png`.
Native Settings category loading and actual Super+Space/repeat/Escape passed
again on both outputs. Settings activation requests were allowed to drain before
changing test monitor focus; otherwise an earlier asynchronous show request can
legitimately reactivate its own output during the chord test.

Native mode/blur tests use temporary overrides and leave the user's transparent
bars, heights, workspace lists, modules and per-output monitor choices intact.
Normal capability checks never capture desktop pixels. Missing-tool fallback is
unit-tested, rather than uninstalling user software or disabling global blur.
Physical hotplug and full wallpaper/opacity accessibility review remain NOT RUN.

## Bar flicker and themed color picker (2026-11-01)

Native before/after hidden-bar lifecycle audit: old 23 module / 68 workspace
creations; new 9 / 4 under 15 preference/urgency updates and module hide/show.
`python3 tests/live/bar-stability.py --live` retains this regression in temporary
XDG directories. Role updates and reorder preserve existing workspace controls;
QML tests verify object identity and active/urgent values, not just item counts.

`python3 tests/live/color-picker.py --live` and `--output HDMI-A-1` passed real
pointer hue/saturation/value editing, two cancels and one commit, no preference
writes while drafting, no extra native client and no Settings geometry movement.
The original global bar color/mode/opacity and prior Settings open/category state
were restored. A separate bounded capture over the owned checkerboard fixture
was visually inspected at `/tmp/swiftshell-themed-color-picker.png`.

New always-run QML suites: keyed models 4 passed, color picker 8 passed. The latter
covers cancel, invalid hex, one accepted value, Escape, keyboard edits, dark/light
shared theme and pointer dragging. Color selection no longer depends on
QtQuick.Dialogs; native image/folder selection remains separately gated.
Existing native bar mode/blur, hidden atomic save/restart and actual global
Super+Space regressions passed on both monitors. Startup geometry readiness is
included in diagnostics to avoid sending test clicks during native restore.
No claim is made about high-GPU-load driver behavior or every physical hotplug case.

## B2 bar ergonomics and frosted panels (2026-11-01)

`scripts/check.sh` passed including new clock/group/visibility logic and bounded
scrolling QML tests. `scripts/test-settings-save-native.sh` passes real FileView
duplicate-write and rapid-edit regression with final disk readback, plus backed-up
v2 migration followed by further edits. The expanded
`scripts/test-workspaces-native.sh` verifies new clock/group/visibility preferences
alongside existing named workspaces and surfaces across a process restart.

`python3 tests/live/bar-ergonomics.py --live` passed both connected monitors:
12/24-hour/date/seconds ticks, non-overlapping centered clock, real right-click and
per-monitor checkboxes, Escape, Customize, and actual Super+Space focus handoff.
Calendar/control/module panels passed real compositor blur comparisons against
an owned checkerboard with observed layer geometry. Final persistence returned
ready after restoring preferences. See decision 0035 for measured comparisons.
The real-pointer color picker, eleven Settings pages and actual global shortcut
regressions were rerun after the writer fix. Test transports guard cursor position
before sending button presses, retrying only moves that sent no press.

Visual acceptance: right-click each bar and toggle a module; the other output
should stay unchanged. In Settings → Bar choose clock seconds/date/style and
module positions, then reopen Calendar and Control Center. Check readable text,
consistent rounded frost/shadow, no initial size flash and Escape/outside dismissal.
Color picker drafts should remain inside Settings and only save on Use color.
Physical hotplug and sustained gaming load remain unperformed.

Runtime log review retained the known Qt Wayland text-input focus warnings; these
were not suppressed. No QML binding-loop/type errors appeared in the final
interaction log. Test-owned opacity and visibility overrides were explicitly
restored from the verified pre-milestone backup and checked on disk.

## PR 41 Qt 6.4 compatibility

GitHub's Ubuntu Qt 6.4 runner exposed an unavailable Overlay lookup through the
Basic style namespace. The picker now imports the base Controls attached type
explicitly while keeping Basic styling. The pointer regression asserts a real
window overlay with the expected width. KeyedModel uses explicit dynamic roles
so older Qt retains object rows without nested-list role type warnings.
The complete local check suite passed after both corrections.

## Native desktop applications and devices (2026-11-01–02)

The exact staged backend tree and exact staged UI tree independently passed
`scripts/check.sh`. The final local suite passes 71 Python tests, 16 QML suites,
the JS regressions, 17 installer cases and static checks for 88 QML documents.
GitHub's Ubuntu Qt 6.4 runner also passes: timer input waits for rendering after
layout changes, and the tray script guards a nullable QML context named module.
The local runtime remains Quickshell 0.3.2 / Qt 6.12 / Hyprland 0.57 on RTX 4070,
DP-1 scale 1 and HDMI-A-1 scale 1.25. Monitor positions/modes were preserved.

Native evidence:

- `settings-pages.py`: all twelve current sidebar categories loaded on the actual
  floating window. Bluetooth is included in Network & Devices.
- `settings-window.py --output DP-1` and `--output HDMI-A-1`: title drag, all four
  edges/four corners, maximize/restore, minimize/reactivation and saved geometry.
- `workspace-drag.py`: actual handle movement, named/empty indicators retained,
  disk readback, unchanged window geometry and scoped preference restoration.
- `spotlight.py`: actual typed calculation, context/keyboard Favorites, All/Favorites,
  tile drag ordering, no accidental launch, Settings icon, Escape on both outputs.
- `launcher-shortcut.py`: actual Super+Space open/repeat toggle/Escape on both.
- `clock-panel.py`: actual faces, Calendar navigation, timer pause/resume/cancel,
  stopwatch/laps/reset, rounded blur and Escape on both outputs; exact tool state
  restored on disk. `clock-tools.py` verifies isolated deadline/restart behavior.
- `bar-inputs.py`: date→Calendar and time→Clock, direct view switching, dedicated
  Audio/Network/Power panels, native tray menu open/Escape on both outputs.
- `bar-persistence.py`: a real visibility checkbox, atomic save, complete scoped
  SwiftShell restart, per-output readback and restoration of the original override.
- `settings-external.py`: real external edits, subsequent no-op/actual saves, and
  malformed/future-file protection without changing live preference values.
- Native duplicate/rapid save, backed-up v2 migration and expanded workspace/
  Spotlight opening-mode process-restart readback scripts passed.
- `tray-native.py`: actual native StatusNotifier ObjectModel order/count, all two
  currently published items displayed. Seven fixture items test the removed cap.
  Steam/Discord publish icons; Cachy-Update is installed but not running/publishing.
- `shortcuts-native.py`: real inhibition captured Super+Space without launching
  Spotlight; a recorded owned chord was applied/read back/removed. All original
  94 effective bindings were unchanged.
- `default-apps.py`: actual xdg-mime selection/readback/backup/Undo in temporary XDG.
  `network-devices.py`: actual NetworkManager transport/state/view ownership with
  no connectivity changes. `power-profiles.py`: actual pointer choice, D-Bus
  readback and exact original Performance mode restoration.
- `contrast.py`: actual hidden bars and async decoder for JPEG/WebP, displayed crop,
  opaque material foreground and mixed-band readability. `bar-stability.py`: 11
  module creations (ten initial plus one deliberate re-add), four retained workspace
  controls, one settings load through 15 appearance/urgency changes.

Actual compositor runtime readback also passed radius 14, blur size 4/passes 2 and
border width 0, followed by Restore and exact pre-test option/journal restoration.
No user Lua, Noctalia, autostart, display modes or unrelated services were changed.
Backups retained: own state directory backups/20261101T190959Z-native-desktop and
backups/20261102T111525Z-desktop-activation. Revert the commits for source recovery;
`python3 shell/helpers/appearancectl.py restore` restores owned desktop options.

Owned checkerboard blur comparisons (on/off edge contrast; smaller means blur):
HDMI Clock 2.318/4.392, Calendar 3.221/5.274, Audio .868/3.223,
Power 4.675/6.768, modules 1.369/4.085; DP Clock 2.515/5.414,
Calendar 3.843/6.662, Audio 1.496/4.409, Power 7.559/9.973,
modules 2.072/5.397. Full Clock and Calendar/module captures were visually inspected;
no underlying application pixels were captured. Spotlight was separately inspected
and measured in decision 0037. Capture files remain under /tmp.

Limits: existing opaque Lua shortcut callbacks are not editable; no calendar app
is installed; no Wi-Fi connection/disconnection, radio change, Bluetooth pairing,
real timer notification, shutdown/reboot/suspend/lock or real-player playback was
performed. Those controls have verified APIs, capability/disabled/error behavior
and focused tests, but this is not an execution claim. Physical hotplug, sustained
GPU/gaming load, every wallpaper and comprehensive accessibility remain pending.
Known Qt Wayland text-input focus warnings remain visible; they were not suppressed.

Final activation at 2026-11-02 12:22 UTC repeated the full scoped-restart visibility
check, both-output bar/tray inputs, Spotlight keyboard/context/favorite-drag checks
and all twelve Settings pages against the final source. Adaptive bar text was
enabled as requested; both outputs reported completed contrast analysis. The
immediately preceding preferences are retained in own state backup
`backups/20261102T122221Z-final-contrast`. Final runtime logs had no QML loading
errors; known Qt text-input and absent legacy request-file warnings remain.


## Notifications, overview, per-display bars and desktop tools — 2026-11-02

Target: Quickshell 0.3.2, Qt 6.12.0, Hyprland 0.57 Lua, NVIDIA RTX 4070;
DP-1 scale 1 and HDMI-A-1 scale 1.25. `scripts/check.sh` passed, including
96 QML documents, the notification/overview/desktop-tools regressions and all
existing checks. Each device, notification/overview/bar, and Spotlight commit was
also checked from its exact staged tree in a temporary checkout. These new commits
have local evidence; the earlier PR's CI result is not a CI claim for them.

Native checks performed:

- `tests/live/notifications-native.py --live`: private D-Bus session with actual
  Quickshell server receipt/replacement, client close, native action callback,
  timeout/history, transient, DND, snooze/wake and 70-notification bounded burst.
  This caught the installed version's millisecond timeout behavior. Actions remain
  usable after a banner archives, until the source closes or the user dismisses it.
- Main session: observed no notification owner, backed up preferences, enabled
  SwiftShell, verified the resulting bus-owner PID, sent a real `notify-send`,
  observed receipt and mapped/bounded banner geometry, then dismissed that test ID.
- `tests/live/clock-notifications.py --live`: actual timer deadline, live bar
  activity, completion notification, snooze/wake and action opening Timer; actual
  stopwatch pause notification opening Stopwatch. Original clock tool state restored.
- `tests/live/overview.py --live`: actual local window preview frames and backdrop
  blur, workspace counts and keyboard Escape on both outputs; no window pixels
  were recorded or sent anywhere. Some dormant/minimized clients may supply no
  frame and receive a labeled fallback card.
- `tests/live/overview-shortcut.py --live`: actual Alt+Tab activation, repeated chord
  navigation and Escape on both outputs. The known cycle-next chord was first
  enabled/restored in a guarded test, leaving unrelated bindings unchanged, then
  enabled as requested. No Lua files were written.
- `tests/live/bar-layouts.py --live`: Top/Bottom/Left/Right with .9/1.25 content
  scales on each monitor, other-output independence and drawer opening; restored
  original layouts. Reservation updates coalesce so orientation changes do not
  temporarily reserve an entire screen width.
- `tests/live/bar-persistence.py --live`: actual checkbox/save/full scoped restart
  and restoration, including final source activation.
- `tests/live/spotlight-desktop.py --live`: actual owned native-window activation,
  precise Settings-control navigation and capability-detected screenshot entries.
  Existing Spotlight pointer/favorite/context tests and all Settings pages passed.
- `tests/live/screenshot-tools.py --live`: real `grim` capture strictly inside an
  opaque owned checkerboard, valid image transport to a private sink. No desktop
  clipboard change and no unrelated application pixels. Full-display capture and
  interactive region selection remain user acceptance checks.
- `tests/live/network-devices.py --live`: actual NetworkManager read-only snapshot,
  helper transport and view ownership. Python/QML regressions cover authentication
  validation, retained availability after errors, targeted cancellation and all
  24 Bluetooth fixture devices instead of the former 16-device truncation.
- Async wallpaper sampling and bounded PNG fallback now test all four bar edges,
  including scaled thickness, displayed crop and per-output refresh.

Notification preferences and original activation state are backed up under own
state `backups/20261102T163711Z-notification-overview`. Source backups include
`/tmp/swiftshell-notification-bar-20261102T074251` and
`/tmp/swiftshell-device-workflows-20261102T124420Z`; committed source is the durable
recovery path. Notifications are now enabled on this session; fresh installs still
leave ownership off. Alt+Tab's owned recovery journal is mode 600, written before
mutation; if SwiftShell is absent, its handler falls back to window cycling.
Restore with `python3 shell/helpers/overviewctl.py restore`, or turn the overview
shortcut off in Workspaces. Disable SwiftShell notifications in Settings to release
the bus name; no previous daemon was stopped and none is automatically started.

Limits: notification sounds/images/inline replies and disk-persisted history are
not provided. Clipboard history defaults off, is bounded to 30 text items/20 minutes
in memory, excludes advertised sensitive formats and requires explicit `clip`
searches. Ordinary copied secrets can still enter history if their source supplies
no privacy hint. Real password-manager behavior, Wi-Fi authentication/connection
changes, Bluetooth PIN/pairing/cancel side effects, physical monitor hotplug and
sustained GPU load remain unperformed. Existing system pairing agents are preserved.
Known Qt Wayland text-input warnings and the absent legacy launcher request file
remain visible; no claim that every intermittent graphics flicker is eliminated.

Final source activation repeated Clock notification actions, both-output actual
Alt+Tab, desktop Spotlight activation, native tray/date/time/widget input and all
twelve Settings pages successfully. The running checkout matches the committed
feature source; normal source-file watching was restored after verification.


## Notification preferences and interaction polish — 2026-11-02

`bash scripts/check.sh` passed on Quickshell 0.3.2 / Qt 6.12 / Hyprland 0.57 Lua,
including 97 QML documents and the expanded notification policy/UI regressions.
The exact staged tree was also checked before committing. Evidence remains local;
this is not a claim that CI ran these commits on another Qt version.

- Fixed active DND/app-rule reconfiguration for local Clock entries as well as
  native notifications. Clock events use the configured duration. Critical default
  timeouts stay until dismissal, and critical arrivals/wakeups take an ordinary
  banner slot when the bounded four-banner queue is full.
- Pure tests cover same-day/overnight weekday boundaries, start-day ownership,
  all-day schedules, invalid settings, explicit critical timeouts, priority,
  local-only image URLs and additive v3 defaults. New sound/quiet/privacy settings
  have a real isolated native atomic save, invalid-value rejection and complete
  process-restart readback (`notification-preferences.py --live`).
- `notifications-native.py --live` passed actual protocol receipt/replacement,
  actions, image-path and image-data, native inline-reply signal, client close,
  default critical timeout, silent hints, DND/sound suppression, no replacement
  sound replay, actual one-second snooze wake and pause expiry, plus the bounded
  70-message burst. All of this used a private D-Bus session, not user messages.
- `notification-sound.py --live` loaded the generated WAV and observed actual Qt
  playback start/completion at isolated 2% volume. No system volume changed.
  This is backend playback evidence, not a claim that a person heard the speakers.
- `notification-surfaces.py --live` passed actual image rendering, app-only privacy,
  light/dark themes and native Reply→drawer keyboard typing/Send/Escape on both
  DP-1 and HDMI-A-1. A second incoming notification did not erase the draft/focus.
  Full-page QML input tests additionally verify the active reply remains scrolled
  into view when incoming messages push it down.
- Banner and grouped drawer delegates are keyed. Property refreshes coalesce until
  native property batches finish, avoiding closing an object inside its update.
  Reply fields and drafts survive role changes rather than being recreated.
- Visual inspection found and fixed blur covering transparent shadow padding.
  Blur/input now use the union of rounded card regions clipped to the viewport;
  shadows and gaps remain clear. Owned shadow-band contrast measured 122 on both
  outputs, and the native test requires >70 to catch the former broad blur.
  Snooze controls share the action row, group headers align left, timestamps avoid
  repeated app names, and reply placeholders use a readable theme color.

Owned screenshots were inspected at `/tmp/swiftshell-notification-DP-1-drawer.png`
and both outputs' `-dark.png`, `-light.png` and `-private.png` variants. The capture
helper asserts every pixel lies over an opaque owned test background, and uses
synthetic notification content on a private bus. No unrelated application pixels
or real notification bodies were captured.

Final activation used only the scoped SwiftShell restart. Actual Clock notification
snooze/wake/open actions and all twelve Settings pages passed on the running build.
No loading/type/binding errors were found. Known Qt text-input diagnostics and the
absent legacy launcher request-file warning remain visible. Preferences and Clock
state are backed up in own state `backups/20261102T193514Z-notification-polish`;
source backup is `/tmp/swiftshell-notification-polish-20261102T134843`.

Default sound and scheduled quiet hours remain off; preview mode remains full.
No network, audio device/default, global volume, monitor mode, Noctalia, user Lua,
autostart or service configuration was changed. Wi-Fi was audited read-only:
hardware enabled, radio disabled; Ethernet stayed connected. Real messaging apps
must advertise inline reply, and their app-specific handling still needs owner
acceptance. Scheduled quiet hours use local time; no system-time or suspend test
was performed. History/drafts remain session-only and HTTP image fetching is not
supported. Revert this commit for source recovery; turn new settings off/reset
individual fields in Notifications to keep newer unrelated preferences intact.

## CI compatibility repair — 2026-11-02

GitHub runs 41513275241 (PR) and 41513935523 (main) failed in
`NotificationCenter::test_banner_previews_and_action_labels_are_plain`: Qt 6.4
exposes `Item.children` as an indexed QML list without JavaScript iteration.
The test now traverses by index and requires a matching label, preserving the
plain-text assertion. The next run (41514946078) passed notifications and exposed
the same indexed-list limitation in the overview test helper, whose use of
`children.filter` is now replaced by indexed traversal too. The earlier Bluetooth Connections signal collision was
already fixed in c3ec14c. The PR runner also spent 6m48s installing dependencies;
its mirror downloaded 38.3 MB at 98 kB/s and completed successfully. That delay
was separate from the test failure.

CI now pins Ubuntu 24.04 for the Qt 6.4 compatibility baseline, avoids optional
APT recommendations, bounds retries/network waits and job/step duration, and
reports checker versions. Local `scripts/check.sh` passed: static checks cover
97 QML files and all 19 QML suites passed on Qt 6.12. This test/workflow change
does not restart SwiftShell or modify desktop configuration. Backups of the
affected files are in `/tmp/swiftshell-ci-repair-backup`; revert the repair
commit to restore the previous workflow/test. GitHub validation is recorded in
the repair PR; offscreen CI does not verify compositor behavior.

## Desktop quick tools and terminal applications — 2026-11-02

The complete `scripts/check.sh` passes on local Qt 6.12: static coverage includes
108 QML documents and all 22 QML suites pass. Added Python tests cover terminal
argument wrapping, selected-terminal failures, telemetry deltas/missing sensors,
private screenshot cache/PNG export and clipboard window scoping/geometry. JS
regressions cover additive per-monitor module migration, stable clipboard IDs and
acceptance of the two new IDs by the actual popup reducer. The native bar test
caught that last integration defect, which isolated panel tests did not cover.

Native checks on Quickshell 0.3.2 / Hyprland 0.57 Lua / RTX 4070:

- `tests/live/terminal-launch.py --live`: a real Terminal=true desktop entry
  reached a terminal PTY with literal spaced/metacharacter arguments. Cachy-Update's
  installed entry uses Terminal=true and Exec=arch-update; the updater itself was
  not executed, and no packages or system settings were changed.
- `performance-native.py --live`: real CPU delta/RAM and NVIDIA usage/VRAM/temps,
  stable bar label identities and owned panel rendering on both output scales.
  RAM temperature is not exposed by this workstation and is not fabricated.
- `clipboard-history.py --live`: synthetic text copy through a private offscreen
  clipboard; real floating placement/focus/blur attachment/Escape/close on both
  displays. No desktop clipboard content was read or changed.
- `screenshot-review.py --live`: grim captured only opaque owned checkerboard
  pixels, preview rendered, a private clipboard sink decoded the PNG, and the real
  native Save As dialog's accepted handler exported a valid PNG on both displays.
  This invokes the dialog handler, not a physical pointer click on its Save button.
- After scoped activation, `desktop-quick-tools.py --live` passed actual camera,
  clipboard and performance bar clicks, Escape, pinned clipboard window opening/
  closing, non-overlapping bar bounds, screenshot search and real telemetry on
  DP-1 (scale 1) and HDMI-A-1 (scale 1.25). No screenshot capture or clipboard
  mutation occurred in this production-session test.

Owned screenshots of the screenshot review and performance surfaces were visually
inspected under `/tmp/swiftshell-screenshot-*-review.png` and
`/tmp/swiftshell-performance-*.png`. Final logs had no QML loading/type/binding
errors. Existing Qt Wayland text-input diagnostics and the absent legacy launcher
request-file warning remain visible. No Noctalia, user-authored Lua, display mode,
autostart or unrelated service was changed. Source watching was paused during
development and restored after activation.

Clipboard history stays opt-in, text-only, session-only and bounded to 30 items/
20 minutes. Keep open persists the floating surface until closed, not the copied
text across a shell restart. Screenshot review caches the current PNG privately
in the runtime directory until replaced/discarded or the login session ends.
Interactive physical slurp selection, real desktop clipboard paste into another
app, physical Save As selection, sustained gaming load and every third-party
terminal remain owner acceptance checks. SwiftShell preferences before activation
are backed up under own state `backups/20261102T234104Z-desktop-tools`; tracked
source and `/tmp/swiftshell-desktop-tools-backup` preserve the prior implementation.
Revert these feature commits for source recovery; hiding a new bar widget or
disabling history does not modify compositor/session configuration.

## Bar hover and drag ordering — 2026-11-02

Removed hover ToolTips from bar widgets, clock, Search and tray controls; accessible
names/descriptions and activation/context actions remain. The source regression
rejects new hover hints in bar components. All existing 22 QML suites and actual
both-output desktop quick-action clicks/Escape passed after this removal.

Top bar Settings now uses drag handles/drop markers instead of ordering arrows.
Drag changes remain local until release, Escape cancels even after later pointer
motion, edge auto-scroll runs only during a drag, and Alt J/K preserves keyboard
access. A single insertion updates the selected output's existing order, preserving
its edge, scale, grouping and visibility. Handles/delegates retain their identity.

`scripts/check.sh` passes: 109 QML documents and all 23 QML suites, including seven
new drag cases for commit-once, cancellation, scrolling, keyboard/visibility/group
independence and full-page per-monitor isolation. The native Quickshell test caught
a missing qmldir registration that plain Qt's implicit lookup had accepted; the
registration and a static regression now cover it.

`tests/live/bar-module-drag.py --live` passed a real pointer drag inside the running
Settings window, atomic on-disk order readback, unchanged other-output overrides
and unchanged Settings geometry. It restored the exact preceding default-profile
override, category, window visibility, cursor and focus. The full pre-test SwiftShell
preferences remain backed up privately in `/tmp/swiftshell-bar-order-settings-backup.json`.
No compositor configuration, monitor mode, Noctalia or service was changed. Runtime
loading/type/binding errors were absent after the corrected build activation; known
Qt text-input/legacy request-file diagnostics remain. Revert the two bar-polish
commits for recovery. Physical long-distance drag scrolling and touch input remain
owner acceptance checks; drag scrolling is covered by QML input tests.

## Real area selection and display-scoped visibility correction — 2026-11-02

The actual slurp selector reproduced the user-reported invisible/stuck capture:
its process inherited an open input pipe and waited for input before mapping any
selection layer. Bounded read-only child tools now receive DEVNULL stdin. A real
subprocess regression keeps its parent pipe open to catch this. Screenshot tools
also cancel unfinished work when reopened, wait for cancellation before accepting
a new capture, treat Escape as normal cancellation, and explain the area gesture.

`tests/live/screenshot-review.py --live --interactive` now uses the installed slurp
instead of a geometry stub. Both monitors passed real selector mapping, actual
64×64 area drags over an opaque owned checkerboard, image preview, private PNG
clipboard decoding, native Save As handler export, Escape cancellation and close
cleanup with no remaining selector or busy state. No unrelated screen pixels or
actual clipboard data were used. This supersedes the earlier unperformed real
area-selection limitation; physical user selection and paste remain acceptance
checks. The generated screenshots remain owned fixture images.

Show/Hide had been editing inherited defaults while both connectors had explicit
visibility overrides. Settings now chooses the focused connector once, preserves
that choice when focus moves, and clearly labels the default-for-inheriting-displays
option. `bar-visibility.py --live` passed actual display-dropdown/Show-Hide and
right-click-checkbox interactions in both directions on both monitors, disk
readback and preservation/restoration of other-display overrides. The adapted
`bar-module-drag.py --live` also passed selected-connector ordering/persistence
and scoped restoration. Source backups are under `/tmp/swiftshell-screenshot-selector-backup`
and `/tmp/swiftshell-bar-visibility-*.bak`; committed source is the recovery path.

## Settings interaction, persistence and weather integration — 2026-11-05

The Settings rebuild uses shared collapsible sections, searchable controls, a live
appearance sample, consistent Undo/Reset and visible-frame resize bands. Native
`tests/live/settings-ux.py --live` passed on HDMI-A-1 and DP-1: requested-output
first map, centering, resizing at the painted corner, collapse/search restoration,
slider drag without page scroll, one Undo step per gesture and saved size on
reopen. Captures contain only the owned QML surface. Bluetooth appears near the
top of Network & Devices. Shared controls use the optional appearance accent.

`tests/live/settings-cold-start.py --live` passed a write followed by two fresh
Quickshell processes with temporary preferences: accent, opaque-window preference,
fullscreen peek, collapsed sections, weather units/query and per-output hidden
widgets survived. This is process-restart evidence, **not an actual machine reboot**.
`scripts/test-settings-save-native.sh` passed duplicate/rapid writes and backed-up
v2 migration; `tests/live/settings-external.py --live` passed external readback and
malformed/future-file protection. Atomic writes now merge locally changed leaves
against the locked latest disk document. Canonical comparisons prevent an endless
Saving state caused solely by property order. Unreadable settings stay protected.

Weather is a sidebar category, local Settings search result and selectable bar
widget with an output-anchored frosted forecast. It starts disabled. Location
search and approximate-IP lookup require explicit user actions; installation does
not request location. Public API evidence uses Berlin and a temporary cache;
user-location/IP lookup was not performed. See decision 0046 for transport,
caching, units, forecast and air-quality test evidence.

`tests/live/bar-stability.py --live` passed 15 appearance/workspace changes with
stable module identities and a single preferences load; the only extra module
creation was the deliberate Battery hide/show. This does not prove every reported
intermittent frame flicker is gone. Real game fullscreen flicker was not reproduced
by owned dual-output fixtures, so no VRR/direct-scanout or display modes were changed.

Recovery: revert the corresponding feature commits and restart only this checkout
with `scripts/stop.sh` followed by `scripts/launch.sh`. Temporary source backups
include `/tmp/swiftshell-nov5-resume-backup.tgz`. Disabling the optional opacity
integration restores only its owned runtime keys; no user Lua, startup or Noctalia
files are changed by the Settings/weather slices.

## Source-backed shortcuts and selected terminal — 2026-11-05

Decision 0048 records the actual Hyprland 0.57 Lua API and recovery design.
`tests/live/source-shortcuts.py --live` passed source span editing, preservation of
the original callback, exact Undo and independent helper-death recovery. The native
recorder test `source-shortcuts-ui.py --live` additionally passed real shortcut
inhibition/recording, source apply and Undo without changing unrelated bindings.
Source/default-app/legacy-helper unit suites passed 16/13/12 tests respectively.
The real selected Konsole default now updates the existing desktop terminal action;
only its literal variable and one callback changed, with the other 93 bindings and
other source files verified unchanged. The original automatic-reload setting and
file permissions were preserved. No full Hyprland reload or app launch occurred.
Super+Enter and actual login/reboot remain owner acceptance checks.

Final review also caught the disabled-weather zero-width latch and asynchronous
settings-reader completion during a save. Real ModuleStrip regression covers
weather off/on/off/on with one retained instance; five QML persistence cases cover
late reads/errors preserving drafts and the in-flight writer. A source-handler
regression covers deferred Settings load failure and stale callback guards. These
prevent a missing component from recursively changing its own Loader binding.

## Final activation and integration evidence — 2026-11-05

The checkout was restarted by selecting its exact SwiftShell instance ID; unrelated
Quickshell/Noctalia processes were not targeted. `scripts/check.sh` exited 0 with
127 production QML documents, 29 QML suites and 218 passing QML cases, plus the
logic/Python/installer suites. No QML warning lines occurred. The subsequent pure
scroll-target change passed its logic regressions and the real pointer tests below.
CI now explicitly installs Lua 5.4 for source validation tests; no package was
installed on the owner's workstation.

After activation, `settings-pages.py --live` loaded all 13 sidebar categories,
including Weather. `bar-visibility.py --live` passed both-output native display
selection, Show/Hide, right-click synchronization and disk readback; it initially
caught oversized-section search navigation hiding the selector. The corrected
scroll target reveals the beginning of tall sections. `bar-module-drag.py --live`
passed real drag/drop, atomic order readback, other-output preservation and stable
Settings geometry. Both tests restored preceding preferences and focus. Current
runtime logs contain no QML type/loading/reference/binding-loop errors.

A disabled weather widget initially left a trailing 12 px Grid gap. The ten-case
Weather QML suite now covers both module orders with a neighboring control; Grid
columns count participating widgets. Native `bar-stability.py --live` still passed
15 appearance/workspace updates without recreating unaffected modules. Actual bar
layout returned to its preceding width on both outputs.

Final readback: DP-1 2560×1440 at 164.834 Hz, scale 1; HDMI-A-1 1920×1080 at 60 Hz,
scale 1.25; original positions and transforms retained. The checksum of binds.lua,
monitors.lua and decorations.lua is unchanged. Only the authorized TERMINAL literal
changed in variables.lua. All 94 effective bindings remain present and automatic
config reload is enabled as before. Active/inactive compositor opacity reads 1/1
for the already opted-in desktop appearance integration. The new weather/location
and fullscreen-peek preferences remain opt-in. Source watching is restored.

Owner acceptance: play the fullscreen game while crossing displays; verify
Super+Enter opens Konsole; compare DP-1 text clarity; try real media scrubbing and
preferred audio devices; inspect dark/light tray popups; configure a weather city;
and check settings after the next normal login/reboot. The actual game flicker was
not reproduced by owned fixtures and no VRR/scanout workaround was applied.

## Actual RuneScape fullscreen investigation — 2026-11-05

The owner explicitly authorized launching Steam/RuneScape, joining the selected
world, display-crossing input, scoped capture and termination afterward. Steam was
opened on HDMI-A-1 workspace 4. The installed RuneScape app launched into DP-1's
named gaming workspace in actual fullscreen. The existing linked login and selected
world were used; no gameplay keys/buttons, graphics settings or purchases were used.

Three passes sent 52 display-boundary crossings with a single persistent
motion-only Wayland pointer per pass. This exercised normal pointer-driven focus
between the actual game and Steam rather than relying only on compositor cursor
warps. The first 20 crossings had no active recording. A 16-second XWayland-window
recording covered another 16 crossings, followed by a separate 16-second composited
DP-1 capture with 16 crossings. Recordings/account pixels remain private local
artifacts and are not included in the repository or uploaded as bug attachments.

Observed evidence:

- Hyprland 0.57.0, exact source commit
  `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426`; NVIDIA RTX 4070 driver 615.78.08;
  XWayland 24.1.14. The launched Windows RuneScape client used XWayland.
- `render:direct_scanout=2`, `misc:vrr=3`,
  `cursor:no_hardware_cursors=2`, `cursor:no_break_fs_vrr=2`, and
  `opengl:nvidia_anti_flicker=true`. These values were observed, not changed.
- DP-1's `directScanoutTo` was `"0"` in all 458 samples. The 120 samples in the
  non-recorded pass already reported the software-cursor (`SW`) scanout blocker.
  During compositor capture some samples additionally reported `RECORD`.
- DP-1 VRR stayed enabled while focus repeatedly switched between the game and
  Steam. HDMI-A-1 VRR stayed disabled. This does not measure instantaneous panel
  refresh intervals or exclude low-framerate-compensation/brightness effects.
- The app recording contained 480 frames at 30 fps. The composited output capture
  contained 320 frames at 20 fps. Neither contained a black frame or a large global
  brightness flash. Their mean luma ranges were approximately 65.06–66.26 and
  65.77–65.97 respectively on the decoded 8-bit scale. These sampled digital
  buffers cannot prove that a brief physical monitor/VRR flicker did not occur.
- Current compositor logging is disabled. Empty rolling-log keyword counts are
  consequently not evidence that modesetting or driver problems never occurred.

The exact-version upstream source clarifies the bypass hypothesis:

- [CMonitor::isDSBlocked](https://github.com/hyprwm/Hyprland/blob/0aa6745f705f2c4b0a5004eb019ef76e5bbdb426/src/output/Monitor.cpp#L1899)
  includes software-cursor and recording blockers.
- [CMonitor::shouldUseSoftwareCursors](https://github.com/hyprwm/Hyprland/blob/0aa6745f705f2c4b0a5004eb019ef76e5bbdb426/src/output/Monitor.cpp#L2196)
  selects software cursors in auto mode on NVIDIA when any monitor has active VRR.
- [VRR policy](https://github.com/hyprwm/Hyprland/blob/0aa6745f705f2c4b0a5004eb019ef76e5bbdb426/src/config/shared/monitor/MonitorRuleManager.cpp#L197)
  uses the output's fullscreen workspace/content state; changing the focused
  monitor alone does not require disabling that fullscreen output's VRR.
- [Hyprland's FAQ](https://wiki.hypr.land/faq/)
  documents refresh-rate-dependent panel brightness flicker. VRR staying enabled
  does not imply that the frame intervals or brightness remain constant.
- Hyprland 0.57 also introduced relevant auto-HDR behavior; the local option is on
  and DP-1 advertises HDR capability. An
  [upstream report](https://github.com/hyprwm/Hyprland/discussions/16756)
  describes fullscreen mode blinks, but concerns different hardware and does not
  establish that this machine has the same fault.

Conclusion: compositor bypass is technically possible, but was not active in
this observed RuneScape session. VRR/frame-pacing or another output/driver issue
remains a hypothesis, not a diagnosis. No shell fix, permanent VRR change,
monitor-mode change, cursor-policy change, driver update or HDR change was applied.
A useful next controlled test requires physical observation: temporarily disable
VRR only for the affected game, compare foreground/background game frame limits,
and restore the original behavior. Test forced composition and auto-HDR separately
if needed; do not change all of them at once or rewrite monitor configuration.

Both launched RuneScape processes were terminated using exact PID/name identity
checks. Prior workspaces, active window and cursor were restored. Steam was left
open on workspace 4. Readback confirmed unchanged observed compositor options and
monitor modes, positions, transforms and scales. The issue remains unconfirmed;
these tests do not establish a resolution of the owner's reported flicker.

## Weather Settings keyboard/search polish — 2026-11-05

Weather Settings now uses the shared Settings search index and exact control IDs.
Search for Fahrenheit, refresh or postal location reveals and focuses the relevant
control instead of always jumping to the location input. Enable weather is indexed,
and keyboard selection stays within Weather's matching controls. The location
field is reachable with Tab and uses the shared accent focus outline. Enter and
the Search button now use identical minimum-length/busy validation, preventing
invalid or duplicate helper requests from keyboard submission.

The Weather QML suite passes 13 cases, including exact search focus, bounded
keyboard navigation and Enter/button validation. `scripts/check.sh` exits 0 with
29 QML suites / 221 passing QML cases and no QML warnings. The isolated native
`tests/live/settings-weather-navigation.py --live` passed on HDMI-A-1 and DP-1:
Fahrenheit, refresh, postal and enable-weather search all focused their exact
controls. Private preferences retained weather disabled and no location/network
request was made. No user compositor configuration or display settings changed.
Source backup: `/tmp/swiftshell-weather-navigation-backup`; revert this feature
commit for recovery. Real location-provider behavior was not retested because
this slice changes navigation and submission validation only.

## Scoped session-action repair — 2026-11-05

Lock previously emitted a logind request without a real locker; no locker was
installed/listening on the reference session. Logout was missing. Detached bar
commands hid subsequent failures, and Spotlight used a separate action path.
Decision 0049 documents the shared SessionActions/service helper and recovery.

The owner authorized installing the signed hyprlock 0.9.7-2.1 package; its resolved
transaction contained only that package and no dependency upgrade. User-authored
locker configuration takes precedence over the new bundled neutral fallback.
Credentials were not added to code, settings or files. No Hyprland Lua, monitor
mode, Noctalia, autostart or existing service configuration was edited.

`scripts/check.sh` passed: 128 production QML documents, 30 QML suites and 231 QML
cases, with no QML warning lines. `tests/test_sessionctl.py` passed 19 cases covering
lock acknowledgement/failure/timeout, suspend ordering and authorization, inhibitor
errors, current-compositor-only logout, known working reboot/poweroff routes,
validated session resolution, user-config precedence and dry-run safety.
`tests/live/session-actions.py --live` passed actual native QML/Process transport,
logout confirmation, one-click lock and shared Spotlight/bar refusal messages. The
private test helper deliberately cannot perform a real system action.

Production helper snapshot and `lock/suspend/logout --dry-run` succeeded on this
machine: active graphical session detected, locker present and CanSuspend=yes.
The zero-argument Lua exit dispatcher was checked against the installed Hyprland
0.57 source without executing it. Session-action availability/errors are included
in the existing read-only shell diagnostics. The dependency checker warns when
hyprlock is missing. Spotlight's action strip also passes a narrow-width bounds
regression with the added Log out button.

Actual lock/unlock, suspend/resume and logout were intentionally not triggered.
Acceptance: Lock should open the password screen immediately; Suspend → Confirm
Suspend should lock, then sleep; Log out → Confirm Log out should end this Hyprland
session and return to the greeter. If refused, the error should remain readable in
Power or Spotlight. No inhibitor override or forced session/user termination is used.
Source backup is `/tmp/swiftshell-session-actions-backup`; revert the feature commit
and restart only SwiftShell for code recovery. The installed locker can remain.

## Per-output wallpaper binding repair — 2026-11-05

A real SwiftShell cold start reproduced DP-1's saved file override with a ready
image whose source did **not** match the resolved configured URL; HDMI-A-1's
shared packaged image matched. Both background surfaces were attached to the
correct connectors. `onDisplayPathChanged` read `displaySource` before that
dependent QML binding updated, leaving the previous texture visible. Deferring
and coalescing the slot update with `Qt.callLater` resolves that binding race.
Read-only diagnostics now expose output/screen, override/fallback, decode readiness,
failure and URL equality without exposing image paths.

`scripts/check.sh` passed (128 production QML documents; 30 QML suites, 231 cases,
zero failures). `python tests/live/wallpaper-outputs.py --live` passed two native
Wayland cold starts on both connected monitors, distinct shared/per-output PNGs,
replacement and removal of an override. The same test against the old renderer
failed at initial source matching. This opt-in regression briefly creates owned
background surfaces; it uses isolated configuration/state/cache and removes its
surfaces on exit. It never changes user preferences, windows, modes or Lua files.

Recovery: revert this change and restart only SwiftShell. Source/preferences were
backed up under `/tmp/swiftshell-wallpaper-backup` before editing. No preference
migration is needed. Fullscreen games legitimately obscure wallpaper layers;
the regression checks each surface's actual screen and image state independently.
Actual reboot remains untested; two process cold starts are verified.

After activating the repair by a scoped SwiftShell restart, actual user-state
readback showed DP-1 override=true, fallback=false, ready=true,
sourceMatches=true; HDMI-A-1 shared packaged source ready=true,
sourceMatches=true. Wallpaper preferences remained identical to the backup.
Runtime logs contained no TypeError, ReferenceError, binding loop or wallpaper
surface diagnostics. Development source watching was restored.

## Wallpaper hidden after fullscreen startup — 2026-11-05

Follow-up visual inspection found a second defect independent of the image URL
binding race: DP-1 showed Hyprland's blue droplet wallpaper, even though its correct
red/black image had decoded. After switching from the existing fullscreen game to
empty workspace 1, `hyprctl -j layers` still reported SwiftShell's background at
alpha=0. The previous source/readiness checks therefore did not establish visual
success.

The installed Hyprland revision `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426`
initializes a layer's fade alpha to zero and skips `animateIn()` in `onMap()` when
its output already contains fullscreen; background layers do not subsequently
receive the top-layer fullscreen restoration. Verified against
[LayerSurface.cpp](https://github.com/hyprwm/Hyprland/blob/0aa6745f705f2c4b0a5004eb019ef76e5bbdb426/src/desktop/view/LayerSurface.cpp).
SwiftShell now waits for monitor discovery and a non-fullscreen desktop before
first mapping each wallpaper surface. Once admitted, the surface stays mapped;
ordinary workspace/game transitions do not recreate it. No compositor rule,
user-authored configuration or display mode is changed.

`python tests/live/wallpaper-outputs.py --live --fullscreen-output DP-1
--desktop-workspace 1` passes two native cold starts while the existing game is
fullscreen. It requires an existing empty desktop workspace on the same output,
checks initial deferred mapping, switches briefly to that workspace, checks the
owned native layer reaches compositor alpha=1, and restores original workspace
and focus in cleanup. Image replacement/shared fallback regressions remain active.
The fixture cannot prove its pixels are topmost over an already running wallpaper
owner; an attempted pixel assertion was removed because background stacking made
that assumption false.

Separately, production SwiftShell was restarted while RuneScape was fullscreen.
The DP-1 background correctly waited unmapped, then mapped at alpha=1 on workspace
1. A real DP-1 screenshot was inspected and visibly showed the intended red/black
woman-with-rifle wallpaper. Gaming and HDMI focus were restored. This verifies the
actual visible image, not only decoded-source equality. Backup:
`/tmp/swiftshell-wallpaper-fullscreen-backup`. Recovery: revert this slice and
restart only SwiftShell. Reboot remains untested.

Final validation: `scripts/check.sh` passed all static/logic/helper checks and
30 QML suites / 231 cases. Native fullscreen-startup regression passed again after
cleanup hardening. Production runtime had zero TypeError, ReferenceError, binding
loop and configuration-load failures; source watching was restored.

## Fullscreen peek layer commit — 2026-11-05

The saved fullscreen peek option was off. Preferences were backed up to
`/tmp/swiftshell-before-enabling-fullscreen-peek.json`, then enabled atomically.
A real DP-1 test exposed a second failure: peek=true while the native bar remained
on layer 2 at alpha=0. Quickshell 0.3.2 queues layer changes until a surface commit;
a fullscreen-hidden surface can remain frame-throttled. Versioned implementation:
https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/wlr_layershell/surface.cpp

BarWindow now briefly unmaps/remaps only its own surface when peek changes, which
commits the requested layer on mapping. Its QML controller remains alive. No
permanent overlay, compositor rule, display mode or user Lua edit is involved.
Source backup: `/tmp/swiftshell-peek-backup`. Revert this slice and restart only
SwiftShell for recovery; disabling fullscreen peek stops edge sampling.

After a scoped restart, actual DP-1 hover reached layer 3 / alpha=1. Screenshots
visibly showed the bar over RuneScape and absent again after leaving the edge.
Pointer/focus were restored, and the owner subsequently confirmed it works.
Layer 2 alpha alone cannot prove hidden state; Hyprland can omit that layer above
fullscreen even with alpha=1.

`python tests/live/bar-fullscreen.py --live --allow-active-game` passed: owned
HDMI-only fullscreen client, private cursor samples, native fullscreen metadata,
visible overlay alpha=1, stable dimensions, return below fullscreen and Clock
popout dismissal. The explicit flag retains the default gaming safety gate.
The regression now tolerates intended remap gaps and verifies actual compositor
visibility rather than requiring the same native surface. `scripts/check.sh`
passed all checks, including 30 QML suites / 231 cases. No real game input or
Noctalia changes were made.

## Persistent Capture alongside Spotlight — 2026-11-05

Capture previously used an exclusive keyboard grab, closed on focus-grab loss and
closed on outside clicks. Starting acquisition also globally dismissed Spotlight,
overview and bar panels, making screenshots of those surfaces impossible.
ScreenshotWindow now accepts input only within its card, uses on-demand keyboard
focus and remains open until explicit Close/Escape. Spotlight's focus grab accepts
the visible Capture window as a companion, so operating Capture does not dismiss
the target. Acquisition hides only Capture itself and returns it afterward; the
global target-panel dismissal connection was removed.

`scripts/check.sh` passed all checks, 30 QML suites / 231 cases. Extended
`python tests/live/screenshot-review.py --live` passed on HDMI-A-1 and DP-1:
Capture survives opening/closing real Spotlight with keyboard focus, capture leaves
Spotlight open, preview loads, private PNG clipboard transport works and native
Save As exports a real PNG. These tests use owned opaque checkerboard surfaces,
isolated preferences and a private clipboard sink; desktop clipboard is unchanged.
A root-wiring static regression prevents acquisition from closing target panels.

The tested change was activated with a scoped SwiftShell restart. Production logs
showed no TypeError, ReferenceError, binding loop, configuration-load or Capture
surface errors. Source watching was restored. User preferences, compositor config,
Noctalia, modes and autostart were unchanged. Physical user acceptance: open Capture,
set a delay, start it, open Spotlight and verify Spotlight appears in the resulting
image. The native regression checks Spotlight lifetime and owned-region acquisition,
not a manual user's region selection of Spotlight pixels.

Recovery: revert this feature commit and restart only SwiftShell. Source backup:
`/tmp/swiftshell-capture-persistence-backup`.

## System login-screen semantics — 2026-11-06

The owner rejected Hyprlock and explicitly requested that Lock sign out to the
boot login screen, and Suspend sleep with that login screen on wake. Decision
0050 supersedes 0049. Lock/Log out now exit only the validated current Hyprland
session. Suspend uses a real logind sleep-delay inhibitor: request sleep while
authorization is available, wait for PreparingForSleep, finish this compositor,
then release the delay. Both actions explain that apps close and require
confirmation. SwiftShell no longer starts Hyprlock or supplies a password screen.

Read-only probes verified active Plasma Login 6.8.2 and its DisplayManager/Seat0
interfaces, valid current graphical session, available logind capabilities, actual
JSON boolean/seat property formats, and autologin/relogin off. `lock --dry-run` and
`suspend --dry-run` report the new routes. A harmless `systemd-inhibit --what=sleep
--mode=delay ... /usr/bin/true` successfully acquired/released an inhibitor without
sleeping. No existing service, user Lua, PAM, Noctalia or display configuration was
edited, and no package was removed or installed.

`scripts/check.sh` passed: 128 QML files, 30 QML suites / 231 cases. Python session
helper tests: 21 passing cases, including sign-out without any locker, sleep
acceptance ordering, denial/timeout without sign-out, compositor-exit wait and
validated-session-only termination fallback. Native `tests/live/session-actions.py
--live` passed Power/Spotlight confirmations and shared refusal/busy/error reporting
with an isolated helper that cannot perform any real session action.

Actual logout, greeter arrival, physical sleep and resume were not triggered.
Owner acceptance: save work; Lock → Confirm Lock should end apps and show Plasma
Login. After logging in, save work; Suspend → Confirm Suspend should end apps and
sleep; wake should show Plasma Login. No separate SwiftShell/Hyprlock password UI
should appear. Failed pre-sleep authorization should leave the desktop open.
Recovery: revert this slice and restart only SwiftShell; backup is
`/tmp/swiftshell-greeter-actions-backup`.

Activated through a scoped SwiftShell restart. Production SessionActions snapshot
reports all five actions available, ready=true, no error; settings persistence is
ready. Runtime logs have no TypeError, ReferenceError, binding loop or load failure.
Development file watching restored. No live session-ending or sleep action ran.

## Non-locking Hyprlock authentication probe — 2026-11-06

The owner requested restoring Hyprlock, contingent on safely testing the password
failure. `scripts/test-hyprlock-auth.py` opens a local password dialog and calls the
actual current user's `hyprlock` PAM service with pam_start/pam_authenticate/pam_end,
matching Hyprlock's authentication API. It never launches a locker or opens a PAM
session. One attempt per invocation prevents automatic retry loops; ordinary PAM
failed-attempt policy still applies. Password input stays local/in memory; stdout
contains only service, authenticated boolean and PAM code, never prompt contents
or password. It does not accept credentials via command arguments or environment.

Read-only checks: current faillock tally empty, login shell listed in /etc/shells,
installed Hyprlock 0.9.7 PAM profile includes login/system-local-login/system-login/
system-auth. Both actual SwiftShell and the test process have NoNewPrivs=0 and
Seccomp=0; unix_chkpwd retains packaged privileged permissions. No PAM files or
account policies were modified. These checks do not prove password acceptance.

The native test window was launched and moved/focused on HDMI-A-1 so it would not
be obscured by the DP-1 game. At this checkpoint it is awaiting the owner's local
password entry; no authentication result has been reported and no lock was taken.
Hyprlock restoration was prepared and passed scripts/check.sh (231 QML cases),
19 backend tests and native isolated session-action routing, but was then held
outside the active tree pending real PAM success. Prepared patch/config:
/tmp/swiftshell-hyprlock-prepared.patch and /tmp/swiftshell-hyprlock-prepared.conf.
The current committed session controls remain unchanged. Do not claim the original
password rejection is diagnosed or that restored Hyprlock is activated yet.

## Verified PAM success and Hyprlock restoration — 2026-11-06

The local non-locking password test returned exactly:
`{"authenticated":true,"pamCode":0,"service":"hyprlock"}`.
The owner separately confirmed the test passed. This tests the real current user's
PAM service, not a mock password comparison. Password data was not sent through
commands, stdout, files or environment variables. The prepared restoration was
applied only after this result. Decision 0051 supersedes the sign-out semantics
of 0050: Lock preserves apps behind Hyprlock, Suspend securely locks before sleep,
and Log out returns to the boot greeter and closes apps. Power/Spotlight explain
these differences; the dependency warning and bundled neutral fallback are back.

The earlier password rejection's cause is still unproven; no PAM/account settings
were changed to make this test pass. Actual lock-screen input, unlocking and
physical sleep/resume are not established by a successful pam_authenticate call.
No real lock or sleep action was triggered by the agent. Recovery information is
in decision 0051; source backups remain in /tmp/swiftshell-hyprlock-restore-backup.

Restoration validation: scripts/check.sh passed (128 QML files; 30 QML suites,
231 cases), 19 session helper tests and the native isolated session-action fixture
passed. Non-disruptive dry runs report hyprlock / locked-logind-suspend routes.
Activated by restarting only SwiftShell; live actions are ready/available without
error, persistence ready, and no TypeError/ReferenceError/binding-loop/load failures
appear in runtime logs. Source watching restored. No actual lock or sleep was run.

## Hidden fullscreen bar does not intercept input — 2026-11-06

The native bar previously stayed mapped below fullscreen when peek closed.
Compositor invisibility is not a reliable input boundary. BarWindow now binds
native visibility to non-fullscreen or visible peek, with the existing brief
layer-binding settle before reveal. The QML controller and optional edge watcher
stay alive while the native window is unmapped. No invisible hit area remains;
normal desktop mapping returns automatically when leaving fullscreen. Input state
is exposed in path-free rendering diagnostics.

`python tests/live/bar-fullscreen.py --live --allow-active-game --input-check`
passed on the actual mixed-scale HDMI output with an owned fullscreen client:
initially no native bar surface, real click at the bar's position delivered to the
client; visible overlay at alpha=1, real Clock click delivered to the bar rather
than the client; hide again removes the surface and restores client clicks;
leaving fullscreen restores the normal interactive bar. Popout dismissal and
stable dimensions also pass. Virtual input is restricted to the owned HDMI client
and its bar; no game click/key was sent. Pointer and monitor focus are restored,
and the owned process/rule are cleaned up even if a check fails.

The test uses compositor-reported bar geometry and disables only its private bar's
space reservation to avoid stacking beneath the running bar. An earlier reveal
assertion clicked the wrong vertical position due to that stacking; this was a
test error, not evidence of a product click-delivery defect. Pointer-movement
safety checks refused gestures during user motion; the final click test ran after
the owner confirmed the pointer could remain still. The private cursor helper
still controls reveal intent without moving the real pointer to the game edge.

`scripts/check.sh` passed (128 QML files, 30 QML suites / 231 cases). Production
SwiftShell was restarted by config path. Live diagnostics: DP-1 fullscreen=true,
peek=false, acceptsInput=false, edge watcher active; `hyprctl -j layers` contains
no DP-1 SwiftShell bar. HDMI retains its layer-2 normal bar and acceptsInput=true.
Runtime logs show no TypeError, ReferenceError, binding loop or load failure.
The current compositor reports Hyprland 0.57.1. Source watching was restored.
No preference, monitor mode, user Lua, Noctalia or existing service changes.

Recovery: revert this feature commit and restart only SwiftShell. Source/test
backup: `/tmp/swiftshell-hidden-bar-input-backup`. Owner acceptance: click game
controls near the hidden bar, then deliberately dwell at the edge and confirm the
revealed bar responds; moving away should return all clicks to the game.
