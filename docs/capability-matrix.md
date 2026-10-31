# Capability matrix

Status values are **PASS**, **FAIL**, or **NOT RUN**. A cloud check is not a hardware pass. This alpha is not stable.

The cloud run is `scripts/check.sh` on 30 Oct 2026, at 10:26 PM America/New_York, in a workspace with no Hyprland session and no `qs` binary. That command exited 0: 52 QML files, logic tests, 16 installer cases, and `qmltestrunner` 6.4.2 totals of 6 and 8. `launcher rank 400 apps: 1.12 ms`. `launcher rank 1000 apps: 1.55 ms`. Those results support the rows marked as source or temporary-home checks. They do not move a window, draw a monitor, or edit a live config.

| Test | Status | Notes |
|---|---|---|
| Start/stop in an existing Hyprland session | NOT RUN | An earlier bar launch was seen with Noctalia stopped. This alpha has not been relaunched |
| Single-monitor laptop (`eDP-*`) | NOT RUN | Source follows the focused monitor, then the first screen |
| Multi-monitor 1080p + 1440p | NOT RUN | Source does not hardcode connector names in defaults |
| Fractional scale 1.5 and scale 2.0 | NOT RUN | Sizes are logical pixels. Scale was not measured |
| Output hotplug / focused-output change | NOT RUN | |
| Bar height minimum, default, and maximum | NOT RUN | Source derives font, icon, gap, and the reserved zone from heights 22, 28, and 52 |
| Maximized versus true fullscreen | NOT RUN | Reservation is a settings flag. Fullscreen policy was not observed |
| Spotlight search | NOT RUN | Source ranks a catalog and shows 24 rows. Dolphin and Helium were missed on an earlier launch and the refresh has not been relaunched |
| Settings floating window | NOT RUN | Source uses one `FloatingWindow`. Move, resize, and focus were not shown |
| Settings search and migration | NOT RUN | Source search, undo, and repair passed in logic tests. A live file was not migrated |
| Wallpaper choose image | NOT RUN | Source crops, falls back to the crimson image, and caps decode at 3840 |
| Wallpaper slideshow | NOT RUN | Source walks stored paths. It does not scan a folder. Jpeg and webp are not sampled |
| Adaptive color | NOT RUN | Source samples png top edges and keeps manual colors. Not shown on a display |
| Real Gaussian blur | NOT RUN | Expected result on a session is a scrim, not blur. No checkerboard was captured |
| Displays drag and drop | NOT RUN | Source preview does not send layout changes. Apply stays disabled |
| Shortcut recording | NOT RUN | Source stores chords and does not install them |
| Audio | NOT RUN | Source writes PipeWire when the node is ready. No device was changed |
| Network and Bluetooth | NOT RUN | Network stays unavailable. Bluetooth does not start a scan |
| Tray, MPRIS, brightness, and battery | NOT RUN | Brightness stays unavailable. Tray, MPRIS, and battery were not used on hardware |
| Notifications | NOT RUN | Source keeps ownership off until a second confirmation. No handoff was tested against another owner |
| Locked, fullscreen, or high GPU load | NOT RUN | No CPU or GPU number is claimed |
| Clean install, reinstall, update, and uninstall | NOT RUN | A temporary home with stub commands passed, including doctor and settings rollback. A live account was not used |

## Labeled limits

| Capability | Status in this alpha |
|---|---|
| Backdrop blur | Unavailable. Scrim only |
| Rounded blur clipping | Not provided. Qt Quick clip is rectangular and is left off |
| NetworkManager | No documented Quickshell 0.2 type. No connection is attempted |
| Hardware brightness | No documented backlight or DDC call. The picture is not dimmed |
| Notification sounds | Not played |
| Display apply | Disabled |
| Shortcut install | Not done. Super+Space is unchanged |
| Slideshow folder scan | Not done. Paths are stored |
| Jpeg and webp sampling | Not done. The files can still be displayed |
| Bluetooth discovery | Not started |
| High contrast | Saved text setting. Manual hex and automatic png text still win |
| Product stability | Not claimed |
