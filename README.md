# SwiftShell

A Quickshell desktop shell for Hyprland: transparent per-output bars, Spotlight,
a native Settings window, wallpaper, notifications and desktop tools. Hyprland
owns application windows; system services own audio, devices and power.

SwiftShell is an **alpha**, with local mixed-scale validation rather than broad
hardware certification. See the [capability matrix](docs/capability-matrix.md)
for implemented features and remaining acceptance work.

## Run from a checkout

Requires Quickshell 0.3.2+, Hyprland 0.57+ and Qt 6.9+ with Python 3 and
wayland-utils. The reference session uses Qt 6.12 and Hyprland's Lua dispatcher.
See [installation](docs/install.md) for packages and optional integrations.

```sh
scripts/check.sh
scripts/launch.sh
# From another terminal:
scripts/stop.sh
```

Launch uses `qs --path` for this checkout's `shell/` directory. Stop selects only
that path. Neither command stops Noctalia, installs shortcuts, edits Hyprland
configuration or changes autostart. Running two bars on one output can overlap;
coordinate the preview and reservation settings before starting another shell.

## Install

```sh
git clone https://github.com/DGProjectAlpha/SwiftShell.git
cd SwiftShell
./install.sh
swiftshell doctor
swiftshell activate
swiftshell start
```

The installer owns its XDG app directories and preserves existing preferences.
Activation registers a desktop entry and a free Quickshell config name; it does
not enable autostart or replace another shell. `swiftshell stop` stops the
installed copy. `swiftshell uninstall` keeps settings unless explicitly told to
purge them. The Arch package remains a draft.

## Current behavior

- Per-output bars support size, edge, background, widgets, ordering and clock
  preferences. **Apply to** selects which bars an edit affects; **Where bars
  appear** controls global placement. Fonts and icons render at their final
  logical size, with Qt applying the output density once.
- Settings is a movable/resizable native window with searchable pages, shared
  controls, persisted sections and Collapse all / Expand all. Preferences use
  validated, backed-up, atomic writes under `$XDG_CONFIG_HOME/swiftshell`.
- Spotlight provides app grids, favorites, recent apps, Settings/window search,
  calculations and explicit URL/web actions. Global shortcuts require opt-in.
- Wallpaper supports per-output images, folder selection, slideshow and regional
  contrast. Audio, media, tray, network/Bluetooth and power expose real backend
  state with capability-dependent controls.
- Optional notifications support history, actions, replies, quiet hours and
  sounds. Clipboard history and weather start disabled. Capture, overview and
  performance widgets share service adapters across displays.
- Display edits use staged Apply/Keep/Revert with an independent rollback helper.
  Desktop appearance and shortcut integrations are explicit, reversible actions.

Missing capabilities have fallbacks; a source test is not proof of hardware
behavior. Noctalia, user-authored Lua, existing binds and service ownership must
remain untouched unless the owner explicitly authorizes an integration.

## Repository map

| Path | Purpose |
|---|---|
| `shell/shell.qml` | Runtime entry and scoped IPC |
| `shell/bar`, `popovers`, `settings`, `launcher`, `overview`, `wallpaper`, `notifications`, `clipboard`, `screenshots` | Shell surfaces |
| `shell/components`, `themes` | Shared controls, materials, typography and motion |
| `shell/services`, `helpers`, `logic` | State/adapters, fixed Python backends and pure JavaScript |
| `shell/config`, `shell/assets`, `assets` | Defaults, locker config, tone and bundled wallpaper |
| `scripts`, `packaging` | Development checks, install/CLI and draft system package |
| `tests/qml`, `stubs`, `live`, `helpers` | Offscreen tests, API stand-ins and opt-in native probes |
| `docs/decisions`, `docs/reports` | Design rationale and dated evidence, not startup instructions |

## Documentation

[User guide](docs/user-guide.md) · [First run](docs/first-run.md) ·
[Install/recovery](docs/install.md) · [Troubleshooting](docs/troubleshooting.md)

[Architecture](docs/architecture.md) · [Compatibility](docs/compatibility.md) ·
[Testing](docs/testing.md) · [Remaining work](docs/roadmap-progress.md) ·
[Cleanup audit](docs/reports/repository-cleanup-2026-11-08.md)

Contributors and coding agents: read [AGENTS.md](AGENTS.md), the
[task kickoff](docs/CURSOR_START_HERE.md) and the
[master product specification](docs/MASTER_IMPLEMENTATION_SPEC.md) before editing.
The specification describes product requirements; it is not a current feature
inventory or authorization to implement another milestone.
