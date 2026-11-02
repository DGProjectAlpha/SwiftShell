# Architecture

SwiftShell is a Quickshell desktop layer with independent per-output bars, native Settings, Spotlight, notifications and workspace overview. Services own system integration; surfaces share theme tokens. Development does not replace Noctalia or rewrite user-authored Hyprland configuration.

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
  BarHost -> per-output BarWindow -> module controls and PopoverHost
    Clock / Audio / Network / Power / Notifications / module customization
  LauncherWindow -> app grid and desktop search providers
  OverviewWindow -> workspace cards -> locally rendered window previews
  SettingsModel -> native floating SettingsWindow
  NotificationHost (only when notification ownership is enabled)
  WallpaperHost and shared service adapters
```

## Theme

Theme provides shared typography, spacing, rounded surfaces, hover/selection,
shadows and reduced-motion tokens. Settings, Spotlight and dedicated bar panels
use the same floater material. Native BackdropEffect regions follow each painted
card rather than its transparent shadow. SurfaceService probes actual protocol
and compositor capability; unsupported systems keep a readable fallback.

DesktopAppearance owns reversible runtime radius, border width and blur-profile
preferences. These affect compositor defaults; explicit app rules can override
them. Font, spacing, tint, opacity and shadow controls style SwiftShell surfaces.
No user Lua is rewritten. See decision 0039 for journal/recovery details.

ColorAnalysis asynchronously samples the chosen wallpaper file's displayed crop
with Qt image decoding (PNG/JPEG/WebP). A bounded PNG fallback works without the
optional Python Qt decoder. Foregrounds account for per-output bar material and
regional luminance; a neutral readability fade handles mixed/unknown backgrounds.
No screen or application pixels are captured for normal contrast decisions.

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

Each bar owns one PopoverHost overlay layer. Date opens Calendar; time opens
Clock. Clock also provides analogue/digital views, deadline-based countdown and
stopwatch/laps. ClockService owns atomic tool state and uses the existing desktop
notification owner for completion, without taking over notification service.

Audio/playback, Network & Devices, Power and module customization are dedicated
panels. The legacy saved module identifier control now renders the Audio widget.
New network/power modules participate in the existing visibility/order settings.
NetworkManager and BlueZ own devices; power-profiles-daemon owns actual modes.
Missing capabilities have explanatory disabled states.

Content is measured before mapping and tall content scrolls inside a bounded
viewport. Rounded input includes only the card, excluding the shadow. The focus
grab permits the panel and its bar, allowing one-click widget/view switches;
outside clicks, Escape, Settings and Spotlight release it. Native layer geometry
is checked against Hyprland observations on both scales. Genuine blur and shared
RectangularShadow require supported compositor/Qt APIs, not an opaque imitation.

TrayModule uses the actual StatusNotifier ObjectModel with native object roles,
without a fixed item cap. Left/right/middle/wheel and keyboard menus reach the
application's published functions. The background bar context handler sits below
module controls. Root UseQApplication enables native QsMenuAnchor menus; a native
open/Escape audit covers the startup prerequisite.

## Settings

Settings is a real floating toplevel with native move/edge/corner resize,
maximize/restore, scoped minimize/reactivation, and saved size/position. Wide
Appearance layouts reflow into two columns; compact layouts stack controls and
navigation collapses. Geometry initializes once, avoiding live persisted-size
bindings that can resize a mapped window unexpectedly.

Pages share controls and central service models. Workspaces has friendly monitor
selection, automatic/custom lists and handle drag ordering with a keyboard
alternative. Spotlight Search saves All/Favorites/Recent as the opening view.
Default Applications uses installed desktop entries and XDG associations; terminal
and unsupported calendar roles are explicitly shell preferences. Network & Devices
includes Bluetooth; the old bluetooth category remains a compatibility alias.

Preferences use a raw watched FileView, validation and a JsonAdapter model.
A fixed stdin-fed Python helper performs private, fsynced atomic writes. Changes
coalesce and saving remains active until the latest snapshot is on disk. No file
content reaches live controls before validation. Own watcher events are ignored
using persisted/in-flight fingerprints. Malformed/future files and invalid
recovery journals are protected. Existing settings and extension data migrate
with backups; see decision 0039 and the native external-edit regressions.

## Notifications

The notification `Loader` is inactive unless `notifications.ownership` is explicitly confirmed. Creating Quickshell's `NotificationServer` does not stop or replace another daemon. Quickshell 0.2 does not expose whether registration of `org.freedesktop.Notifications` succeeded, so component construction is reported as `waiting`, not as proof of ownership. SwiftShell changes the status to `running` only after the server receives notification traffic. With another owner present, the request can remain unverified indefinitely; this repository does not claim a seamless daemon handoff or restore another process.

The host decides policy and banner capacity before setting `Notification.tracked`. Hidden, quiet, do-not-disturb, and overflow notifications are copied into the bounded model when appropriate and are not retained as native Quickshell objects. Live banners keep their native object so dismiss, expiration, close, replacement, and action signals reach the sender. Releasing ownership dismisses remaining tracked banners. The window follows the focused Hyprland output and falls back to the first Qt screen. History is memory-only, capped at 40 entries, and notification sounds are not implemented.

## Wallpaper

`shell/wallpaper/WallpaperHost.qml` builds one `PanelWindow` per screen from `Quickshell.screens`. The layer is `WlrLayer.Background`, the namespace is `swiftshell-wallpaper`, keyboard focus is `None`, and the exclusive zone is ignored. The surface does not take pointer or keyboard input. Stopping SwiftShell removes it. It does not signal `hyprpaper` or `swww`. While it is enabled, the opaque layer covers whatever those programs draw.

An empty path, a rejected path, or a picture that fails to decode uses `shell/assets/wallpapers/swiftshell-default-crimson.png`. That file is a link to `assets/wallpapers/swiftshell-default-crimson.png` in a checkout. `install.sh` copies the real PNG into the installed tree and does not leave the link in place. Qt bounds each wallpaper decode to a 3840×3840 source request. Cover and contain use the same crop math in `shell/logic/wallpaper.js` and in the `Image` fill mode. A per-output path is stored under the screen name. That name is the connector Quickshell reports, which can change when a cable moves.

The settings page previews the shared image, offers Cover and Contain, a path field, and native image/folder pickers. The pickers and `Qt.labs.folderlistmodel` scanner live behind separate `Loader` boundaries, so a missing optional Qt module leaves individual path entry usable. Folder scans include PNG, JPEG, and WebP names in sorted order and replace the slideshow list with at most 64 paths. The selected file list persists; the folder itself is not yet a schema field. This workspace lacks both optional modules, so local dialog interaction is not verified. The page has not been shown on a Hyprland session, so the crop on a real output is not measured.

Slideshow states are disabled, scanning, waiting, preloading, transitioning, paused, and error. A minute timer fires only while the session is waiting. Interval and transition changes preserve the current item; list and order changes preserve it when it remains valid. Each output preloads into its inactive image slot. The state machine starts and commits a transition only after every participating output reports the same generation, while disconnected outputs are removed from that barrier. The slots exchange roles after the fade, so committing does not clear the visible texture and reload it through a third state. A failed incoming image keeps the current image; a failed current item is skipped, and an exhausted list falls back to the packaged image. One image does not advance. Turning the wallpaper off disables the slideshow. This does not read battery, lock, or fullscreen state, so there is no pause switch for those.

Automatic text and the automatic fade read png samples from the image region actually mapped behind each output's bar. The sampler applies that output's logical geometry and Cover or Contain rectangle; letterboxed pixels use the wallpaper surface's black background. Per-output overrides and a committed slideshow image are analyzed independently, and stale reads are discarded. Light text is chosen on a dark edge and dark text on a light edge. A split edge, or a contrast below 4.5, turns on the bar fade instead of flipping the text. A small change keeps the previous text so a slideshow does not strobe. The accent mixed into the fade is pulled toward gray. The in-process decoder rejects files above 32 MiB and inflated samples above 16 MiB before allocation; larger PNGs still display through Qt but are not sampled. Jpeg and webp still display, and the page says they are not sampled. Manual hex values are kept when automatic is turned off. Nothing here reads pixels from other windows.

## Displays

Displays stages actual discovered monitor modes, refresh rates, scale,
orientation, enable state and logical positions. Dragging changes position while
preserving representation dimensions. Apply starts an independent recovery
watchdog; Keep commits and Revert/timeout restores. Confirmed owned layouts can
be restored explicitly. User Hyprland Lua remains untouched. Native transaction
and crash-recovery evidence is in decision 0031 and testing.md; physical hotplug
remains a separate hardware checklist item.

## Shortcuts

Shortcuts shows effective Hyprland bindings and a curated managed action
catalog. Recording uses the supported ShortcutInhibitor and waits for confirmed
inhibition before accepting a chord. Physical-keycode collisions are checked.
Managed hl.bind handles can be applied, changed, removed and undone; owned state
reapplies at startup/config reload. Existing opaque Lua callbacks remain read-only
because their original actions cannot be safely reconstructed from IPC. No user
bind file or unrelated handle is changed. Decision 0038 documents the boundary.

## Launcher

Spotlight resolves the focused output at invocation and keeps keyboard focus
in a large search field. Empty input shows the saved All/Favorites/Recent opening
view. Installed apps are a scrollable icon grid; favorite context actions and
drag/keyboard ordering persist desktop IDs, retaining temporarily missing apps.
A mode switch while open does not overwrite the preferred opening view.

Local providers rank applications/settings, safely parse calculations and common
unit conversions, and recognize URLs. A labeled Google fallback opens only on
activation through the default browser, with no network queries while typing.
Applications launch through parsed DesktopEntry.execute, never a shell query.
The Settings/Lock/Suspend/Restart/Shutdown icon strip uses verified fixed commands;
power actions require confirmation. Dangerous actions were not executed in tests.

The layer owns a rounded backdrop region and shared shadow. Escape, outside
click, repeated invocation and monitor loss close safely. Actual Super+Space,
calculator input, favorites/context/drag and Settings handoff have native tests on
both scales. See decision 0037 for provider and privacy limits.

## Process identity

`shell/shell.qml` sets Quickshell shell id `swiftshell`. Launch and stop use `qs --path` pointed at this checkout's `shell` directory. Stop does not select Noctalia.

## Dependencies

Runtime: Quickshell with the Hyprland, layer-shell, and PipeWire modules, Qt 6 Quick, Qt 6 Quick Layouts, and Qt 6 Core (`StandardPaths`). A Quickshell build without PipeWire still loads the bar; the audio block shows Unavailable. No npm packages and no vendored Quickshell.

Installed files live under `$XDG_DATA_HOME/swiftshell`. Settings live under `$XDG_CONFIG_HOME/swiftshell`. `./install.sh` copies the app and launcher. `swiftshell activate` registers a free Quickshell name and a desktop entry. Those commands do not edit Hyprland startup, shortcuts, or service units. See `docs/install.md`.

Test-only: Node for `tests/logic.test.js`, Python 3 for `tests/static_check.py`, and a POSIX shell for `tests/install_flow.sh`. None of these are required to run the shell.

## Decision

The safe preview behavior is recorded in `docs/decisions/0001-m0-m1-boundaries.md`. The install boundaries are recorded in `docs/decisions/0002-install-boundaries.md`. The original panel boundaries are recorded in `docs/decisions/0003-m2-panels.md`. The color, blur, anchor, and popup-phase corrections are recorded in `docs/decisions/0004-m2-stability.md`.


## Notification and overview lifecycle

NotificationsModel is a bounded reducer-backed in-memory store. NotificationHost
owns protocol objects and uses the installed Quickshell millisecond timeout API;
archiving a banner retains actions, while client close invalidates them. Model
signals route dismiss/actions to the host; snooze deadlines and persisted pause
preferences use a timer only while pending. Native/local Clock entries share the
same drawer. Local action metadata remains bounded alongside history; no content
is persisted or logged. Banner height is capped to the output with scrolling.

OverviewService reads live Hyprland toplevel geometry and bridges native foreign
handles to ScreencopyView. Captures exist only on local GPU surfaces while open,
with a truthful fallback when a frame is unavailable. No screenshot files are used.
Focus uses the native handle, with validated address dispatch for missing handles.
The overviewctl adapter replaces only a source-verified built-in Alt+Tab chord,
records recovery before mutation and falls back to cycling if shell IPC is absent.

Per-output bar layout is additive validated v3 data: edge, extra content scale,
module order and groups. Visibility remains independently inherited. Logical
layout scales the complete control surface, vertical rails stack modules and
popovers open inward from the selected edge. Reservation changes coalesce after
orientation dimensions settle. Wallpaper analysis samples that output's actual
edge/thickness, including the bounded PNG fallback.

DesktopTools provides opt-in event-driven clipboard sampling and typed screenshot
operations. Clipboard text never enters ordinary launcher ranking: only an explicit
clip prefix searches bounded session memory, and a deadline removes expired items.
The helper refuses sensitive MIME hints and bounds input. Screenshots invoke fixed
argv, validate output connectors/region geometry, close shell overlays before
capture, and pipe PNG directly to wl-copy without writing files. Source disappearance,
missing tools and cancellation have truthful outcomes. No launcher query becomes
shell code. Settings links retain a pending control until the native page is mapped.
