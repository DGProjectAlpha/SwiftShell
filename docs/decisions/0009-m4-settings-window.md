# M4.0 Settings window

## Status

Accepted for the source tree. The window has not been shown on a Hyprland session. Movable and resizable behavior is not verified.

## Context

M3.2 is merged. Spotlight can open on the focused monitor in source, and Gate A hardware checks are still not done. The master specification's next slice is a real settings toplevel, a versioned schema, and the appearance controls that already persist. It is not a sidebar of unfinished categories and it is not a blur slider.

## Decision

- The window type is Quickshell 0.2 `FloatingWindow`. The 0.2 page lists `title`, `minimumSize`, and `maximumSize`. Width and height are assigned once in `Component.onCompleted` and again only when the window closes, so a user resize is not overwritten while the window is open. `startSystemMove` and `startSystemResize` are not called. Those methods are not on the 0.2 page. Hyprland can still move a normal toplevel with its own binds. This tree does not add a bind and does not edit `binds.lua`.
- `shell/shell.qml` loads the window with a `Loader`. A type the installed Quickshell cannot parse fails that loader only. The bar stays up, and `SettingsModel.noteLoadFailed()` records the reason.
- One `SettingsModel` instance. Spotlight's Settings row and the control center Settings button call `show()`. A second call increments `focusTicket` and asks the existing window to activate. There is no second shell process.
- The only page is Appearance. Dark, light, reduced motion, the top gradient, panel opacity, and corner radius call the existing `SettingsStore` setters. `appearance.panelBlur` remains a stored number. The page states that Quickshell 0.2 has no `BackgroundEffect` and that this shell does not change Hyprland blur rules. The surface is the theme scrim.
- Schema version 2 is the written form. Version 1 and a missing version stay valid inputs. `migrationDecision` returns `migrate` only when validation succeeds. The store writes `settings.json.bak-swiftshell` first. The settings file is rewritten as version 2 only after that backup reports saved. An invalid or unreadable file is not rewritten by the migration path.
- `JsonAdapter` drops keys it does not declare before JavaScript sees the file. `extensionsJson` preserves unknown keys when `migrationDecision` is given the raw object. The running store's backup is the adapter snapshot, so a hand-added key is not recovered from that backup. Copy `settings.json` aside before the first launch if it contains keys outside the documented schema. The reference file's `HDMI-A-1` monitor and workspace ids `[4, 5, 6]` are documented keys and stay.
- Categories other than Appearance are not listed as controls. `settingsWindow.category` accepts only `appearance`.

## Consequences

Cloud checks compile the window against a `FloatingWindow` stub. They do not show it, move it, or prove the compositor's resize. Gate A for M3.2 remains not run. The next source milestone is M4.1, navigation and the remaining real appearance controls, after this window is reviewed. That milestone is a separate change.
