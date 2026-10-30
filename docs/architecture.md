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

`BarHost` is a Quickshell `Scope`. `Variants` is a child of that scope. `targetScreens` is a plain list, not a binding. `refreshTargetScreens()` fills it when the component is completed, when `Quickshell.screens` changes, when the target monitor setting changes, and when `HyprlandModel` finishes a monitor refresh. The list is replaced only when the matched screen objects change, so reading Hyprland monitor names while a bar window is created does not re-enter the property. The default connector is `HDMI-A-1`. A match succeeds when the Shell screen name or the Hyprland monitor name from `Hyprland.monitorFor` equals that connector. Unmatched screens, including DP-1, get no window. An empty match logs one warning and creates no bar.

Fractional scale is left to the compositor. Layout values are logical pixels.

## Hyprland

`HyprlandModel` reads `Hyprland.workspaces`, `Hyprland.monitors`, and `Hyprland.toplevels`. QML property notifications drive the bar. There is no workspace timer. One refresh runs when the event socket becomes available so the first frame can catch up with state that arrived before the shell subscribed.

Workspace clicks all use one `Hyprland.dispatch` request. They do not call `HyprlandWorkspace.activate()`. On Quickshell 0.2 that method sends `workspace <name>`, and Hyprland's Lua config evaluates the request as `return hl.dispatch(<request>)`. The live click `workspace 5` failed with `')' expected near '5'` even when workspace 5 already existed. The Lua request is `hl.dsp.focus({ workspace = <id> })`, which the Hyprland dispatcher wiki documents as focus-workspace and which a Wayland click test accepted for a numeric id. The id is an integer from 1 to 99. The expression does not set `on_current_monitor`, so a workspace stays on its own monitor: DP-1 keeps 1–3 and HDMI-A-1 keeps 4–6. `bar.workspaceDispatch` is `auto`, `lua`, or `legacy`. `auto` uses Quickshell's `Hyprland.usingLua` when that property exists. Quickshell 0.2 does not publish it, so `auto` selects Lua on that floor. `legacy` sends `workspace <id>` for a compositor that still uses the text dispatcher. After a dispatch the model refreshes monitors, workspaces, and toplevels on the next turn. The request is socket IPC. It does not run a shell and it does not rewrite `binds.lua`, `monitors.lua`, or `decorations.lua`.

The highlighted workspace is the one active on the bar's monitor. A workspace that is active on another monitor stays unhighlighted. Indicators for workspaces 4, 5, and 6 are still shown when Hyprland has not created them yet.

The focused-title text is the activated toplevel on the bar's monitor. If none is activated, the title of a toplevel on that monitor's active workspace is used. Other monitors are ignored. An empty title hides the module.

If the Hyprland socket is absent, the indicators render inactive and clicks log a warning.

## Panels

Each bar window owns one `PopoverHost`. That host is the only primary popup for its monitor. Its phase is `closed`, `opening`, `open`, or `closing`. The grab and the click mask follow that phase. Opening the clock replaces the control center on that monitor, and the reverse, without starting a second window.

The host is a `PopupWindow`. `anchor.window` is the bar. `anchor.edges` stays `Top | Left` and `anchor.gravity` stays `Bottom | Right`, so a 1×1 anchor rect is the popup's top-left. `PopupAdjustment.Flip` and `PopupAdjustment.Slide` remain as the compositor's own adjustment. The rect is written inside `anchor.onAnchoring`, which is the documented place for a non-reactive map. The map is `contentItem.mapFromItem(anchorItem, 0, 0, anchorItem.width, anchorItem.height)`. Those values are logical pixels. `QsWindow.itemRect` is not used: its documented equivalent is `mapFromItem(item, 0, 0, 0, 0)`, which has no size, so end alignment cannot use it. `shell/logic/popover.js` then clamps the top-left to the screen margin. A zero-size map produces no rect. `updateAnchor()` runs when the anchor item, the bar window, or the panel size changes. There is no timer.

The popup window color is transparent and `surfaceFormat.opaque` is false, so the surface can blend. The visible card is a separate rectangle using the theme scrim. A flat translucent rectangle sits behind that card. It is not a sampled shadow and it is not blur.

`BackgroundEffect` is not referenced. Quickshell 0.2.0 does not have that type, and a dynamic property lookup does not create the attached object. The 0.3 effect is declarative and needs `ext-background-effect-v1`. A file that names the type would fail to parse on 0.2.0, and version-gated preprocessing is not part of that release. `appearance.panelBlur` stays in the settings file and does not change rendering. The scrim, its opacity, and the flat shadow are the supported surface. Hyprland's blur settings are not modified.

Dismissal uses `HyprlandFocusGrab` from Quickshell 0.2. The grab is active only while the phase is `opening` or `open`. Closing clears the key scope's focus before the grab is set inactive. Active focus is requested on the next frame, and only if the popup is still visible and the grab is active. The key scope is not a text field and does not accept Tab. Setting the grab inactive releases it and does not emit `cleared`. A click outside emits `cleared` only after the compositor has already dropped the grab, then the same close path runs. Escape closes the panel while the key scope is focused. During `closing`, the window can stay visible for the fade, the grab is already off, and `mask` is a `Region` with `Intersection.Xor` over the window content so the fading surface does not keep clicks. `closed` hides the window. Monitor loss, anchor loss, and window close go straight to `closed`. Destruction clears focus and then turns the grab off. Stopping SwiftShell also drops the client, which releases a grab the process did not clear. Noctalia is not part of that grab.

The bar's layer is `WlrLayer.Top` and its keyboard focus is `WlrKeyboardFocus.None`. Qt's Wayland text-input client still enables and disables the text-input protocol when an item gains or loses active focus. The logged line `Trying to disable ... but 0x0 is focused` is that client talking to a null keyboard-focus surface. The layer surface is not the text-input focus, and an outside click drops the grab before Qt runs the disable. The shell does not filter the message. Whether it still appears after this focus order is a hardware check.

Open animation is 180ms and close is 120ms at motion scale 1, with a 4px move and an opacity fade. `appearance.reducedMotion` or a motion scale of 0 skips the fade and sets the finished phase immediately. A close that starts while the surface opacity is still 0 also finishes immediately, so an opening panel cannot remain in `closing` with no animation left to complete. A finish signal is applied only when the phase and the opacity agree, so a stale finish cannot hide a panel that has been reopened. Hover color changes take 80ms unless motion is reduced.

The calendar and control center roots are `Item`s. `Column`, `Row`, `Grid`, `Flow`, `Loader`, and `Text` calculate `implicitWidth` and `implicitHeight`, and assigning either property is a startup error. The item publishes the panel size; the column inside it is given that width and lays out the controls. A `Loader` is left to adopt the loaded item's implicit size. Day cells are text. They do not pretend to select an event. The calendar highlights today with weight and a 1px mark, and moves by month. "Today" returns to the clock's month. Week numbers are ISO weeks and stay hidden until the panel's week-number control turns them on. The first column follows `clock.weekStart`: `locale` uses `Qt.locale().firstDayOfWeek`, and `monday` or `sunday` override it.

The control center's live control is the default PipeWire sink. `AudioSection.qml` binds that node with `PwObjectTracker` and writes `audio.volume` and `audio.muted`. Raising the volume above zero unmutes. A missing PipeWire module or sink leaves the row labeled Unavailable. Network, Bluetooth, brightness, media, Do Not Disturb, and power are status text, not buttons. Settings text points at the JSON file. Dark, light, motion, and the top gradient are real preference writes.

## Settings

Preferences live in `$XDG_CONFIG_HOME/swiftshell/settings.json`, which is `~/.config/swiftshell/settings.json` when `XDG_CONFIG_HOME` is unset. That directory is separate from `~/.config/quickshell` and from Noctalia.

`scripts/launch.sh` creates the directory and copies `shell/config/defaults.json` only when the file is missing. `SettingsStore` is a Quickshell `Singleton` and loads the file with `FileView` and `JsonAdapter`. `atomicWrites` stays enabled. A missing or unreadable file keeps the built-in defaults and does not overwrite an existing file. Unknown JSON keys are not preserved across a later adapter write. The settings schema is the whole file. Missing `appearance` or calendar keys keep the defaults.

`shell/logic/settings.js` is the validation contract. The settings GUI does not exist yet. Edit the JSON file, and a running shell reloads it because `watchChanges` is on. `bar.workspaceIds` accepts a JSON array or a QML `list<int>`. Both have `length` and indexes. `Array.isArray` is false for the QML list, and that used to warn `bar.workspaceIds` for a valid `[4, 5, 6]`. A list is valid only when every entry is an integer id, the length is from 1 to 12, and there are no duplicates. A bad list still reports `bar.workspaceIds` and is not treated as clean. Strings such as `"6"` stay invalid. The repaired copy is what the bar shows after a warning.

| Key | Default | Effect |
|---|---|---|
| `clock.use24Hour` | `true` | `09:04` or `9:04 AM` |
| `clock.showWeekNumbers` | `false` | ISO week numbers in the calendar |
| `clock.weekStart` | `locale` | `locale`, `monday`, or `sunday` |
| `bar.targetMonitor` | `HDMI-A-1` | Connector that receives the bar |
| `bar.workspaceIds` | `[4, 5, 6]` | Indicator order, maximum 12 ids |
| `bar.workspaceDispatch` | `auto` | `auto`, `lua`, or `legacy` workspace IPC |
| `bar.showFocusedTitle` | `true` | Hides the center title when false |
| `bar.reserveSpace` | `false` | When true, reserves the bar height on that output |
| `appearance.mode` | `dark` | `dark` or `light` text and panel palette |
| `appearance.tint` | `neutral` | `wallpaper` is stored and not sampled |
| `appearance.panelOpacity` | `0.92` | Scrim strength, clamped from 0.72 to 0.96 |
| `appearance.panelBlur` | `1` | Stored only. It does not enable blur on the Quickshell 0.2 floor |
| `appearance.topGradient` | `false` | Faint fade inside the bar window |
| `appearance.reducedMotion` | `false` | Removes panel and hover animation |
| `appearance.motionScale` | `1` | Scales the 180ms / 120ms / 80ms durations, from 0 to 1 |

`reserveSpace` defaults off. That mode is a fully transparent overlay: the bar does not reserve an exclusive zone, and tiled, maximized, and fullscreen windows can cover it. Quickshell treats `ExclusionMode.Auto` as a reservation. The window therefore assigns `ExclusionMode.Ignore` and does not also assign `exclusiveZone`, because an `exclusiveZone` write forces normal exclusion inside Quickshell. Setting `bar.reserveSpace` to true assigns `exclusiveZone` to the bar height in logical pixels and does not also assign `exclusionMode`. Tiled and maximized windows then keep out of that strip. The layer stays `WlrLayer.Top`, which Hyprland draws under true fullscreen, so fullscreen clients still cover the bar. This tree does not change Hyprland's fullscreen rules. The zone is applied when the bar window is created and again when the setting changes. It is not multiplied by the output scale.

## Process identity

`shell/shell.qml` sets Quickshell shell id `swiftshell`. Launch and stop use `qs --path` pointed at this checkout's `shell` directory. Stop does not select Noctalia.

## Dependencies

Runtime: Quickshell with the Hyprland, layer-shell, and PipeWire modules, Qt 6 Quick, Qt 6 Quick Layouts, and Qt 6 Core (`StandardPaths`). A Quickshell build without PipeWire still loads the bar; the audio block shows Unavailable. No npm packages and no vendored Quickshell.

Installed files live under `$XDG_DATA_HOME/swiftshell`. Settings live under `$XDG_CONFIG_HOME/swiftshell`. `./install.sh` copies the app and launcher. `swiftshell activate` registers a free Quickshell name and a desktop entry. Those commands do not edit Hyprland startup, shortcuts, or service units. See `docs/install.md`.

Test-only: Node for `tests/logic.test.js`, Python 3 for `tests/static_check.py`, and a POSIX shell for `tests/install_flow.sh`. None of these are required to run the shell.

## Decision

The safe preview behavior is recorded in `docs/decisions/0001-m0-m1-boundaries.md`. The install boundaries are recorded in `docs/decisions/0002-install-boundaries.md`. The original panel boundaries are recorded in `docs/decisions/0003-m2-panels.md`. The color, blur, anchor, and popup-phase corrections are recorded in `docs/decisions/0004-m2-stability.md`.
