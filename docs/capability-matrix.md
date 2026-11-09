# Capability status

As of 2026-11-08. **Implemented** means present with repository coverage.
**Local evidence** means the dated reference-session checks below, not certification
of all hardware, every workflow or every later commit. This remains an alpha.

| Area | Implementation and local evidence | Remaining acceptance / limits |
|---|---|---|
| Bars and mixed scale | Per-output geometry, material, layout and visibility; native two-output rendering and persistence checks | Physical hotplug, other DPI/hardware combinations, sustained GPU load |
| Bar text/icons | Final-size metrics without texture magnification; native size captures on both outputs | Broader fonts/output configurations |
| Settings | Native window, pages, search, persistence, shared controls; local move/resize and initial UI/blur checks | Full accessibility and clean-user acceptance |
| Spotlight | App grid, favorites, Settings/window search, local providers; native interaction evidence | Broad desktop-entry and catalog performance matrix |
| Wallpaper | Per-output images, folder scan, slideshow, crop contrast; local rendering evidence | Physical disconnect during fades, long resource profiling |
| Blur/material | Native rounded backdrop on supported reference protocol; fallback elsewhere | Unsupported compositor/GPU combinations |
| Displays | Staged modes/topology with independent Apply/Keep/Revert watchdog; native transaction/recovery evidence | Physical hotplug, unsupported hardware modes; no speculative HDR promise |
| Shortcuts | Effective viewer, owned actions and source-backed edits with validation/undo; native recorder evidence | Opaque/generated Lua stays read-only; no arbitrary rewrite |
| Audio/media/tray | Shared PipeWire/MPRIS/native tray controls; local fixture/service checks | Wider device hotplug and real app combinations |
| Network/Bluetooth/power | Capability-detected real controls, profiles and operation state; native fixtures/snapshots | Real Wi-Fi authentication, pairing and hardware-specific actions need owner testing |
| Notifications | Opt-in host, policy/history/actions/replies/sounds; native protocol/fixture evidence | General daemon handoff/restore, persistent-history privacy design |
| Capture/clipboard/performance | Native surfaces, typed helpers, opt-in bounded clipboard and shared telemetry; local tests | Long-running load, sensitive real clipboard and broader sensors |
| Weather | Opt-in provider-backed search, cache and forecasts; local navigation/service tests | Provider/network availability; location is never automatic |
| Lock/session | Restored Hyprlock path and non-locking PAM probe; scoped helper tests | Physical lock/unlock, suspend/resume, logout/reboot acceptance |
| Install/package | Hermetic install/reinstall/rollback/uninstall and shared-root layout tests | Clean-user live install, Arch package build, chosen license/tag/checksum |
| Release | Repository CI definition and local test suite | Hosted CI result must be observed separately; no stable certification |

Command-level evidence and explicit NOT RUN notes are in the
[native validation record](reports/native-validation.md). Use
[testing](testing.md) for current checks and [remaining work](roadmap-progress.md)
for debt. Old cloud-only milestone reports were removed because their claims
that blur, network, display apply and shortcut editing were unavailable no longer
matched the code. Their original snapshots remain in Git history.
