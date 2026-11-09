# SwiftShell — Instructions for AI Coding Agents (Cursor, Codex, etc.)

Read these before editing code, in this order:

1. `docs/MASTER_IMPLEMENTATION_SPEC.md` — the long-term product and milestone contract. Read the current file, not a remembered summary.
2. `docs/CURSOR_START_HERE.md` — the kickoff sequence and completion format.
3. `README.md` — what the repository currently claims is running.
4. This file — day-to-day safety and the rules learned from the running session.

The master specification does not replace the safety boundaries below or in its own section 0.2. When a milestone asks for display changes, shortcuts, blur rules, notification ownership, or autostart, those stay opt-in and unapplied until the owner authorizes them. Do not implement several milestones in one pull request. Do not treat a green `scripts/check.sh` as a Hyprland pass. Do not merge unverified work to `main` unless the owner asks.

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

Follow the user’s current task and the master specification one coherent increment at a time. Historical milestone assignments do not restart development at M0 or M4.0. The roadmap never overrides these safety boundaries.

## Current repository and entry points

- Runtime: `shell/shell.qml`, with per-output bars, Spotlight, overview, Capture,
  clipboard, wallpaper and optional notifications; Settings is loaded lazily.
- State and OS adapters: `shell/services/`; fixed Python backends:
  `shell/helpers/`; pure algorithms: `shell/logic/`. Shared presentation belongs
  in `shell/components/` and `shell/themes/`.
- `README.md`, `docs/architecture.md` and `docs/compatibility.md` describe the
  current tree. `docs/capability-matrix.md` distinguishes implementation from
  hardware acceptance; `docs/testing.md` lists checks and links dated evidence.
  Read the relevant decision records, not every historical report for every task.
- `scripts/check.sh` runs repository checks. `scripts/launch.sh` and
  `scripts/stop.sh` select this checkout only. Native tests are opt-in and live
  fixtures belong in `tests/live/`, outside the installed `shell/` tree.
- Preserve legacy settings identifiers and migration paths when removing old
  implementations. Verify dynamic Loader sources, qmldir exports, IPC strings,
  installer manifests and native fixtures before declaring code unused.
- The reference workstation has mixed-scale outputs and uses Hyprland Lua.
  Connector names and workspace choices are personal preferences, never defaults.
  Noctalia runs as its own `noctalia` executable. Never kill it with a `qs` command.

## Rules learned from the running session

- While any user app/game is fullscreen (including client-requested fullscreen after compositor demotion), do not launch native foreground/fullscreen fixtures, move focus/cursor, or run interactive UI tests on another monitor. Those tests disrupted the game despite HDMI placement and no-initial-focus rules. Use read-only diagnostics and automated/offscreen checks until the owner stops gaming. Do not add or use an `--allow-active-game` bypass. Native interactive tests must run the read-only `tests/live/fullscreen_guard.py` preflight before creating windows, rules or sending input.

- Read the Quickshell type page for the supported version before using a property. `DesktopEntries.applications` is an `ObjectModel`, and its scan result arrives on `applicationsChanged`.
- Do not send `workspace N` through Hyprland's Lua dispatcher. The working form is `hl.dsp.focus({ workspace = N })` unless `bar.workspaceDispatch` is `legacy`.
- Do not use a project QML type without the import that provides it. `tests/static_check.py` fails the tree when that import is missing.
- Add a regression for every defect. A stub that never loads the failing file does not count.
- Do not hide a warning until its cause is known.
- Do not change Noctalia, Hyprland, or existing keybinds. Super+Space stays where the user put it until they apply `docs/launcher-shortcut.md` themselves.
- Keep each change reversible, and say what the cloud run did not execute.
- A green `scripts/check.sh` is not a CachyOS pass.
