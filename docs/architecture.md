# Architecture

SwiftShell's M0/M1 prototype is a Quickshell configuration that draws one transparent bar. It is launched from this repository and does not replace Noctalia or edit the Hyprland configuration.

## Boundaries

| Module | Owns | Does not own |
|---|---|---|
| `shell/themes` | Colors, bar height, spacing, type size | Wallpaper sampling, blur, popovers |
| `shell/components` | Shared text styling | Feature behavior |
| `shell/bar` | Bar window, workspace indicators, clock, focused title | Screen reservation policy beyond the settings flag |
| `shell/services/HyprlandModel.qml` | Hyprland workspace, monitor, and toplevel snapshots; workspace activation | Hyprland config files, binds, window decorations |
| `shell/services/SettingsStore.qml` | Versioned JSON preferences | Hyprland and Noctalia settings |
| `shell/logic` | Pure functions for time, monitor match, workspace state, settings validation | Qt or Quickshell objects |

UI files read service snapshots and theme tokens. They do not call `hyprctl` and they do not parse Lua.

```text
shell/shell.qml
  BarHost
    one PanelWindow per matching screen
      WorkspaceIndicators
      FocusedTitle
      ClockModule
  SettingsStore
  HyprlandModel
```

## Theme

`Theme.qml` is a QML singleton. The bar is 28 logical pixels tall. Logical pixels are Quickshell's coordinate system; the prototype does not multiply sizes by `devicePixelRatio`. Text uses the application font so a missing family does not fail the load. The bar color is fully transparent. There is no background rectangle and no top-edge gradient in this milestone.

Active workspace state is a brighter weight plus a 1px mark. Inactive text is muted. Urgent workspaces use the primary text color and stay monochrome.

## Monitors and scale

`BarHost` asks Quickshell for the current screen list and creates a window only when `monitors.js` matches the configured connector. The default connector is `HDMI-A-1`. A match succeeds when the Shell screen name or the Hyprland monitor name from `Hyprland.monitorFor` equals that connector. Unmatched screens, including DP-1, get no window. An empty match logs a warning and creates no bar. Connecting or disconnecting a screen changes `Quickshell.screens`, and `Variants` creates or destroys the window.

Fractional scale is left to the compositor. Layout values are logical pixels.

## Hyprland

`HyprlandModel` reads `Hyprland.workspaces`, `Hyprland.monitors`, and `Hyprland.toplevels`. QML property notifications drive the bar. There is no workspace timer. One refresh runs when the event socket becomes available so the first frame can catch up with state that arrived before the shell subscribed.

Workspace clicks call `HyprlandWorkspace.activate()` when that workspace object already exists. Otherwise the shell sends one IPC request, `workspace <id>`, through `Hyprland.dispatch`. That request is written to Hyprland's socket. It does not run a shell and it does not rewrite `binds.lua`, `monitors.lua`, or `decorations.lua`.

The highlighted workspace is the one active on the bar's monitor. A workspace that is active on another monitor stays unhighlighted. Indicators for workspaces 4, 5, and 6 are still shown when Hyprland has not created them yet.

The focused-title text is the activated toplevel on the bar's monitor. If none is activated, the title of a toplevel on that monitor's active workspace is used. Other monitors are ignored. An empty title hides the module.

If the Hyprland socket is absent, the indicators render inactive and clicks log a warning.

## Settings

Preferences live in `$XDG_CONFIG_HOME/swiftshell/settings.json`, which is `~/.config/swiftshell/settings.json` when `XDG_CONFIG_HOME` is unset. That directory is separate from `~/.config/quickshell` and from Noctalia.

`scripts/launch.sh` creates the directory and copies `shell/config/defaults.json` only when the file is missing. `SettingsStore` loads it with Quickshell `FileView` and `JsonAdapter`. `atomicWrites` stays enabled. A missing or unreadable file keeps the built-in defaults and does not overwrite an existing file. Unknown JSON keys are not preserved across a later adapter write; the M1 schema is the whole file.

`shell/logic/settings.js` is the validation contract. The settings GUI does not exist yet. Edit the JSON file, and a running shell reloads it because `watchChanges` is on.

| Key | Default | Effect |
|---|---|---|
| `clock.use24Hour` | `true` | `09:04` or `9:04 AM` |
| `bar.targetMonitor` | `HDMI-A-1` | Connector that receives the bar |
| `bar.workspaceIds` | `[4, 5, 6]` | Indicator order, maximum 12 ids |
| `bar.showFocusedTitle` | `true` | Hides the center title when false |
| `bar.reserveSpace` | `false` | When true, reserves the bar height on that output |

`reserveSpace` defaults off so a preview does not take the output's exclusive zone while Noctalia is still running. Quickshell treats `ExclusionMode.Auto` as a reservation, so the window sets `ExclusionMode.Ignore` unless reservation is enabled. Enabling reservation assigns `exclusiveZone` to the bar height, which is the Quickshell operation that switches the zone mode to normal.

## Process identity

`shell/shell.qml` sets Quickshell shell id `swiftshell`. Launch and stop use `qs --path` pointed at this checkout's `shell` directory. Stop does not select Noctalia.

## Dependencies

Runtime: Quickshell with the Hyprland and layer-shell modules, Qt 6 Quick, Qt 6 Quick Layouts, and Qt 6 Core (`StandardPaths`). No npm packages and no vendored Quickshell.

Installed files live under `$XDG_DATA_HOME/swiftshell`. Settings live under `$XDG_CONFIG_HOME/swiftshell`. `./install.sh` copies the app and launcher. `swiftshell activate` registers a free Quickshell name and a desktop entry. Those commands do not edit Hyprland startup, shortcuts, or service units. See `docs/install.md`.

Test-only: Node for `tests/logic.test.js`, Python 3 for `tests/static_check.py`, and a POSIX shell for `tests/install_flow.sh`. None of these are required to run the shell.

## Decision

The safe preview behavior is recorded in `docs/decisions/0001-m0-m1-boundaries.md`. The install boundaries are recorded in `docs/decisions/0002-install-boundaries.md`.
