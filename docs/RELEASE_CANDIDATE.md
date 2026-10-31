# Release candidate engineering report

## Assessment

`cursor/rc-release-915d` integrates the reviewed settings, QML gate, wallpaper, notification, folder-picker, and packaging repairs on top of `416d835`. Repository checks pass. This is a **hardware-validation candidate**, not a daily-driver release: no Quickshell/Hyprland session or target hardware was available in the cloud VM.

## Integrated repair changes

- PR #34: transactional settings validation, migration, backup protection, queued writes, and temporary-filesystem tests.
- PR #35: strict QML compilation gate, explicit Qt runtime modules, dialog dependency reporting, and a notification parse repair.
- PR #36: state-preserving slideshow updates, per-output transition barriers, two-slot crossfade, crop-aware per-output contrast, and bounded PNG inflate.
- PR #37: notification policy-before-track routing, replacement observation, native close lifecycle, honest ownership state, and focused-output placement.
- PR #38: optional native slideshow folder selection, sorted/bounded enumeration, removal monitoring, and explicit fallback.
- PR #39: functional system-package runtime roots, package manifest, safe package-mode uninstall, and package-layout tests.

These PRs are assembled and tested on the release branch. They are not described as merged on GitHub until a maintainer merges them.

## Capability status

| Area | Repository status | Live status |
|---|---|---|
| Settings integrity | Implemented and filesystem-tested | NOT RUN in Quickshell |
| QML component gate | Strict mock compile; CI modules explicit | Real Quickshell startup NOT RUN |
| Wallpaper/slideshow | Implemented with multi-output generation barriers | Crossfade, hotplug, GPU behavior NOT RUN |
| Adaptive contrast | Per-output crop-aware PNG sampling | DP-1/HDMI-A-1 pixels NOT RUN |
| Notifications | Native lifecycle repaired; ownership state is evidence-based | D-Bus conflict/handoff/actions NOT RUN |
| Image/folder picker | Implemented behind optional Qt modules | Dialog interaction NOT RUN locally |
| Audio/media/tray/battery | Existing typed integrations retained | Hardware/services NOT RUN |
| NetworkManager | Unavailable: no packaged typed backend | NOT RUN |
| Brightness | Unavailable: internal backlight/DDC backends not packaged | NOT RUN |
| Bluetooth discovery | Unavailable: Quickshell 0.2 exposes discovery state, not a start API | Known-device actions NOT RUN |
| Display Apply/Revert | Disabled pending crash-safe helper and independent revert | NOT RUN |
| Shortcut installation | Disabled pending owned, reversible Lua integration | NOT RUN |
| Real backdrop blur | Optional compositor rule not installed or written | NOT RUN |
| Arch package | Runtime layout tested hermetically | `makepkg`/pacman NOT RUN |

## Required CachyOS workstation validation

1. Keep Noctalia running. Launch SwiftShell only with `scripts/launch.sh`; do not add autostart.
2. Confirm no Noctalia process, config, notification owner, Hyprland Lua file, bind, monitor mode, or service changes.
3. On DP-1 (2560×1440, ~165 Hz) and HDMI-A-1 (1920×1080, scale 1.5), verify bar placement, logical height, typography, pointer targets, exclusive-zone behavior, fullscreen coverage, and hotplug.
4. Run a two-image slideshow across both outputs. Change interval, fade, order, reduced motion, and image list during preload and fade. Check for black frames, desynchronization, texture flashes, or unexpected image resets.
5. Test Cover and Contain with landscape, portrait, ultrawide, split black/white, JPEG, WebP, and oversized PNG images. Verify each output's bar contrast follows its own visible crop.
6. With the current notification daemon active, request SwiftShell ownership and verify it remains `waiting` and does not intercept traffic. Test ownership only in a recoverable session, then verify replacement, action, DND, critical, expire, dismiss, and release behavior.
7. Verify PipeWire sink/source and stream controls, MPRIS, tray menus, UPower, and known Bluetooth-device actions. Network, brightness, discovery, display Apply, and shortcut installation should remain unavailable rather than simulate success.
8. Observe idle CPU, memory growth, NVIDIA GPU activity, frame pacing at 165/60 Hz, and image-transition behavior using local tools. No performance number is claimed by this report.
9. Run fresh install, update, reinstall, activate/deactivate, settings corruption recovery, rollback, uninstall, and optional purge in a disposable user account. Build the PKGBUILD only after choosing a license and checksum.

## Recovery

- Stop only this checkout: `scripts/stop.sh`.
- Stop an installed copy: `swiftshell stop`.
- Remove registration without removing settings: `swiftshell deactivate`.
- Restore the protected settings backup: `swiftshell rollback-settings`.
- Remove a user install: `swiftshell uninstall`; add `--purge-settings` only when settings deletion is intended.
- For a system package, `swiftshell uninstall` removes per-user activation only; remove package files with pacman.
- If path-based stop cannot identify the instance, inspect `qs list --all` and kill only the exact SwiftShell instance ID. Never kill all Quickshell processes while Noctalia is running.

## Release decision

The repository is materially safer and its automated gates are less misleading. It is not yet a production daily-driver shell because major system integrations remain deliberately unavailable and all compositor, D-Bus, hardware, fractional-scale, performance, and coexistence claims are unverified. The next release decision should be based on the workstation checklist, not on the green mock suite alone.
