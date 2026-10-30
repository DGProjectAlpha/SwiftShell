# Architecture

SwiftShell's M0/M1 prototype is a Quickshell configuration that draws one transparent bar. It is launched from this repository and does not replace Noctalia or edit the Hyprland configuration.

## Boundaries

| Module | Owns | Does not own |
|---|---|---|
| `shell/themes` | Shared colors, type, spacing, motion, panel tokens | Wallpaper sampling |
| `shell/components` | Shared text, flat buttons, slider, status rows | Service calls |
| `shell/bar` | Bar window, workspace indicators, clock, focused title, control mark | Screen reservation policy beyond the settings flag |
| `shell/popovers` | Popup window, calendar, control center | Hyprland config, notification ownership, network management |
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
      ControlIndicator
      PopoverHost
        CalendarPanel
        ControlCenterPanel
          AudioSection
  SettingsStore
  HyprlandModel
```

## Theme

`Theme.qml` is a QML singleton. Every bar and panel color, size, and duration comes from it. The bar is 28 logical pixels tall. Logical pixels are Quickshell's coordinate system; the prototype does not multiply sizes by `devicePixelRatio`. Text uses the application font so a missing family does not fail the load. The bar color is fully transparent. `appearance.topGradient` defaults to false. When it is true, a vertical fade is drawn inside that 28px window only. It is not a second surface and it does not extend into the wallpaper below the bar.

Panel color, opacity, radius, shadow, type size, icon scale, and motion come from `appearance` in the settings file. `shell/logic/palette.js` resolves `dark` and `light`. `tint: "wallpaper"` stores the request and keeps the neutral palette. The provider returns `adaptive: false` and the sentence "Wallpaper tint is not sampled yet." Nothing in this milestone reads the wallpaper.

Active workspace state is a brighter weight plus a 1px mark. Inactive text is muted. Urgent workspaces use the primary text color and stay monochrome.

## Monitors and scale

`BarHost` is a Quickshell `Scope`. `Variants` is a child of that scope. `BarHost` asks Quickshell for the current screen list and creates a window only when `monitors.js` matches the configured connector. The default connector is `HDMI-A-1`. A match succeeds when the Shell screen name or the Hyprland monitor name from `Hyprland.monitorFor` equals that connector. Unmatched screens, including DP-1, get no window. An empty match logs a warning and creates no bar. Connecting or disconnecting a screen changes `Quickshell.screens`, and `Variants` creates or destroys the window.

Fractional scale is left to the compositor. Layout values are logical pixels.

## Hyprland

`HyprlandModel` reads `Hyprland.workspaces`, `Hyprland.monitors`, and `Hyprland.toplevels`. QML property notifications drive the bar. There is no workspace timer. One refresh runs when the event socket becomes available so the first frame can catch up with state that arrived before the shell subscribed.

Workspace clicks call `HyprlandWorkspace.activate()` when that workspace object already exists. Otherwise the shell sends one IPC request, `workspace <id>`, through `Hyprland.dispatch`. That request is written to Hyprland's socket. It does not run a shell and it does not rewrite `binds.lua`, `monitors.lua`, or `decorations.lua`.

The highlighted workspace is the one active on the bar's monitor. A workspace that is active on another monitor stays unhighlighted. Indicators for workspaces 4, 5, and 6 are still shown when Hyprland has not created them yet.

The focused-title text is the activated toplevel on the bar's monitor. If none is activated, the title of a toplevel on that monitor's active workspace is used. Other monitors are ignored. An empty title hides the module.

If the Hyprland socket is absent, the indicators render inactive and clicks log a warning.

## Panels

Each bar window owns one `PopoverHost`. Opening the clock closes the control center on that monitor, and the reverse. The host is a `PopupWindow` anchored to the clicked item. `shell/logic/popover.js` places the top-left corner in logical pixels and keeps it inside the screen margin. `PopupAdjustment.Flip` and `PopupAdjustment.Slide` are also set so the compositor can move the popup if the shell's rectangle is still outside the output.

The popup window color is transparent and `surfaceFormat.opaque` is false, so the surface can blend. The visible card is a separate rectangle using the theme scrim. A flat translucent rectangle sits behind that card. It is not a sampled shadow.

`BackgroundEffect` is not referenced as a QML type, because Quickshell 0.2.0 does not provide it. On open, the host looks up the attached object dynamically and, when it exists, sets its blur region to the popup content. If the lookup fails, the scrim stays and one warning is logged. Alpha on the scrim is not blur.

Dismissal uses `HyprlandFocusGrab` from Quickshell 0.2. A click outside the popup clears the grab and closes the panel. Escape closes it when the popup has keyboard focus. The same bar control toggles the panel without a global shortcut. The grab is released when the panel closes. The popup does not set an exclusive zone.

Open animation is 180ms and close is 120ms at motion scale 1, with a 4px move and an opacity fade. `appearance.reducedMotion` or a motion scale of 0 removes both. Hover color changes take 80ms unless motion is reduced.

The calendar draws the requested month, highlights today with weight and a 1px mark, and moves by month. "Today" returns to the clock's month. Week numbers are ISO weeks and stay hidden until the panel's week-number control turns them on. The first column follows `clock.weekStart`: `locale` uses `Qt.locale().firstDayOfWeek`, and `monday` or `sunday` override it. Day cells are text. They do not pretend to select an event.

The control center's live control is the default PipeWire sink. `AudioSection.qml` binds that node with `PwObjectTracker` and writes `audio.volume` and `audio.muted`. Raising the volume above zero unmutes. A missing PipeWire module or sink leaves the row labeled Unavailable. Network, Bluetooth, brightness, media, Do Not Disturb, and power are status text, not buttons. Settings text points at the JSON file. Dark, light, motion, and the top gradient are real preference writes.

## Settings

Preferences live in `$XDG_CONFIG_HOME/swiftshell/settings.json`, which is `~/.config/swiftshell/settings.json` when `XDG_CONFIG_HOME` is unset. That directory is separate from `~/.config/quickshell` and from Noctalia.

`scripts/launch.sh` creates the directory and copies `shell/config/defaults.json` only when the file is missing. `SettingsStore` is a Quickshell `Singleton` and loads the file with `FileView` and `JsonAdapter`. `atomicWrites` stays enabled. A missing or unreadable file keeps the built-in defaults and does not overwrite an existing file. Unknown JSON keys are not preserved across a later adapter write. The settings schema is the whole file. Missing `appearance` or calendar keys keep the defaults.

`shell/logic/settings.js` is the validation contract. The settings GUI does not exist yet. Edit the JSON file, and a running shell reloads it because `watchChanges` is on.

| Key | Default | Effect |
|---|---|---|
| `clock.use24Hour` | `true` | `09:04` or `9:04 AM` |
| `clock.showWeekNumbers` | `false` | ISO week numbers in the calendar |
| `clock.weekStart` | `locale` | `locale`, `monday`, or `sunday` |
| `bar.targetMonitor` | `HDMI-A-1` | Connector that receives the bar |
| `bar.workspaceIds` | `[4, 5, 6]` | Indicator order, maximum 12 ids |
| `bar.showFocusedTitle` | `true` | Hides the center title when false |
| `bar.reserveSpace` | `false` | When true, reserves the bar height on that output |
| `appearance.mode` | `dark` | `dark` or `light` text and panel palette |
| `appearance.tint` | `neutral` | `wallpaper` is stored and not sampled |
| `appearance.panelOpacity` | `0.92` | Scrim strength, clamped from 0.72 to 0.96 |
| `appearance.panelBlur` | `1` | Requests blur when the protocol exists; `0` skips it |
| `appearance.topGradient` | `false` | Faint fade inside the bar window |
| `appearance.reducedMotion` | `false` | Removes panel and hover animation |
| `appearance.motionScale` | `1` | Scales the 180ms / 120ms / 80ms durations, from 0 to 1 |

`reserveSpace` defaults off so a preview does not take the output's exclusive zone while Noctalia is still running. Quickshell treats `ExclusionMode.Auto` as a reservation, so the window sets `ExclusionMode.Ignore` unless reservation is enabled. Enabling reservation assigns `exclusiveZone` to the bar height, which is the Quickshell operation that switches the zone mode to normal.

## Process identity

`shell/shell.qml` sets Quickshell shell id `swiftshell`. Launch and stop use `qs --path` pointed at this checkout's `shell` directory. Stop does not select Noctalia.

## Dependencies

Runtime: Quickshell with the Hyprland, layer-shell, and PipeWire modules, Qt 6 Quick, Qt 6 Quick Layouts, and Qt 6 Core (`StandardPaths`). A Quickshell build without PipeWire still loads the bar; the audio block shows Unavailable. No npm packages and no vendored Quickshell.

Installed files live under `$XDG_DATA_HOME/swiftshell`. Settings live under `$XDG_CONFIG_HOME/swiftshell`. `./install.sh` copies the app and launcher. `swiftshell activate` registers a free Quickshell name and a desktop entry. Those commands do not edit Hyprland startup, shortcuts, or service units. See `docs/install.md`.

Test-only: Node for `tests/logic.test.js`, Python 3 for `tests/static_check.py`, and a POSIX shell for `tests/install_flow.sh`. None of these are required to run the shell.

## Decision

The safe preview behavior is recorded in `docs/decisions/0001-m0-m1-boundaries.md`. The install boundaries are recorded in `docs/decisions/0002-install-boundaries.md`. The panel boundaries are recorded in `docs/decisions/0003-m2-panels.md`.
