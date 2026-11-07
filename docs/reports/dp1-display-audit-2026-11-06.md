# DP-1 display audit — 2026-11-06

Read-only audit on the owner's running CachyOS desktop. Hyprland 0.57.1
(acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9), NVIDIA RTX 4070 driver 615.78.08.
The game remained on the named gaming workspace with internal/client fullscreen
both 2. No compositor/display configuration was applied and no fixture was mapped.

| Feature | Capability / configuration | Observed state |
| --- | --- | --- |
| Native mode | HP X32 EDID preferred high-refresh timing 2560×1440 at 164.833904 Hz | 2560×1440 at 164.834 Hz; matches the panel's nominal 165 Hz mode |
| Scale / orientation | Saved scale 1, position 0×0 | Scale 1, transform 0, not mirrored, DPMS on |
| Color depth | EDID advertises 10 bits per channel; active Lua specifies bitdepth=10 | XBGR2101010 output format (10-bit RGB; not proof of the panel's physical subpixel design) |
| Adaptive sync | EDID AMD block advertises 60–165 Hz; DRM vrr_capable=1; global misc:vrr=3 | Hyprland vrr=true; DRM dump includes active VRR; no physical timing measurement performed |
| HDR support | EDID PQ/ST2084 and static HDR metadata, advertised peak 400 cd/m²; backend hdr=true | Available; current preset srgb and no active HDR metadata blob |
| Automatic HDR | render:cm_auto_hdr=1 | Enabled; actual HDR switching/content not exercised during gameplay |
| Direct scanout | render:direct_scanout=2 (automatic for game content) | Not engaged; directScanoutBlockedBy=[SW] across repeated samples |
| Cursor | cursor:no_hardware_cursors=2, use_cpu_buffer=2 (automatic policies) | hardwareCursorsInUse=false; software cursor blocker remains; no manual override applied |
| VRR cursor scheduling | cursor:no_break_fs_vrr=2 | Automatic policy; no cursor-motion stress test performed |
| Tearing | general:allow_tearing=false | Not active; retained tear-free policy |
| DP link | DRM link-status=Good | No bad-link indication at audit time |

The actual main Lua includes `config.monitors`. That active file matches the live
DP-1 resolution/refresh/scale/bit depth. A separate older nwg-displays-generated
`monitors.lua` exists at the root of the Hyprland config directory with different
values, but the main Lua does not import that file. It was not edited or removed.
SwiftShell has no persisted display override in its current settings document.

Automatic HDR being enabled does not mean an SDR game is displaying HDR. Forcing
HDR or cursor/direct-scanout overrides during gameplay would not establish correct
HDR rendering and could reintroduce flicker. Further investigation of the software
cursor blocker should happen outside an active game, with a reversible plan.
Panel OSD settings such as overdrive and physical HDR/VRR behavior cannot be fully
verified from these compositor/EDID queries alone.

Sources: actual `hyprctl` monitor/options/client queries, current Lua includes,
`edid-decode` of the DP-1 EDID, read-only `modetest -c -p`, NVIDIA query. Public API
semantics: [Hyprland config options](https://wiki.hypr.land/configuring/core/config-options/)
and [monitor VRR modes](https://wiki.hypr.land/configuring/core/monitors/modes/).
No monitor serial numbers or user content are included in this report.

## Test disruption

The preceding test created its own fullscreen client on HDMI and moved/restored
focus. Targeting a second monitor and using no-initial-focus rules did not prevent
the owner-reported game disruption. There is insufficient saved event history to
attribute the exact game/fullscreen transition to a particular request, and the
audit did not reproduce it against the live game. The tests' fullscreen requests
were intended for their owned fixture, not RuneScape. This is not a claim that
those tests were harmless: the owner observed repeated fullscreen loss.

The dangerous `--allow-active-game` bypass has been removed. A shared preflight
now refuses the fullscreen/scanout fixtures, screenshot review and bar input tests
before any mutation if any mapped app reports fullscreen in either the compositor
or client state, on any monitor. It also protects games left with client=2 and
internal=0 after demotion. AGENTS.md prohibits interactive foreground testing or
focus/pointer manipulation while the owner is gaming; read-only audits and
noninteractive checks remain available.
