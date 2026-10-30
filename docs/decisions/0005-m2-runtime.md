# M2 runtime stabilization

The CachyOS session loaded SwiftShell, drew the bar, and opened the calendar and control center while Noctalia was stopped. The same session rejected workspace clicks, logged a `targetScreens` binding loop, warned on a valid workspace id list, and showed windows over the bar. The installer dependency test failed there because real `qs` and `Hyprland` were on `PATH`.

## Dispatch

`HyprlandWorkspace.activate()` and the string `workspace <id>` both become `return hl.dispatch(workspace N)` under the Lua config. That is a syntax error for an existing workspace and for an empty one. Every click now sends `hl.dsp.focus({ workspace = N })` unless `Hyprland.usingLua` is false or `bar.workspaceDispatch` is `legacy`. `on_current_monitor` is not set. The id is an integer. This was checked against the Hyprland dispatcher wiki and against published click results for that expression. It has not been clicked again on the reference machine.

## Bar space

`reserveSpace: false` assigns only `ExclusionMode.Ignore`. `true` assigns only `exclusiveZone` to the logical bar height. The layer stays `WlrLayer.Top`, so true fullscreen still covers the bar. Hyprland fullscreen rules are not edited.

## Screens and settings

`targetScreens` is filled by a function. It is not a binding over Hyprland monitor state and `Variants`. Workspace ids are valid when they are array-like integer lists. `Array.isArray` is not the test. Malformed lists still fail validation.

## Focus diagnostic

`qt.qpa.wayland.textinput` disables the protocol when active focus leaves. The bar's keyboard focus is `None`, and an outside click drops `HyprlandFocusGrab` before Qt runs that disable, so the focused surface in the log is null. Close now clears the key scope before this process drops the grab, and open requests focus on the next frame. The log line is not filtered.

## Installer test

The dependency case no longer appends `/usr/bin`. Host `qs` cannot satisfy it. Stub `sudo` and `pacman` are the only package tools. Real `sudo` and `pacman` are not executed.
