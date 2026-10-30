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
| `ShellRoot`, `Scope`, `Singleton`, `PanelWindow`, `Variants`, `SystemClock`, `ExclusionMode` | `Quickshell` | Entry, non-visual parents, per-screen instances, clock |
| `Hyprland` | `Quickshell.Hyprland` | Workspaces, monitors, toplevels, `dispatch`, `monitorFor` |
| `WlrLayershell` | `Quickshell.Wayland` | Layer namespace `swiftshell-bar` |
| `FileView`, `JsonAdapter`, `JsonObject` | `Quickshell.Io` | Settings file |

`PanelWindow.color` is fully transparent. `implicitHeight` is 28. Anchors are top, left, and right. `focusable` is false so the bar does not take keyboard focus from the session. Existing Super shortcuts stay where they are.

`SystemClock` uses minute precision. That is an update from the clock object, not a workspace poll.

`QtObject` has no default property. A child object written directly inside it fails to load. `BarHost` is a `Scope`, whose default property is `children`. `SettingsStore`, `HyprlandModel`, and `Theme` use Quickshell's `Singleton` type, which extends `Scope`. `FileView` stays a child of that singleton, and `JsonAdapter` stays a child of `FileView` because `adapter` is `FileView`'s default property. `SystemClock` stays inside `Item`, whose `data` property accepts non-visual objects.

Workspace activation prefers `HyprlandWorkspace.activate()`. The fallback string is `workspace <id>` passed to `Hyprland.dispatch`. Both are socket IPC. The historical Lua parse error from putting `hyprctl` syntax into the Lua config does not apply to this path, because this path does not call `hyprctl`.

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

- Shell screen name and Hyprland monitor name for HDMI-A-1 may differ. The matcher accepts either. If both differ from `HDMI-A-1`, the bar is not created and the log says no output matched.
- Focused title reads `title`, `activated`, `monitor`, and `workspace` on the toplevel object, then the attached `HyprlandToplevel` when those fields are empty. A Quickshell build that exposes neither will load and will show no title.
- `WlrLayershell.namespace` must be set before the layer surface connects. If the local module rejects the attached property, the shell will fail at load. The fallback is to remove the `Quickshell.Wayland` import and the namespace line from `shell/bar/BarWindow.qml`. The bar can still run; its layer name will be Quickshell's default.
- `exclusiveZone` writes force exclusion mode to normal inside Quickshell. Reservation therefore assigns the zone only when `bar.reserveSpace` is true. The default remains ignore.
- Light wallpaper can wash out `#F2F2F2` text. M1 does not add a scrim, because a scrim would be a bar background. Contrast on a light wallpaper is unverified.
- One notification daemon and the current global shortcuts stay with the existing session. This prototype does not register a notification service or a global bind.

## Explicitly out of scope

Popovers, launcher, settings GUI, tray, media, network, audio, Bluetooth, and Hyprland decoration changes are later milestones. They are not implemented here.
