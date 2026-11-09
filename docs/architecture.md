# Architecture

SwiftShell runs one Quickshell configuration, `shell/shell.qml`. Services own
state and system integration; surfaces observe that state through shared controls
and theme tokens. Hyprland owns application window behavior. There is no npm
runtime, vendored Quickshell or separate always-on Settings process.

## Runtime composition

```text
shell/shell.qml (ShellRoot, UseQApplication, scoped IPC)
  BarHost -> per-output BarWindow -> ModuleStrip + PopoverHost
  LauncherWindow, OverviewWindow, ScreenshotWindow, ClipboardWindow
  SettingsModel.open -> lazy SettingsWindow (native FloatingWindow)
  wallpaperEnabled -> WallpaperHost -> per-output background surfaces
  notificationOwnership == on -> NotificationHost
```

`BarHost` replaces its plain `targetScreens` list only when placement changes,
avoiding screen/model binding loops. Placement can be focused, primary, all, or
a preferred output with a connected fallback. `HyprlandModel` combines native
objects and event-triggered IPC snapshots for outputs, workspaces and toplevels.
Numeric and named workspaces are supported; per-output explicit choices retain
empty indicators. Lua activation uses `hl.dsp.focus`, with an explicit legacy
text-dispatch mode. No universal monitor names or workspace lists are defaults.

## Ownership

| Location | Responsibility |
|---|---|
| `shell/bar`, `popovers` | Bar modules and dedicated Clock/Calendar, Audio, Network, Power, Weather and other panels |
| `shell/settings` | Native Settings window, pages, responsive controls and optional dialogs |
| `shell/launcher`, `overview` | Spotlight, desktop providers, workspace miniatures |
| `shell/wallpaper`, `notifications`, `clipboard`, `screenshots` | Feature surfaces and their local lifecycle |
| `shell/components`, `themes` | Reusable controls, materials, typography, motion and sizing |
| `shell/services` | Shared preference/live state, capability probes and OS adapters |
| `shell/helpers` | Fixed Python entry points for APIs absent from QML, validation and atomic filesystem operations |
| `shell/logic` | Pure JavaScript validation, geometry, reducers and algorithms |
| `tests/live` | Opt-in native fixtures and diagnostics; never installed as runtime code |

QML services invoke fixed argv with validated values; launcher queries never
become shell commands. NetworkManager, BlueZ, PipeWire, MPRIS, UPower and
power-profiles-daemon remain the system authorities. Python helpers are runtime
dependencies, including persistence; they are not disposable prototype scripts.

## Preferences and compatibility

`SettingsStore` watches raw JSON, validates before publishing, and exposes a
JsonAdapter-backed model. A stdin-fed Python helper performs private, fsynced,
atomic writes. Queued edits coalesce until the latest snapshot is on disk.
Fingerprints distinguish own writes from external edits. Migration backs up the
original, preserves supported extension data and protects malformed/future files.
The schema and defaults live in `shell/logic/settings.js` and
`shell/config/defaults.json`; user values live under `$XDG_CONFIG_HOME/swiftshell`.

Per-output bar maps are sparse: shared preferences resolve first, then output
overrides. **Apply to: All displays** changes the edited property across existing
overrides while preserving unrelated choices. `control` remains the saved Audio
module identifier; `bluetooth` remains a Settings category alias to Network &
Devices. `BluetoothPage` is still embedded by NetworkPage. These compatibility
paths must survive cleanup even though the old combined control center is gone.

## Rendering and interaction

All layout values are logical pixels. `Bar.targetBarMetrics` resolves final font,
icon, spacing and hit-area sizes for each bar. The content scene has no scale
transform; Qt applies window DPR once. The renderer policy uses actual raster
density/transform: native vertically hinted text at unscaled density 1, scalable
Qt text for fractional/higher density. It does not depend on connector names.
See decisions [0053](decisions/0053-bar-text-rasterization.md) and
[0055](decisions/0055-direct-bar-target-sizes.md).

Theme owns shared colors, motion, shadows and reduced-motion policy. SurfaceService
probes actual compositor/protocol support. BackdropEffect regions match painted
rounded materials and exclude transparent shadow margins. Missing blur support
has a readable fallback. Popovers release grabs/input immediately when closing,
then unmap after their fade; completed opacity changes finish the lifecycle.
Settings paints UI and blur in its initial map while placement is acknowledged
asynchronously. See decisions [0056](decisions/0056-popover-close-blur-cleanup.md)
and [0057](decisions/0057-settings-initial-presentation.md).

Settings uses one lazy native toplevel, saved geometry, native titlebar/edge move
and resize, scoped minimize and reactivation. Sections share bold headings,
indented controls, collapse transitions and page-wide expand/collapse. Main and
sidebar scrolling is wheel-driven so drag handles and sliders keep pointer input.

## Feature lifecycles

- Audio/media/tray share service models across panels, bars and Settings. All
  published tray items use native object roles and application-owned actions;
  UseQApplication is required for native menus.
- Wallpaper surfaces are noninteractive background layers. Two image slots per
  output coordinate slideshow generations. Optional dialogs/folder scanning stay
  behind loader boundaries. Regional contrast uses the chosen wallpaper's actual
  crop, never application pixels; Qt decoding supports PNG/JPEG/WebP with bounded
  in-process PNG fallback. The checkout wallpaper link is intentional; installers
  replace it with the real PNG in the installed tree.
- Notifications load only after ownership opt-in. Host lifetime follows real
  native notification objects; reducers bound history, policy and actions. History
  and reply drafts are memory-only. Optional QtMultimedia sound loads separately.
  Constructing a server is not proof of bus ownership; observed traffic establishes
  running state. Another daemon is never automatically stopped or restored.
- Overview previews use local native screencopy handles with a labeled fallback.
  Capture uses fixed tool argv and explicit copy/save. Clipboard history is
  opt-in, bounded, expiring session memory. Shared performance sampling runs only
  with consumers. Weather is opt-in with explicit location/network requests.
- Display Apply/Keep/Revert has an independent durable rollback watchdog. Owned
  appearance/shortcut integrations have recovery journals. Source-backed shortcut
  editing validates recognized Lua call sites; opaque/generated expressions stay
  read-only. This is not a generic Lua rewriter. Existing session authorization
  remains necessary for configuration or ownership changes.

## Installation and validation

Development scripts select this checkout's config path. The installer copies
`shell/` and the CLI/library scripts into owned XDG locations; package mode uses
its shared app root. Existing settings and foreign config names are preserved.
The bundled tone and wallpaper are runtime assets; native fixtures remain outside
the installed tree. No install/activation step silently enables autostart.

[Compatibility](compatibility.md) lists supported floors and optional APIs.
[Testing](testing.md) distinguishes offscreen/stub tests from native evidence.
[Capability status](capability-matrix.md) and [remaining work](roadmap-progress.md)
are the current status sources; dated decisions/reports preserve rationale.
