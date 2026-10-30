# Testing

The cloud environment used to add this prototype has no Hyprland session, no monitors, and no Noctalia installation. Checks here cover logic, source structure, and the installer in a temporary home directory. They do not show pixels.

## Commands

From the repository root:

```sh
python3 tests/static_check.py
node tests/logic.test.js
sh tests/install_flow.sh
```

Or all three:

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
- palette contrast for the dark and light scrims, including the unsampled wallpaper tint
- motion durations and reduced motion
- calendar month grids, locale week start, and ISO week numbers
- popup placement in logical pixels, including a 1.5 scale screen size
- one open popover id at a time
- audio volume clamping, unmute behavior, and output labels

`tests/static_check.py` checks that the QML files exist, local imports resolve, braces and parentheses balance, and the tree does not spawn `hyprctl`, a `Timer`, or a `Process`. It rejects a QML object nested directly in `QtObject`, which has no default property, including through a component whose root type is `QtObject`. Property values such as `property Item child: Item {}` are allowed. It also checks the transparent color, 28px token, HDMI-A-1 default, shell id, `Scope` bar host, `Singleton` service roots, the transparent popup surface, and that wallpaper sampling is not claimed. Shell scripts are scanned for edits to Hyprland config, service units, and package installation outside the explicit Arch dependency path.

`tests/install_flow.sh` runs `./install.sh`, activation, deactivation, and uninstallation in a temporary `HOME` with stub `qs` and `Hyprland` commands. It checks that a second install keeps settings, that occupied config names and foreign launchers are refused, and that Hyprland and other shell files in that temporary home stay unchanged. Stop is checked twice: a stub whose help lists `--any-display` must receive that flag, and a stub that matches Quickshell 0.2.0 must be stopped with `kill --path` alone. It does not install packages and it does not open a Wayland session.

## What was run for this change

On 30 Oct 2026 (America/New_York), in the cloud workspace, with no Hyprland session:

```text
python3 tests/static_check.py
node tests/logic.test.js
sh tests/install_flow.sh
```

Node was v22.23.4 and Python was 3.12.3. Static checks passed for 20 QML files, including the nesting fixtures and the real `Scope` / `Singleton` roots. Logic tests passed, including calendar, placement, theme contrast, popover state, and audio commands. Install tests passed, including the Quickshell 0.2 stop path that must not pass `--any-display`, and a failed `qs kill` that must still print the miss warning. `qmllint`, `qml`, and `qs` are not installed here, so Qt did not parse the QML and the CLI probe was not run against a real Quickshell binary. The shell was not launched. Blur, focus grab, fractional-scale placement, PipeWire volume, and panel animation were not seen on a compositor.

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
- The popup stays inside the HDMI-A-1 output at scale 1.5, and the scrim stays readable on the real wallpaper.
- `BackgroundEffect` either attaches or the warning is logged once. The blur itself was not observed.
- PipeWire reports the default sink and accepts volume and mute writes.
- Escape and an outside click close the panel without leaving a focus grab behind.
- The optional top gradient remains inside the bar and does not steal clicks from windows below it.
- `WlrLayershell.namespace` parses on the installed Quickshell. The 0.2 page documents that property and says it must be set before the layer surface connects.
- `qs kill --help` on the installed binary matches the 0.2.0 parser or the later `--any-display` flag. The probe was tested with stubs only.

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
