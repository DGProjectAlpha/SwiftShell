# Testing

The cloud environment used to add this prototype has no Hyprland session, no monitors, and no Noctalia installation. Checks here cover logic and source structure. They do not show pixels.

## Commands

From the repository root:

```sh
python3 tests/static_check.py
node tests/logic.test.js
```

Or both:

```sh
scripts/check.sh
```

`scripts/check.sh` expects `node` and `python3` on `PATH`.

## What the checks cover

`tests/logic.test.js` exercises the plain JavaScript used by the QML:

- 12-hour and 24-hour formatting, including midnight and an invalid date
- connector matching for `HDMI-A-1`
- workspace fallback to 4, 5, and 6
- active highlighting only when the workspace is on the bar's monitor
- focused-title selection
- settings validation, repair, and the defaults file

`tests/static_check.py` checks that the QML files exist, local imports resolve, braces and parentheses balance, and the tree does not spawn `hyprctl`, a `Timer`, or a `Process`. It also checks the transparent color, 28px token, HDMI-A-1 default, and shell id.

## What was run for this change

On 30 Oct 2026, in the cloud workspace, with no Hyprland session:

```text
python3 tests/static_check.py
node tests/logic.test.js
```

Node was v22.23.4 and Python was 3.12.3. Static checks passed for 10 QML files. Logic tests passed. `qmllint` is not installed here, so Qt did not parse the QML. The shell was not launched.

## What these checks do not prove

- The bar is transparent on a real wallpaper.
- Text remains readable at 1.0 and 1.5 scale.
- `HDMI-A-1` matches the Qt screen name on the target machine.
- Hyprland IPC accepts `workspace 4` through the installed Quickshell build.
- Hotplug destroys and recreates the window.
- `reserveSpace: false` leaves Noctalia's exclusive zone unchanged.
- The shell exits without taking Hyprland down.

Those need the CachyOS session. Do not mark them passed from a cloud log.

## Install, launch, and stop on CachyOS

1. Install Quickshell with the Hyprland module using the distro package. This repository does not install it. On CachyOS the package name is `quickshell`.
2. Leave Noctalia and the existing Hyprland config in place.
3. From this checkout, run `scripts/launch.sh`.
4. The script creates `$XDG_CONFIG_HOME/swiftshell` (or `~/.config/swiftshell`) and copies default settings only if that file is absent.
5. Quickshell is started as `qs --path <checkout>/shell --no-duplicate`. The process stays in that terminal. Ctrl-C stops it.
6. `scripts/stop.sh` runs `qs kill --path <checkout>/shell --any-display`. That path is this prototype, not Noctalia's config.

If stop cannot find the instance:

```sh
qs list --all
qs kill --id <instance-id>
```

Read the instance id from `qs list` before killing anything. A blanket process kill can stop Noctalia.

To reserve space for maximized windows on HDMI-A-1, set `bar.reserveSpace` to `true` in the settings file and restart the prototype. Leave it `false` while Noctalia is also drawing on that output.

Clock format is `clock.use24Hour` in the same file. `true` prints `09:04`. `false` prints `9:04 AM`.

## Recovery

Stopping SwiftShell releases its layer surface. This milestone does not write Hyprland or Noctalia files, so there is no compositor config to roll back. If a bar remains after stop, run `qs list --all` and kill only the instance whose config path is this checkout's `shell/shell.qml`.
