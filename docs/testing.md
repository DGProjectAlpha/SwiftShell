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
4. Change dark, light, text size, text weight, density, panel opacity, corner radius, shadow, icon scale, motion scale, reduced motion, and the top gradient. The bar, Spotlight, and the settings window should follow without a restart. Restart with `scripts/stop.sh` and `scripts/launch.sh` and confirm the same values. Undo should restore the previous values. Reset should restore the appearance defaults. There is no blur slider. Wallpaper tint should say it is not sampled. Search should hide controls that do not match, and Escape in a filled search field should clear it before the next Escape closes the window.
5. Confirm `~/.config/hypr` and the Noctalia config are unchanged.
6. Open Settings, Top bar. Set the height to 22 and to 52. The text, workspace marks, and reserved strip should follow. Hide Clock and move Search earlier. Restart and confirm the order. Set the height back to 28.
7. Open Settings, Wallpaper. The preview should show the crimson image. Choose a png, or type its path, and confirm Cover crops and Contain shows the whole picture on each output. Point one output at a different file and restart. Remove that file and confirm the crimson image returns. Turn Draw wallpaper off and confirm another wallpaper program is still running. `~/.config/hypr` must stay unchanged.
8. Add two png files to the slideshow, set the fade to 400, and confirm the pictures crossfade and the second one is not the same as the first when shuffle is on. Turn on automatic text on the crimson image and on a white png. Text should be light on the crimson image and dark on the white one. A black-and-white split should show the bar fade. Turn automatic text off and confirm a manual hex color remains. A jpeg should still display and should say it is not sampled.
9. Open Settings, Displays. The rectangles should match the connected outputs, including a portrait or a negative position if one is connected. Dragging should move only the preview. Apply stays unavailable. `~/.config/hypr` must stay unchanged.
10. Open Settings, Shortcuts. Record Super+Z for Settings, press Enter, and confirm the row shows Super+Z after a restart. Press Escape while listening and confirm nothing is stored. Record the same chord on Control center and confirm it is refused. The compositor's own binds, including Super+Space, must be unchanged.

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
