# Capability matrix

Status values are **PASS**, **FAIL**, or **NOT RUN**. A cloud check is not a hardware pass. This alpha is not stable.

Later source repairs were checked with `scripts/check.sh` through 11:05 PM America/New_York on 30 Oct 2026. Each of those runs exited 0. They had no Hyprland session and no `qs` binary. A source pass is not a session pass.

`.github/workflows/check.yml` runs `scripts/check.sh` on GitHub-hosted Ubuntu. This workspace did not observe that workflow. Do not treat the file as a green check.

| Test | Source | Session | Notes |
|---|---|---|---|
| Start/stop in an existing Hyprland session | NOT RUN | NOT RUN | An earlier bar launch was seen with Noctalia stopped. This alpha has not been relaunched |
| Single-monitor laptop (`eDP-*`) | NOT RUN | NOT RUN | Placement can be focused, the first screen, or every screen. No laptop output was present |
| Multi-monitor 1080p + 1440p | NOT RUN | NOT RUN | Source does not hardcode connector names in defaults |
| Fractional scale 1.5 and scale 2.0 | NOT RUN | NOT RUN | Sizes are logical pixels. Scale was not measured |
| Output hotplug / focused-output change | NOT RUN | NOT RUN | |
| Bar height minimum, default, and maximum | NOT RUN | NOT RUN | Source derives font, icon, gap, and the reserved zone from heights 22, 28, and 52 |
| Maximized versus true fullscreen | NOT RUN | NOT RUN | Reservation is a settings flag. Fullscreen policy was not observed |
| Spotlight search | NOT RUN | NOT RUN | Source ranks a catalog and shows 24 rows. Dolphin and Helium were missed on an earlier launch |
| Settings floating window | NOT RUN | NOT RUN | Source uses one `FloatingWindow`. Move, resize, and focus were not shown |
| Settings search and migration | PASS | NOT RUN | Temporary files kept the original backup bytes, unknown keys, and a malformed file |
| Wallpaper choose image | NOT RUN | NOT RUN | Source crops, falls back to the crimson image, and caps the long edge at 3840 |
| Wallpaper slideshow | PASS | NOT RUN | Timing/list changes preserve the current item; output generations gate preload and finish; failed current images are skipped. Crossfade and hotplug remain unobserved on a compositor |
| Adaptive color | PASS | NOT RUN | Cover/Contain crop sampling, per-output state, stale-response rejection, and PNG allocation limits are source-tested. Not shown on a display |
| Real Gaussian blur | NOT RUN | NOT RUN | Expected result on a session is a scrim, not blur |
| Displays drag and drop | NOT RUN | NOT RUN | Preview only. Apply stays disabled |
| Shortcut recording | NOT RUN | NOT RUN | Source stores chords and does not install them |
| Audio | NOT RUN | NOT RUN | Stream nodes are added to the tracker. No device volume was changed |
| Network and Bluetooth | NOT RUN | NOT RUN | Network stays unavailable. Bluetooth does not start a scan |
| Tray, MPRIS, brightness, and battery | NOT RUN | NOT RUN | Brightness stays unavailable. A tray menu uses the clicked position in source only |
| Notifications | PASS | NOT RUN | Dismiss and expire call a stand-in object. Ownership stays off until a second confirmation |
| Locked, fullscreen, or high GPU load | NOT RUN | NOT RUN | No CPU or GPU number is claimed |
| Clean install, reinstall, update, and uninstall | PASS | NOT RUN | Temporary home passed, including doctor and settings rollback. The draft package was not built |

## Labeled limits

| Capability | Status in this alpha |
|---|---|
| Backdrop blur | Unavailable. Scrim only. No Hyprland rule file is written |
| Rounded blur clipping | Not provided. Qt Quick clip is rectangular and is left off |
| NetworkManager | No Quickshell 0.2 type, and this workspace has no Qt D-Bus QML module. No connection is attempted |
| Hardware brightness | No documented backlight or DDC call. The picture is not dimmed |
| Notification sounds | Not played |
| Display apply | Disabled. No verified Lua layout transaction |
| Shortcut install | Not done. Super+Space is unchanged |
| Slideshow folder scan | Not done here. `QtQuick.Dialogs` and a folder-list module are not installed in this workspace |
| Jpeg and webp sampling | Not done. The files can still be displayed |
| Bluetooth discovery | Not started |
| Settings backup | Original file text. An old `document` wrapper is unwrapped on rollback |
| Bar screens | `focused` by default, or `primary`, or `all`. A named monitor wins |
| High contrast | Saved text setting. Manual hex and automatic png text still win |
| Package | Draft only. License is unchosen. `doctor.sh` and the real PNG are in the script |
| Product stability | Not claimed |
