# Bar ergonomics and consistent frosted floaters

Date: 2026-11-01. Roadmap B2, following the bar/picker maintenance fix.

The bar now groups modules on left, center and right without overlapping the
centered group. Existing module order supplies default group membership. Settings
provides compact placement controls, an optional Search label, 12/24-hour time,
seconds, and short/weekday/ISO dates. Minute-only clocks do not request second
updates. Per-monitor visibility overrides inherit global settings until customized;
right-clicking either bar opens its own real module checkboxes and Settings link.
Connectors are accompanied by observed friendly monitor names.

Settings additions are validated additive schema-v3 fields: clock.showSeconds,
showDate, dateFormat; bar.searchLabel, moduleSidesJson and hiddenOutputsJson.
Existing workspace, bar surface and extension data remain preserved. Keyed
repeaters retain live controls. Reset positions and per-monitor inheritance are
explicit. Invalid module ids, groups and JSON shapes are rejected.

Calendar, control center and module menus use independent overlay PanelWindows
with rounded ext-background-effect blur, shared theme typography/contrast and
RectangularShadow. Content is laid out before mapping to avoid empty-size flashes.
Tall content has a bounded scrolling viewport. Exclusive keyboard focus exists
only while open; Escape, outside click, Settings and Spotlight dismiss panels.
Native geometry is checked against actual compositor layers on mixed scales.
No Hyprland rules or user configuration were changed to enable this material.

A final readback test exposed a real FileView edge case: writing identical adapter
content may emit no saved event. Queued redundant writes left persistence stuck at
saving. SettingsStore now tracks semantic persisted/in-flight snapshots, skips
identical writes and coalesces actual changes. Failure clears pending work with a
truthful error. Migration uses the same deferred cache-safe writer after backup.
The same regression caught reentrant FileView load callbacks interrupting a first
backup write; backup consideration is deferred and guarded against duplicate writes.
The native isolated regression exercises backed-up v2 migration, duplicate saves
and rapid edits, checks
ready state and reads the final JSON from disk; restart persistence also passes.

Validation: scripts/check.sh; scripts/test-settings-save-native.sh;
scripts/test-workspaces-native.sh; native bar-ergonomics.py, color-picker.py,
settings-pages.py and launcher-shortcut.py. Both connected outputs passed real
right-click/checkbox/Escape, Customize, launcher handoff, clock ticking and layout.
Owned checkerboard blur comparisons (on/off edge contrast, lower is blurred):
HDMI calendar 2.637/4.601, control 4.375/5.958, modules 1.524/3.728;
DP calendar 4.568/6.878, control 5.344/7.523, modules 2.428/5.097.
Only owned test fixture pixels were captured. The compact calendar capture was
visually inspected. Quickshell 0.3.2, Qt 6.12.0, Hyprland 0.57; scale 1/1.25.

Verified preferences backup: own state directory
backups/20261101T143917Z-bar-ergonomics/settings.json (restricted permissions).
Test overrides are restored. No display modes, Lua files, Noctalia, autostart,
services or packages were changed. Revert this commit to roll back source; retain
backups for selective preference recovery. Physical hotplug, gaming GPU load,
every wallpaper and other compositor versions remain unverified. C1/C2 Spotlight
work is a separate milestone; this does not claim the full roadmap is complete.
