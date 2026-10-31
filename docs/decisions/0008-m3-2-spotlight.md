# M3.2 Spotlight on the focused monitor

## Status

Accepted for the source tree. The centered card, focused-monitor placement, and Super+Space handoff have not been shown on a Hyprland session.

## Context

The launcher opened on the bar's screen and sat near the top of that output. Search and the external request token both needed the monitor that is focused when the request arrives. A new install also needs a bar and workspace row that follow the connected outputs instead of assuming HDMI-A-1 and workspaces 4–6. The reference session still uses that layout through its existing settings file. The Lua workspace dispatcher that was confirmed on that session stays as it is.

## Decision

- `bar.targetMonitor` defaults to an empty string. Empty selects the focused Hyprland monitor when its name or description matches a Quickshell screen, otherwise the first screen. A non-empty value matches the Qt screen name, the Hyprland connector name, or the Hyprland description. A saved value that is not connected falls back the same way. No screens means no bar.
- `bar.workspaceIds` defaults to an empty list. Empty shows the positive workspace ids Hyprland currently reports on the bar's monitor, sorted, at most 12. A non-empty list keeps that order and still draws ids Hyprland has not created. The dispatch string is unchanged: `hl.dsp.focus({ workspace = N })` unless `bar.workspaceDispatch` is `legacy`.
- `scripts/launch.sh` copies defaults only when `settings.json` is missing. An existing file that names `HDMI-A-1` and `[4, 5, 6]` keeps both.
- Spotlight resolves the focused screen inside `openLauncher`, for Search and for the request token. It does not move if focus changes while it stays open. A missing focus reading uses the first connected screen. A screen that leaves the screen list closes the launcher.
- A new request token opens the launcher. The same path closes it when it is already open. The token present at startup does nothing. There is no second launcher process.
- The card is centered in logical pixels, at most 480 wide, and only the result list scrolls. The open fade is `Theme.motionOpen`. Reduced motion and a motion scale of 0 make that duration 0. Closing hides the layer immediately and clears the field and the focus grab.
- Super+Space is still a manual edit of the existing Lua bind, with a backup, after Search works. This tree does not write `binds.lua`, reload Hyprland, or change Noctalia or autostart.

## Consequences

Automatic workspace rows cannot show an empty workspace Hyprland has already destroyed. An explicit id list still can. If the Hyprland socket is down, an automatic row is empty and clicks stay ignored. `Hyprland.focusedMonitor` is read when a request arrives. If that property does not notify on focus changes, the automatic bar waits for the next screen or monitor refresh before it follows focus. A launcher request still reads the property at that moment.

Cloud checks do not show the card, launch an application, or press Super+Space. The handoff procedure is `docs/launcher-shortcut.md`.
