# Compatibility

Supported native floor: **Quickshell 0.3.2, Hyprland 0.57, Qt 6.9**. The reference
CachyOS/NVIDIA session uses Qt 6.12, Hyprland Lua and mixed-scale DP-1 (1.0) /
HDMI-A-1 (1.25). These outputs are test evidence, not required names or resolutions.
Older Quickshell 0.2 investigation is historical, not a supported fallback target.
Qt's older offscreen CI runtime with stubs is a test environment, not a native
support promise.

## Runtime contracts

| API | Use and boundary |
|---|---|
| `ShellRoot`, `Scope`, `Singleton`, `Variants` | Composition and per-output lifetime; no unnamed children under QtObject |
| `PanelWindow`, `WlrLayershell` | Nonfocused bar/background and scoped overlays; logical coordinates and explicit exclusion mode |
| `FloatingWindow` | Native Settings and desktop utility windows; move/resize on the supported runtime |
| `Hyprland`, `HyprlandFocusGrab` | Native state, Lua dispatch and scoped popup dismissal; release before hiding |
| `DesktopEntries` | Asynchronous ObjectModel; rebuild catalog on `applicationsChanged`; parsed desktop execution |
| `FileView`, `JsonAdapter`, `Process` | Validated preference reads and fixed helper argv; atomic writes via Python |
| `PwObjectTracker` | Bind sink/source/stream nodes before using node audio; missing module stays behind Loader |
| MPRIS, SystemTray, UPower, Bluetooth | Typed service state with capability-dependent actions |
| `BackgroundEffect` / Regions | Dynamically loaded, capability-probed real blur; fallback if unavailable |
| `ScreencopyView` / native toplevel handles | Local overview previews; clients may provide no frame |
| Notification APIs | `expireTimeout` is **milliseconds** on installed 0.3.2; preserve tracked lifecycle, actions and replacement batching |
| QtMultimedia | Optional notification tone; module presence and output readiness are separate |

Quickshell attached C++ types cannot all be represented by QML stubs. The shell
load test's narrow unavailable-type exceptions do not certify native startup.
Some Qt implicit-size properties are read-only; retain the actual instantiation
regressions rather than trusting qmllint alone.

Hyprland Lua workspace requests use `hl.dsp.focus({ workspace = ... })` through
native dispatch. Legacy `workspace N` is a separate explicit mode. Display,
window, appearance and shortcut helpers verify their supported backend and keep
scope/recovery state; never reuse legacy text examples blindly. Source-backed
shortcut editing requires `luac` and recognized unambiguous source, otherwise it
is read-only. Live user Lua/monitor/bind changes still require authorization.

## Rendering

Layout and final bar metrics are logical pixels. Qt supplies effective window
DPR; do not multiply UI dimensions by DPR or scale a completed bar texture.
At untransformed raster density 1 the bar uses native vertically hinted text;
fractional/higher density uses Qt scalable text. Bar height, output scale and
icon/font sizes remain independent from compositor mode changes.

## Dependencies and optional integrations

Python 3 is required by runtime helpers. wayland-utils provides read-only protocol
capability inspection. Qt Quick, Layouts and Core are required. Dialogs and
folderlistmodel enable native wallpaper choice/scanning; absent modules retain
the tested path-entry fallback. PySide6 enables asynchronous multi-format
wallpaper analysis; bounded PNG analysis remains available without it.

NetworkManager, BlueZ, PipeWire, MPRIS, UPower and power-profiles-daemon are detected
rather than replaced. `wl-clipboard`, `grim` and `slurp` enable optional clipboard
and Capture operations. Secure locking requires Hyprlock; SwiftShell never
silently installs a locker. Hardware brightness has no packaged backend.
See [install](install.md) for package names and [capabilities](capability-matrix.md)
for remaining gates. No dependencies were added or removed by the cleanup.

## Launch and stop

```sh
qs --path /path/to/SwiftShell/shell --no-duplicate
qs kill --path /path/to/SwiftShell/shell
```

Use the repository scripts or installed CLI to select the right path. Stop adds
`--any-display` only if advertised by `qs kill --help`; this small CLI compatibility
check is intentional. The shell id is `swiftshell`, but shutdown selects the
config path. Noctalia is its own executable and must not be selected by a blanket
Quickshell kill. See [testing](testing.md) and the
[dated native evidence](reports/native-validation.md) for observed behavior.
