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

`BarHost` is a Quickshell `Scope`. `Variants` is a child of that scope. `targetScreens` is a plain list, not a binding. `refreshTargetScreens()` fills it when the component is completed, when `Quickshell.screens` changes, when the target monitor setting changes, and when `HyprlandModel` finishes a monitor refresh or its focused monitor changes. The list is replaced only when the matched screen object changes, so reading Hyprland monitor names while a bar window is created does not re-enter the property. One screen gets the bar. An empty `bar.targetMonitor` uses the focused Hyprland monitor when its connector name or description matches a Quickshell screen, and otherwise the first screen. A non-empty value matches the Qt name, the Hyprland connector name, or the Hyprland description. A saved name that is not connected uses that same fallback. No screens means no bar. A new settings file leaves the preference empty. An existing file that still says `HDMI-A-1` keeps the bar on that output while it is connected.

Fractional scale is left to the compositor. Layout values are logical pixels.

## Hyprland

`HyprlandModel` reads `Hyprland.workspaces`, `Hyprland.monitors`, and `Hyprland.toplevels`. QML property notifications drive the bar. There is no workspace timer. One refresh runs when the event socket becomes available so the first frame can catch up with state that arrived before the shell subscribed.

Workspace clicks all use one `Hyprland.dispatch` request. They do not call `HyprlandWorkspace.activate()`. On Quickshell 0.2 that method sends `workspace <name>`, and Hyprland's Lua config evaluates the request as `return hl.dispatch(<request>)`. The live click `workspace 5` failed with `')' expected near '5'` even when workspace 5 already existed. The Lua request is `hl.dsp.focus({ workspace = <id> })`, which the Hyprland dispatcher wiki documents as focus-workspace and which a Wayland click test accepted for a numeric id. The id is an integer from 1 to 99. The expression does not set `on_current_monitor`, so a workspace stays on its own monitor: DP-1 keeps 1–3 and HDMI-A-1 keeps 4–6. `bar.workspaceDispatch` is `auto`, `lua`, or `legacy`. `auto` uses Quickshell's `Hyprland.usingLua` when that property exists. Quickshell 0.2 does not publish it, so `auto` selects Lua on that floor. `legacy` sends `workspace <id>` for a compositor that still uses the text dispatcher. After a dispatch the model refreshes monitors, workspaces, and toplevels on the next turn. The request is socket IPC. It does not run a shell and it does not rewrite `binds.lua`, `monitors.lua`, or `decorations.lua`.

The highlighted workspace is the one active on the bar's monitor. A workspace that is active on another monitor stays unhighlighted. An empty `bar.workspaceIds` shows the positive ids Hyprland currently reports on that monitor, sorted. An explicit list keeps its order and still draws an id Hyprland has not created, which is how a saved `[4, 5, 6]` keeps an empty workspace clickable. Automatic mode cannot invent a workspace Hyprland has already destroyed. Named workspaces use negative ids and are not shown.

The focused-title text is the activated toplevel on the bar's monitor. If none is activated, the title of a toplevel on that monitor's active workspace is used. Other monitors are ignored. An empty title hides the module.

If the Hyprland socket is absent, the indicators render inactive and clicks log a warning.

## Panels

Each bar window owns one `PopoverHost`. That host is the only primary popup for its monitor. Its phase is `closed`, `opening`, `open`, or `closing`. The grab and the click mask follow that phase. Opening the clock replaces the control center on that monitor, and the reverse, without starting a second window.

The host is a `PopupWindow`. `anchor.window` is the bar. `anchor.edges` stays `Top | Left` and `anchor.gravity` stays `Bottom | Right`, so a 1×1 anchor rect is the popup's top-left. `PopupAdjustment.Flip` and `PopupAdjustment.Slide` remain as the compositor's own adjustment. The rect is written inside `anchor.onAnchoring`, which is the documented place for a non-reactive map. The map is `contentItem.mapFromItem(anchorItem, 0, 0, anchorItem.width, anchorItem.height)`. Those values are logical pixels. `QsWindow.itemRect` is not used: its documented equivalent is `mapFromItem(item, 0, 0, 0, 0)`, which has no size, so end alignment cannot use it. `shell/logic/popover.js` then clamps the top-left to the screen margin. A zero-size map produces no rect. `updateAnchor()` runs when the anchor item, the bar window, or the panel size changes. There is no timer.

The popup window color is transparent and `surfaceFormat.opaque` is false, so the surface can blend. The visible card is a separate rectangle using the theme scrim. A flat translucent rectangle sits behind that card. It is not a sampled shadow and it is not blur. The card sets a corner radius and leaves `clip` off. Qt Quick's clip is rectangular, so turning it on would not make a rounded blur mask. Long button and switch labels elide when the control is narrower than the text. A 1px border is drawn only while a control has keyboard focus. The display diagram keeps a 1px edge so the rectangles stay readable.

`BackgroundEffect` is not referenced. Quickshell 0.2.0 does not have that type, and a dynamic property lookup does not create the attached object. The 0.3 effect is declarative and needs `ext-background-effect-v1`. A file that names the type would fail to parse on 0.2.0, and version-gated preprocessing is not part of that release. `appearance.panelBlur` stays in the settings file and does not change rendering. The scrim, its opacity, and the flat shadow are the supported surface. Hyprland's blur settings are not modified.

Dismissal uses `HyprlandFocusGrab` from Quickshell 0.2. The grab is active only while the phase is `opening` or `open`. Closing clears the key scope's focus before the grab is set inactive. Active focus is requested on the next frame, and only if the popup is still visible and the grab is active. The key scope is not a text field and does not accept Tab. Setting the grab inactive releases it and does not emit `cleared`. A click outside emits `cleared` only after the compositor has already dropped the grab, then the same close path runs. Escape closes the panel while the key scope is focused. During `closing`, the window can stay visible for the fade, the grab is already off, and `mask` is a `Region` with `Intersection.Xor` over the window content so the fading surface does not keep clicks. `closed` hides the window. Monitor loss, anchor loss, and window close go straight to `closed`. Destruction clears focus and then turns the grab off. Stopping SwiftShell also drops the client, which releases a grab the process did not clear. Noctalia is not part of that grab.

The bar's layer is `WlrLayer.Top` and its keyboard focus is `WlrKeyboardFocus.None`. Qt's Wayland text-input client still enables and disables the text-input protocol when an item gains or loses active focus. The logged line `Trying to disable ... but 0x0 is focused` is that client talking to a null keyboard-focus surface. The layer surface is not the text-input focus, and an outside click drops the grab before Qt runs the disable. The shell does not filter the message. Whether it still appears after this focus order is a hardware check.

Open animation is 180ms and close is 120ms at motion scale 1, with a 4px move and an opacity fade. `appearance.reducedMotion` or a motion scale of 0 skips the fade and sets the finished phase immediately. A close that starts while the surface opacity is still 0 also finishes immediately, so an opening panel cannot remain in `closing` with no animation left to complete. A finish signal is applied only when the phase and the opacity agree, so a stale finish cannot hide a panel that has been reopened. Hover color changes take 80ms unless motion is reduced.

The calendar and control center roots are `Item`s. `Column`, `Row`, `Grid`, `Flow`, `Loader`, and `Text` calculate `implicitWidth` and `implicitHeight`, and assigning either property is a startup error. The item publishes the panel size; the column inside it is given that width and lays out the controls. A `Loader` is left to adopt the loaded item's implicit size. Day cells are text. They do not pretend to select an event. The calendar highlights today with weight and a 1px mark, and moves by month. "Today" returns to the clock's month. Week numbers are ISO weeks and stay hidden until the panel's week-number control turns them on. The first column follows `clock.weekStart`: `locale` uses `Qt.locale().firstDayOfWeek`, and `monday` or `sunday` override it.

The control center's audio section is the default PipeWire sink and, when PipeWire reports one, the default source. `AudioSection.qml` binds those nodes with `PwObjectTracker` and writes `audio.volume` and `audio.muted`. Raising the volume above zero unmutes. Application streams are the audio nodes PipeWire marks as streams, capped at six, and a stream slider writes that node's volume. Choosing another output sets `preferredDefaultAudioSink` only after PipeWire is ready and the node is in the sink list. A missing PipeWire module or sink leaves the row labeled Unavailable. Media uses `Mpris.players`. Play, pause, next, and previous run only when that player says the action is allowed. The tray lists `SystemTray.items` that can be activated or that have a menu. An item that is menu-only and has no menu is not shown. A missing MPRIS or tray module stays inside its loader and is labeled Unavailable. Network and brightness stay labeled unavailable: this Quickshell floor has no NetworkManager type and no backlight call, so there is no scan and no software dimming. Bluetooth lists devices BlueZ already knows and can connect, disconnect, pair, cancel, or forget them. It does not start a scan. Battery reads UPower's display device when that device is ready. Lock, suspend, restart, and shut down use the same confirmed `loginctl` path as Spotlight. Do not disturb is a saved preference. Critical banners still show when SwiftShell owns notifications. It does not own them until Settings asks a second time. The notification server is created only after that confirmation. If creation fails, the current owner is left alone. A preview card on the page is labeled Preview and does not take the bus. Notification bodies are not written to the log. The Settings button opens the settings window. Dark, light, motion, and the top gradient are real preference writes. The bar can show Media and Tray. Both take no width until a player or an actionable tray icon exists.

## Settings

Preferences live in `$XDG_CONFIG_HOME/swiftshell/settings.json`, which is `~/.config/swiftshell/settings.json` when `XDG_CONFIG_HOME` is unset. That directory is separate from `~/.config/quickshell` and from Noctalia.

`scripts/launch.sh` creates the directory and copies `shell/config/defaults.json` only when the file is missing. `SettingsStore` is a Quickshell `Singleton` and loads the file with `FileView` and `JsonAdapter`. `atomicWrites` stays enabled. A missing or unreadable file keeps the built-in defaults and does not overwrite an existing file. Unknown JSON keys are not preserved across a later adapter write. The settings schema is the whole file. Missing `appearance` or calendar keys keep the defaults.

Schema version 3 is the current file. Versions 1 and 2 migrate. Version 3 is kept. Any other version is an error and the file is left as it is. A readable older file, or a readable file with no version, is backed up to `settings.json.bak-swiftshell` and then saved as version 3. The backup is the original file text, written with `FileView.setText`. It is not passed through `JsonAdapter`. An existing backup that already restores to a settings object is left in place, including an older backup that stored the text under a `document` string. `swiftshell rollback-settings` unwraps that string when it is the whole file. Unknown keys from the original object are kept in `extensionsJson` on the migrated file and remain in the backup bytes. A file that is not JSON is not migrated and is not rewritten. Copy the file aside before the first launch of this version if you need the original key layout as well as the backup. A version 3 file that has no `wallpaper` object keeps the wallpaper defaults the next time a value is written. Missing keys are not a new schema version.

`shell/logic/settings.js` is the validation contract. The settings window is `shell/settings/SettingsWindow.qml`, a Quickshell `FloatingWindow` created by a `Loader` while `SettingsModel.open` is true. It is not a `PanelWindow`. Spotlight's Settings row and the control center's Settings button both call `SettingsModel.show()`. A second request raises the same window. Escape and the compositor close path remember the size and close it. The pages that exist are Appearance, Top bar, Wallpaper, Displays, Shortcuts, and Audio. Search covers the controls on those pages: theme, text size and weight, density, panel opacity, corner radius, shadow opacity and softness, icon scale, motion scale, reduced motion, high contrast, the top gradient, bar height and modules, the wallpaper path, fit, and per-output override, the display preview, and the preferred chords. Wallpaper tint is labeled not sampled. Backdrop blur is labeled unavailable. Undo restores the previous appearance values for this open window. Reset restores the appearance defaults and can itself be undone. Both write the settings file. The shortcut page stores preferred chords and does not install them. The audio page shows the same PipeWire, player, and tray controls as the control center. A window narrower than 720 logical pixels stacks the actions above the page. A running shell still reloads the JSON file because `watchChanges` is on. `bar.workspaceIds` accepts a JSON array or a QML `list<int>`. Both have `length` and indexes. `Array.isArray` is false for the QML list, and that used to warn `bar.workspaceIds` for a valid `[4, 5, 6]`. An empty list is valid and means the live ids described above. A non-empty list is valid only when every entry is an integer id, the length is at most 12, and there are no duplicates. A bad list still reports `bar.workspaceIds` and is not treated as clean. Strings such as `"6"` stay invalid. The repaired copy is the valid ids from that list, or an empty list when none remain. `bar.targetMonitor` accepts any string. Blank text is automatic. A non-string is reported and repaired to automatic.

| Key | Default | Effect |
|---|---|---|
| `clock.use24Hour` | `true` | `09:04` or `9:04 AM` |
| `clock.showWeekNumbers` | `false` | ISO week numbers in the calendar |
| `clock.weekStart` | `locale` | `locale`, `monday`, or `sunday` |
| `bar.targetMonitor` | `""` | Empty follows the focused monitor, then the first screen. A connector name or Hyprland description pins the bar |
| `bar.workspaceIds` | `[]` | Empty follows live ids on the bar's monitor. A non-empty list is the indicator order, maximum 12 ids |
| `bar.workspaceDispatch` | `auto` | `auto`, `lua`, or `legacy` workspace IPC |
| `bar.showFocusedTitle` | `true` | Hides the center title when false |
| `bar.reserveSpace` | `true` | When true, reserves the bar height. `false` is the overlay used beside Noctalia |
| `appearance.mode` | `dark` | `dark` or `light` text and panel palette |
| `appearance.tint` | `neutral` | `wallpaper` is stored and not sampled |
| `appearance.panelOpacity` | `0.92` | Scrim strength, clamped from 0.72 to 0.96 |
| `appearance.panelBlur` | `1` | Stored only. It does not enable blur on the Quickshell 0.2 floor |
| `appearance.topGradient` | `false` | Faint fade inside the bar window |
| `appearance.reducedMotion` | `false` | Removes panel and hover animation |
| `appearance.motionScale` | `1` | Scales the 180ms / 120ms / 80ms durations, from 0 to 1 |
| `launcher.pinnedIds` | `[]` | Desktop ids shown first in an empty launcher query. Maximum 12. |
| `settingsWindow.width` | `900` | Last settings window width, from 640 to 1600 logical px |
| `settingsWindow.height` | `620` | Last settings window height, from 440 to 1200 logical px |
| `settingsWindow.category` | `appearance` | `appearance`, `bar`, `wallpaper`, `displays`, `shortcuts`, `audio`, `network`, `bluetooth`, `power`, or `notifications` |
| `notifications.ownership` | `off` | `on` tries to create a notification server. `off` does not |
| `notifications.dnd` | `false` | When ownership is on, non-critical banners wait in history |
| `notifications.policiesJson` | `{}` | Desktop id to `show`, `quiet`, or `hide`. `hide` drops the notification. `quiet` keeps it in history unless it is critical |
| `wallpaper.enabled` | `true` | Draws one background layer per output. `false` removes those layers and does not stop another wallpaper program |
| `wallpaper.fit` | `cover` | `cover` crops to fill. `contain` shows the whole picture on black |
| `wallpaper.path` | `""` | Empty uses the packaged crimson image. A png, jpeg, or webp path is used as written |
| `wallpaper.outputsJson` | `{}` | JSON object of output name to image path. An empty path removes that output's override |
| `wallpaper.slideshow` | `false` | When true, and at least one slide path is valid, the background advances through that list |
| `wallpaper.intervalMinutes` | `30` | Minutes between slides, from 1 to 720. The scheduler waits at least one minute |
| `wallpaper.order` | `sequential` | `sequential` or `shuffle`. Shuffle does not show the current image again while another remains |
| `wallpaper.transitionMs` | `400` | Crossfade length, from 0 to 1000. Reduced motion uses 0 |
| `wallpaper.slidesJson` | `[]` | JSON array of image paths, at most 64 |
| `appearance.automaticText` | `false` | When true, a png's top edge chooses light or dark text. Jpeg and webp are not sampled |
| `appearance.automaticGradient` | `false` | When true, a split or low-contrast top edge draws the bar fade |
| `appearance.contrast` | `standard` | `standard` or `high`. High uses black or white text. A manual hex still wins, and automatic text still follows a png sample |
| `appearance.manualText` | `""` | `#rrggbb` used when automatic text is off. Empty keeps the theme text |
| `appearance.manualMuted` | `""` | `#rrggbb` muted text. Empty keeps the theme |
| `appearance.manualPanel` | `""` | `#rrggbb` panel. Empty keeps the theme |
| `appearance.manualGradient` | `""` | `#rrggbb` fade color. Empty keeps the theme, or the sampled accent when automatic fade is on |
| `shortcutsJson` | `{}` | JSON object of `spotlight`, `settings`, and `control` to a chord. Saving it does not install a compositor bind |
| `extensionsJson` | `{}` | JSON object text for keys the validator does not own, capped at 4096 characters |

`reserveSpace` defaults on for a new settings file. `PanelWindow` would otherwise use `ExclusionMode.Auto` and reserve space on its own. Overlay mode (`false`) assigns only `ExclusionMode.Ignore`. Quickshell's Wayland binding then publishes exclusive zone `-1`, which does not push windows. Reservation assigns the logical bar height and `ExclusionMode.Normal`. Quickshell converts that height to native pixels on commit, including on the 1.5 scale HDMI-A-1 output, so the shell does not multiply by scale itself. Writing `exclusiveZone` to the same number it already holds does not call the setter. After an overlay period the stored height is often unchanged, so the window also assigns `Normal` or the bar would stay an overlay. Tiled and maximized windows should then keep out of that strip. The layer stays `WlrLayer.Top`, which Hyprland draws under true fullscreen, so fullscreen clients still cover the bar. This tree does not change Hyprland's fullscreen rules. The zone is applied when the bar is created, when the height changes, and when the setting changes. An existing settings file that already says `false` is left as an overlay. Use that while Noctalia is also drawing on the output. The reserved strip has not been measured on the session yet.

## Notifications

The notification `Loader` is inactive unless `notifications.ownership` is explicitly confirmed. Creating Quickshell's `NotificationServer` does not stop or replace another daemon. Quickshell 0.2 does not expose whether registration of `org.freedesktop.Notifications` succeeded, so component construction is reported as `waiting`, not as proof of ownership. SwiftShell changes the status to `running` only after the server receives notification traffic. With another owner present, the request can remain unverified indefinitely; this repository does not claim a seamless daemon handoff or restore another process.

The host decides policy and banner capacity before setting `Notification.tracked`. Hidden, quiet, do-not-disturb, and overflow notifications are copied into the bounded model when appropriate and are not retained as native Quickshell objects. Live banners keep their native object so dismiss, expiration, close, replacement, and action signals reach the sender. Releasing ownership dismisses remaining tracked banners. The window follows the focused Hyprland output and falls back to the first Qt screen. History is memory-only, capped at 40 entries, and notification sounds are not implemented.

## Wallpaper

`shell/wallpaper/WallpaperHost.qml` builds one `PanelWindow` per screen from `Quickshell.screens`. The layer is `WlrLayer.Background`, the namespace is `swiftshell-wallpaper`, keyboard focus is `None`, and the exclusive zone is ignored. The surface does not take pointer or keyboard input. Stopping SwiftShell removes it. It does not signal `hyprpaper` or `swww`. While it is enabled, the opaque layer covers whatever those programs draw.

An empty path, a rejected path, or a picture that fails to decode uses `shell/assets/wallpapers/swiftshell-default-crimson.png`. That file is a link to `assets/wallpapers/swiftshell-default-crimson.png` in a checkout. `install.sh` copies the real PNG into the installed tree and does not leave the link in place. Qt bounds each wallpaper decode to a 3840×3840 source request. Cover and contain use the same crop math in `shell/logic/wallpaper.js` and in the `Image` fill mode. A per-output path is stored under the screen name. That name is the connector Quickshell reports, which can change when a cable moves.

The settings page previews the shared image, offers Cover and Contain, a path field, and Choose image. Choose image loads `QtQuick.Dialogs.FileDialog` in its own `Loader`. If that module is missing, the page says so and the path field remains the way to set a file. This workspace's Qt build does not include `QtQuick.Dialogs`, and it has no folder listing. Slideshow images are added by path. The page has not been shown on a Hyprland session, so the crop on a real output is not measured.

Slideshow states are disabled, scanning, waiting, preloading, transitioning, paused, and error. A minute timer fires only while the session is waiting. Interval and transition changes preserve the current item; list and order changes preserve it when it remains valid. Each output preloads into its inactive image slot. The state machine starts and commits a transition only after every participating output reports the same generation, while disconnected outputs are removed from that barrier. The slots exchange roles after the fade, so committing does not clear the visible texture and reload it through a third state. A failed incoming image keeps the current image; a failed current item is skipped, and an exhausted list falls back to the packaged image. One image does not advance. Turning the wallpaper off disables the slideshow. This does not read battery, lock, or fullscreen state, so there is no pause switch for those.

Automatic text and the automatic fade read png samples from the image region actually mapped behind each output's bar. The sampler applies that output's logical geometry and Cover or Contain rectangle; letterboxed pixels use the wallpaper surface's black background. Per-output overrides and a committed slideshow image are analyzed independently, and stale reads are discarded. Light text is chosen on a dark edge and dark text on a light edge. A split edge, or a contrast below 4.5, turns on the bar fade instead of flipping the text. A small change keeps the previous text so a slideshow does not strobe. The accent mixed into the fade is pulled toward gray. The in-process decoder rejects files above 32 MiB and inflated samples above 16 MiB before allocation; larger PNGs still display through Qt but are not sampled. Jpeg and webp still display, and the page says they are not sampled. Manual hex values are kept when automatic is turned off. Nothing here reads pixels from other windows.

## Displays

The Displays page draws one rectangle per connected screen. Dragging, or Alt+H/J/K/L while the diagram is focused, moves that rectangle in the preview. Edges within 40 logical pixels snap. Overlap is named. The last enabled output cannot be turned off in the preview. If every reported position is the origin, the preview lays the outputs in a row and says so. The current width, height, scale, and refresh are shown when the compositor reported them. Another mode, rotation, or HDR switch is not offered. Apply is disabled. The sentence on the page is the reason: this floor has no verified layout call, so nothing is sent. The preview is not written to Hyprland and is not kept as a display configuration.

## Shortcuts

The Shortcuts page lists Spotlight, Settings, and the control center. Record listens for one chord. Enter stores it in `shortcutsJson`. Escape cancels. A chord already used by another of those three actions is refused. Clear removes that action's chord. The page says the save does not install the chord, and that compositor binds are not read and are not changed. Super+Space stays on the handoff in `docs/launcher-shortcut.md`. Nothing in this page writes a bind file.

## Launcher

The Search control on the bar closes any open panel and asks `LauncherModel` to open `LauncherWindow`. `scripts/request-launcher.sh` and `swiftshell request-launcher` write a JSON token under the XDG state directory. The shell watches that file. The token already present at startup does not open the launcher. A later token opens it, and another token while it is open closes it. Neither command edits Hyprland or starts a second process. Super+Space is documented in `docs/launcher-shortcut.md` and is not changed by this repository.

Both paths resolve the screen when the request happens. The match is `Hyprland.focusedMonitor` against the Quickshell screen's name, Hyprland connector name, or Hyprland description. The bar's screen is not the target. If that focused monitor cannot be read, the first connected screen is used. The card stays on the screen chosen at open. A focus change while it remains open does not move it. If that screen leaves `Quickshell.screens`, the launcher closes.

`LauncherModel` reads `DesktopEntries.applications.values` at startup, whenever `applicationsChanged` fires, and again when the launcher opens. Current Quickshell posts the scan result to the event loop, so the first read can be empty. That read is not treated as the catalog. A later signal replaces it. The list is kept after the launcher closes so the next open is not forced through an empty copy. Keystrokes search the snapshot. They do not scan desktop files. Results come from `shell/logic/launcher.js`: exact name, prefix, word prefix, substring, then a short fuzzy subsequence. The desktop id is scored under the name, so `dolphin` matches `org.kde.dolphin` and `helium` matches the Helium id. Name matches outrank id, generic name, comment, keywords, and categories. Equal scores sort by name, then id. There is no file, calculation, or settings-search provider.

An empty query shows pinned ids from `launcher.pinnedIds`, then up to eight recent ids, then up to twelve other applications in name order, then Settings and the power rows. The twelve-row grid is not the search set. Recent ids are recorded only after a launch from this launcher. They are desktop ids in the state file, not commands and not window titles. Settings closes the launcher and opens the settings window. Power rows are Lock, Suspend, Restart, and Shut down. The first Enter or click arms confirmation. A different row arms that row instead of running the previous one. The second confirmation runs a fixed `loginctl` argument list. The search text is not one of those arguments. If the call throws, the launcher stays open and shows a short notice.

Launch uses `DesktopEntry.execute()`. That is Quickshell's parsed `command` list plus the entry's working directory. `execString` is not passed to a shell. Quickshell 0.2's `execute()` ignores the terminal flag and field codes; the log says so when a terminal entry is launched. Lookup tries the id and the same id with or without a `.desktop` suffix, because Quickshell's id is the file basename. Icons use `Quickshell.iconPath(name, true)` for theme names and the path itself when it is absolute. The image keeps its aspect ratio. A missing icon or a failed load is a one-letter monogram.

The window is layer `Overlay` only so the search field sits above other windows while it is open. It uses `ExclusionMode.Ignore`, so it does not reserve the screen. The card is centered on the chosen screen in logical pixels. Its width is at most 480 and stays at least 48 logical pixels in from each side. Its height follows the field, status lines, and result rows, and it stops 24 logical pixels short of the screen edges. The search field stays above the result list, so scrolling does not move it. Long lists scroll inside the card. The card fades in over `Theme.motionOpen` unless reduced motion or a motion scale of 0 makes that duration 0. Closing hides the window immediately. Keyboard focus is `Exclusive` while the window is visible and `None` after it closes. Hiding the window clears the field and the focus grab. If the screen is gone while the launcher is open, it closes rather than leaving the grab up. Focus on the text field is requested on the next frame, and once more if that frame did not focus it. Escape on the field or the window, a click on the dim area around the card, and a cleared focus grab all close it. Tab and Shift+Tab move the selection and keep the selected row inside the list. Alt+J and Alt+K do the same. Bare letters stay in the search field. Quickshell 0.2 has no panel blur here, so the card is the theme scrim only.

## Process identity

`shell/shell.qml` sets Quickshell shell id `swiftshell`. Launch and stop use `qs --path` pointed at this checkout's `shell` directory. Stop does not select Noctalia.

## Dependencies

Runtime: Quickshell with the Hyprland, layer-shell, and PipeWire modules, Qt 6 Quick, Qt 6 Quick Layouts, and Qt 6 Core (`StandardPaths`). A Quickshell build without PipeWire still loads the bar; the audio block shows Unavailable. No npm packages and no vendored Quickshell.

Installed files live under `$XDG_DATA_HOME/swiftshell`. Settings live under `$XDG_CONFIG_HOME/swiftshell`. `./install.sh` copies the app and launcher. `swiftshell activate` registers a free Quickshell name and a desktop entry. Those commands do not edit Hyprland startup, shortcuts, or service units. See `docs/install.md`.

Test-only: Node for `tests/logic.test.js`, Python 3 for `tests/static_check.py`, and a POSIX shell for `tests/install_flow.sh`. None of these are required to run the shell.

## Decision

The safe preview behavior is recorded in `docs/decisions/0001-m0-m1-boundaries.md`. The install boundaries are recorded in `docs/decisions/0002-install-boundaries.md`. The original panel boundaries are recorded in `docs/decisions/0003-m2-panels.md`. The color, blur, anchor, and popup-phase corrections are recorded in `docs/decisions/0004-m2-stability.md`.
