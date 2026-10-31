# SwiftShell — Instructions for AI Coding Agents (Cursor, Codex, etc.)

READ README.md FIRST. Treat it as the source of product truth. This file governs day-to-day development behavior.

## Hard safety boundaries

1. **Never modify, remove, disable or overwrite the working Noctalia shell**, its configuration, startup, notification owner, or services without explicit user authorization.
2. **Never mutate live Hyprland Lua configuration** (including binds.lua, monitors.lua, decorations.lua), autostart, systemd user services, display/HDR modes, or session settings without prior explicit authorization and a recovery plan.
3. Work inside this repository. Do not use blanket shell redirection to write external config files. No `sudo` or package installation without approval.
4. Never force-push, `git reset --hard`, `git clean -fd`, or delete work you did not author.
5. Do not claim to have tested graphics, compositor behavior, or monitor scaling unless run locally against the real setup.
6. Do not silently replace working binds. The existing 60% keyboard workflow is core product context.
7. Don't log secrets, credential headers, cookies, network passwords, file search contents, or user-private paths.
8. No fake controls: mock interfaces must be marked as previews, and interactive buttons must do what their labels promise.

## Product aesthetic

Extreme restraint: fully transparent top bar, no background strip, no decorative borders, compact components, grayscale/neutral palette, optional faint top-edge readability gradient, wallpaper-adaptive muted tint only where required, softly blurred popovers with flat buttons. Avoid Material Design, oversized colorful cards, pill-heavy dashboards, and gratuitous animation. Accessibility and readability remain essential.

## Architecture

Quickshell + Qt6/QML shell surfaces; Hyprland owns window behavior; OS service adapters own audio/network/etc. Verify runtime APIs before committing version-dependent code. Separate presentational components, service adapters, models, theme tokens, and settings persistence. Use event-driven state. Keep a standalone development mode with explicit launch/stop steps.

## Required agent workflow

For each task:
1. Read README.md plus relevant docs and inspect existing source before editing.
2. State the smallest deliverable and any risk to the running desktop.
3. Determine which claims can be verified locally; document unknowns.
4. Implement a coherent vertical slice, not speculative scaffolding or ten unfinished features.
5. Run available formatting/static/tests and record exact results.
6. Perform manual UI tests only in an approved isolated mode.
7. Report files changed, test evidence, assumptions, known limitations, and recovery instructions.
8. Commit a reviewable change.

## First task ONLY

Read-only runtime audit (Quickshell, Hyprland Lua wrapper, monitors, Noctalia ownership) and M0/M1: a named, separately launched Quickshell prototype with transparent bar on HDMI-A-1, workspace indicators and clock. No Noctalia replacement, autostart change, shortcut capture or notification daemon. Use version-accurate launch commands and verify shutdown/recovery.

## Coding quality

- Central tokens for visual parameters and reusable QML components.
- Validate inputs and settings. Use atomic persisted writes for preferences.
- Prefer typed IPC / native integrations to ad-hoc shell commands. Escape user input; do not execute arbitrary launcher queries in a shell.
- Prefer stable public APIs and document compositor/version compatibility.
- Respect multiple monitor scales and hotplug.
- Small modules, descriptive names, no unnecessary dependencies.
- Favor measurable behavior over marketing claims.
- When uncertain, state the limitation instead of inventing a capability.

## Decision priority

Safety > correct behavior > accessibility > performance > visual polish > experimental features.

Do not interpret README's long-term roadmap as permission to implement M2–M8 in the first task.

## Repository status

M0/M1, M2, and the M3 launcher source live in `shell/`. The reference session is CachyOS, Lua-based Hyprland, and Noctalia as its own `noctalia` executable rather than a `qs` process. That session's settings file keeps DP-1 on workspaces 1–3 and HDMI-A-1 on 4–6. The monitors use mixed scale. Those ids are personal settings, not the new-install default. On that session, with Noctalia stopped, SwiftShell has loaded, the bar has rendered, the calendar and control center have opened, and workspace switching works after the Lua dispatch fix. The same session showed a `targetScreens` binding loop, a false `bar.workspaceIds` warning for `[4, 5, 6]`, bar overlap while `reserveSpace` was false, a Wayland text-input diagnostic, a launcher that did not find Dolphin or Helium, monogram icons, and `BarLabel is not a type` until `shell/bar/BarWindow.qml` imported `../components`. M3.2 centers Spotlight and resolves the focused monitor in source. Do not mark that placement, exclusive-zone behavior, focus return, application launch, theme icons, or the refreshed catalog as hardware-verified from cloud tests. The checklist is `docs/testing.md`. Do not edit Noctalia, `binds.lua`, or autostart. Super+Space stays where the user put it until they apply `docs/launcher-shortcut.md` themselves.

## Rules learned from the running session

- Read the Quickshell type page for the supported version before using a property. `DesktopEntries.applications` is an `ObjectModel`, and its scan result arrives on `applicationsChanged`.
- Do not send `workspace N` through Hyprland's Lua dispatcher. The working form is `hl.dsp.focus({ workspace = N })` unless `bar.workspaceDispatch` is `legacy`.
- Do not use a project QML type without the import that provides it. `tests/static_check.py` fails the tree when that import is missing.
- Add a regression for every defect. A stub that never loads the failing file does not count.
- Do not hide a warning until its cause is known.
- Do not change Noctalia, Hyprland, or existing keybinds. Super+Space stays where the user put it until they apply `docs/launcher-shortcut.md` themselves.
- Keep each change reversible, and say what the cloud run did not execute.
- A green `scripts/check.sh` is not a CachyOS pass.
