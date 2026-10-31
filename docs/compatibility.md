# Compatibility

Versions below are the APIs this prototype was written against. They were taken from the Quickshell documentation and source for the 0.2 and 0.3 lines. They were not executed on the target CachyOS machine. Run `qs -V` locally and treat a mismatch as a load failure to fix, not as a working bar.

## Expected stack

| Piece | Expectation |
|---|---|
| Session | Hyprland on Wayland. The Lua configuration is left unchanged. |
| Quickshell | `qs` or `quickshell` on `PATH`, built with `Quickshell.Hyprland` and `Quickshell.Wayland` layer shell. |
| Qt | Qt 6. QML modules: `QtQuick`, `QtQuick.Layouts`, `QtCore`. |
| Settings path | `StandardPaths.GenericConfigLocation`, then `/swiftshell/settings.json`. |

## Quickshell types used

| Type | Module | Use |
|---|---|---|
| `ShellRoot`, `Scope`, `Singleton`, `PanelWindow`, `PopupWindow`, `PopupAnchor`, `PopupAdjustment`, `Variants`, `SystemClock`, `ExclusionMode`, `Region` | `Quickshell` | Entry, non-visual parents, per-screen instances, popups, clock |
| `Hyprland`, `HyprlandFocusGrab` | `Quickshell.Hyprland` | Workspaces, monitors, toplevels, `dispatch`, `monitorFor`, popup dismissal |
| `WlrLayershell` | `Quickshell.Wayland` | Namespace `swiftshell-bar`, layer `Top`, keyboard focus `None` |
| `FileView`, `JsonAdapter`, `JsonObject` | `Quickshell.Io` | Settings file and the launcher request token |
| `Pipewire`, `PwObjectTracker` | `Quickshell.Services.Pipewire` | Default sink volume and mute |
| `DesktopEntries`, `DesktopEntry` | `Quickshell` | Application index. `execute()` launches `command` without a shell. `execString` is not used |
| `Quickshell.execDetached` | `Quickshell` | Fixed `loginctl` power arguments after a second confirmation |

`PanelWindow.color` is fully transparent. `implicitHeight` is 28. Anchors are top, left, and right. `focusable` is false so the bar does not take keyboard focus from the session. Existing Super shortcuts stay where they are.

`SystemClock` uses minute precision. That is an update from the clock object, not a workspace poll.

`PopupWindow` is the 0.2 popup surface. Its anchor uses `anchor.window`, `anchor.rect`, `Edges`, and `PopupAdjustment.Flip | PopupAdjustment.Slide`. The rect is filled from `contentItem.mapFromItem` inside the `anchoring` signal. `QsWindow.itemRect` is documented as `contentItem.mapFromItem(item, 0, 0, 0, 0)`, so it is not a sized anchor. The window starts transparent with `surfaceFormat.opaque: false`. Quickshell documents that an opaque color applied before the first show cannot become transparent later. `Qt.rgba` takes components from 0.0 to 1.0. Palette bytes are divided by 255 before they reach it. Hex literals such as `#F2F2F2` are already QML colors.

`HyprlandFocusGrab` is the 0.2 click-outside path. It needs `hyprland-focus-grab-v1`. The shell sets `active` and does not set `PopupWindow.grabFocus`. That property is absent from the 0.2.0 page and present on the 0.3.1 page. `setActive(false)` releases the grab without emitting `cleared`.

`BackgroundEffect` and `ext-background-effect-v1` appear in the 0.3 docs, not in 0.2.0. The attached object has to be declared in QML. A JavaScript lookup does not construct it. Naming the type in a file that 0.2.0 parses makes that file fail to load, and this tree does not assume the later version-gated preprocessor. Blur is unsupported. The scrim is the panel surface. Hyprland blur rules are left unchanged.

PipeWire volume uses `Pipewire.defaultAudioSink`, `PwObjectTracker.objects`, and `PwNodeAudio.volume` / `muted`. Those properties are documented as invalid until the node is bound. The audio file is loaded with a `Loader`, so a build without the PipeWire module does not take the bar down.

`QtObject` has no default property. A child object written directly inside it fails to load. `BarHost` is a `Scope`, whose default property is `children`. `SettingsStore`, `HyprlandModel`, and `Theme` use Quickshell's `Singleton` type, which extends `Scope`. `FileView` stays a child of that singleton, and `JsonAdapter` stays a child of `FileView` because `adapter` is `FileView`'s default property. `SystemClock` stays inside `Item`, whose `data` property accepts non-visual objects.

`Column`, `Row`, `Grid`, `Flow`, `Loader`, `Text`, `TextInput`, `TextEdit`, and `Image` inherit Qt's `QQuickImplicitSizeItem`. That type calculates `implicitWidth` and `implicitHeight`. Assigning either property stops the shell before the next file is compiled, with `Invalid property assignment: "implicitWidth" is a read-only property` (or `implicitHeight`). `Item`, `Rectangle`, `MouseArea`, `FocusScope`, the layout types, `PanelWindow`, and `PopupWindow` still accept an implicit size. The calendar and the control center are `Item`s for that reason. The inner column is given the item's width. A `Loader` is left to adopt the loaded item's implicit size. `qmllint` 6.4.2 does not report the assignment, because it follows the writable property on `Item` and misses the read-only override.

Workspace activation sends `hl.dsp.focus({ workspace = <id> })` through `Hyprland.dispatch` for Lua configs. Quickshell 0.2's `HyprlandWorkspace.activate()` is documented as `dispatch("workspace " + name)`. That string is what the CachyOS session rejected: `return hl.dispatch(workspace 5)` with `')' expected near '5'`. The shell does not call `activate()`. `Hyprland.usingLua` exists on the Quickshell 0.3.2 page and is not on the 0.2 page. The code reads it with a bracket lookup. A missing property keeps the Lua request. `bar.workspaceDispatch: "legacy"` is the override for a text dispatcher. Neither form calls `hyprctl`.

## Launch

```sh
qs --path /path/to/SwiftShell/shell --no-duplicate
```

`--path` runs this checkout without registering it as the default Quickshell config and without copying it over Noctalia. `--no-duplicate` exits if that same config is already running.

```sh
qs kill --path /path/to/SwiftShell/shell
```

Quickshell 0.2.0 accepts `--path` and `--no-duplicate` on the main command, and `kill --path` plus `kill --id`. The `--any-display` kill flag was added after 0.2.1. `scripts/stop.sh` and `swiftshell stop` read `qs kill --help` and pass `--any-display` only when that build lists it. On 0.2.0, kill still selects this config path and only considers instances on the current display connection. The selector is never every Quickshell process.

`//@ pragma ShellId swiftshell` is set so Quickshell state for this config is identifiable. Kill selection uses the path, not the shell id.

## Installation

`./install.sh` and `swiftshell` are the distributable entry points. They copy files into XDG data, config, and state directories and can run `qs -V` and `Hyprland --version` as read-only probes. Optional package installation is `pacman` on Arch-based systems and only runs with `--install-deps`. The version floors in `scripts/lib/deps.sh` are documented assumptions, not measurements from the target machine. See `docs/install.md`.

## Behavior that depends on the local compositor

- A saved `bar.targetMonitor` may be a Qt screen name, a Hyprland connector name, or a Hyprland monitor description. An empty preference uses `Hyprland.focusedMonitor` when that object is available, then the first Quickshell screen. A preference that matches nothing uses the same fallback. Spotlight reads `Hyprland.focusedMonitor` again when it is requested. If that property does not notify, the automatic bar moves on the next monitor refresh rather than on every focus change. The launcher request still reads the property at that moment.
- Focused title reads `title`, `activated`, `monitor`, and `workspace` on the toplevel object, then the attached `HyprlandToplevel` when those fields are empty. A Quickshell build that exposes neither will load and will show no title.
- `WlrLayershell.namespace` must be set before the layer surface connects. The bar also sets `layer` to `WlrLayer.Top` and `keyboardFocus` to `WlrKeyboardFocus.None`. Both are on the Quickshell 0.2.0 `WlrLayershell` page. `Top` is documented as above normal windows and below fullscreen windows. `Overlay` is not used. If the local module rejects the attached property, the shell will fail at load. The fallback is to remove the `Quickshell.Wayland` import and the attached lines from `shell/bar/BarWindow.qml`. The bar can still run; its layer name and keyboard focus will be Quickshell's defaults, which are the same `Top` and `None`.
- `exclusiveZone` writes force exclusion mode to normal inside Quickshell, and a write of the same value does not call the setter. `bar.reserveSpace: false` assigns only `ExclusionMode.Ignore` (Wayland zone `-1`). `true` assigns the logical bar height when it changed and always assigns `ExclusionMode.Normal`. Quickshell scales the logical height to native pixels. True fullscreen still covers a `Top` layer. Hyprland's fullscreen rules are not edited.
- Light wallpaper can wash out `#F2F2F2` text. M1 does not add a scrim, because a scrim would be a bar background. Contrast on a light wallpaper is unverified.
- One notification daemon and the current global shortcuts stay with the existing session. This prototype does not register a notification service or a global bind.

## Compatibility matrix

"Verified" here means the cloud checks named in `docs/testing.md`. It does not mean a Hyprland session showed the result.

| Feature | Quickshell 0.2.0 | Later Quickshell | This tree |
|---|---|---|---|
| Transparent `PanelWindow` bar | Documented | Documented | Launched on CachyOS with Noctalia stopped. Cloud checks still do not show pixels |
| `PopupWindow` and `PopupAnchor` | Documented. `anchoring` is the map point | Documented | Calendar and control center opened on CachyOS. Placement math is unit-tested. This cloud run did not show them |
| `contentItem.mapFromItem` sized rect | Qt Quick, logical pixels | Same | Implemented, not runtime-tested |
| `QsWindow.itemRect` | Documented as a 0×0 map | Same documented equivalent | Not used |
| `HyprlandFocusGrab` | Documented. Needs `hyprland-focus-grab-v1` | Documented | Implemented, not runtime-tested. Missing protocol logs a warning and does not grab |
| `PopupWindow.grabFocus` | Absent | Present in 0.3.1 | Not used |
| `BackgroundEffect` | Absent | 0.3+ attached property. Needs `ext-background-effect-v1` | Unsupported. Scrim fallback is what renders |
| PipeWire default sink | `Pipewire.defaultAudioSink`, `PwObjectTracker`, `PwNodeAudio.volume` / `muted` | Same family | Implemented, not runtime-tested. A missing module stays inside the audio `Loader` |
| `SystemClock`, `Variants`, `FileView`, `WlrLayershell.namespace` | Documented | Documented | Implemented, not runtime-tested |
| Network, Bluetooth, media, power menu beyond the launcher confirmations, file search | Not part of the verified launcher | Not implemented here | Deferred. The launcher does not invent those results |
| Launcher window | `DesktopEntries`, `applicationsChanged`, `Quickshell.iconPath(icon, true)`, and `Hyprland.focusedMonitor` are on the 0.2 pages | The scan result is queued before `applicationsChanged`. `focusedMonitor` may be null | Implemented. The CachyOS session opened an earlier launcher and did not find Dolphin or Helium. The centered card and focused-monitor placement have not been launched with `qs` here |
| Wallpaper surface | `PanelWindow`, `WlrLayer.Background`, `WlrLayershell.namespace` | Same family | One layer per `Quickshell.screens` entry, in source. Not shown on a session. Sampling the picture for tint is still not implemented |
| Wallpaper sampling | PNG bytes are inflated and unfiltered in `shell/logic/png.js` | No `Canvas` and no image-pixel API in this Qt Quick build | PNG top edge only. Jpeg and webp display and are reported as not sampled. Not shown on a session |
| `FloatingWindow` settings toplevel | Documented in 0.2.0 with `title`, `minimumSize`, and `maximumSize` only. `closed` is on `QsWindow`. Client move and resize methods are later | `startSystemMove` and `startSystemResize` appear after 0.2 | Loaded through a `Loader`. Size is assigned once. Not shown on a Wayland session in this run |

## Explicitly out of scope

Tray, media controls, network management, Bluetooth, and Hyprland decoration changes are later milestones. PNG top-edge sampling is in the wallpaper page. Jpeg and webp are not sampled. The settings window is a `FloatingWindow` with Appearance, Top bar, Wallpaper, Displays, and Shortcuts pages. The shortcut page stores preferred chords and does not read or write compositor binds. It does not edit Hyprland. The wallpaper layer is a background `PanelWindow` and does not stop another wallpaper program. The launcher's power rows call `loginctl` only after a second confirmation. Panel blur is unsupported on the current compatibility floor rather than deferred behind a fake effect. The display page is a preview and does not send a layout.
