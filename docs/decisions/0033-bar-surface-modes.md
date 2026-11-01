# Opt-in bar surface modes

Date: 2026-11-01. Roadmap B1, independently usable bar-background slice.

## User-visible changes

Top bar settings offers Transparent, Solid and Frosted backgrounds, a color
picker and surface opacity. All-screen settings can be overridden per discovered
monitor, with an explicit return to inheritance. Transparent remains the default
for new and existing configurations. Appearance's corner radius also rounds
painted bar surfaces; bar height and work-area reservation remain unchanged.
Foreground follows a dominant surface tint unless a manual foreground is set.
Very low alpha still depends on the underlying wallpaper for contrast.

## Architecture

Additive v3 fields: bar.surfaceMode, surfaceColor, surfaceOpacity and
surfaceOutputsJson. Settings validation rejects malformed overrides; it keeps
unrelated preferences and numeric/named workspace lists. A batched surface update
defers atomic writes until JsonAdapter's serialization notifications finish.

SurfaceService uses one fixed read-only startup/config-reload capability probe.
BackdropEffect assigns the real bar window a rounded BackgroundEffect Region.
Native testing proved this works directly for layer surfaces: no layer rule,
compositor configuration write, global blur-strength change or screenshot-based
production effect is needed. Transparent/Solid remove the request. If protocol,
tool or compositor blur is unavailable, Frosted uses a readable near-opaque fill.
Blur strength and saturation sliders are omitted because no independent verified
backend exists. Settings shadows retain their existing window scope. Shared
popover treatment and bar context menus are the next separate B increments.

## Files changed

BarWindow/BarHost paint and report each output independently. BarPage exposes the
controls. SettingsStore/settings.js own validation and persistence. SurfaceService,
BackdropEffect and the read-only capability function in windowctl own native blur.
Tests cover migration, inheritance, unavailable capabilities, actual QML controls,
native save/restart and controlled-pattern measurements.

## Test results

`scripts/check.sh` passed: 64 QML files, JS suites including the new bar surface
suite, 8 display + 7 window helper Python tests, 17 installer checks, and QML
suites 6/13/6/4/4 with zero failures/skips. Native checkerboard mode/blur proof
passed on DP-1 scale 1 and HDMI-A-1 scale 1.25. Native hidden SettingsWindow
save/restart retained global and per-output surfaces plus named workspaces. All
11 native Settings pages loaded; real Super+Space/repeat/Escape still passed on
both outputs. The chord test waits for queued native Settings activation to
finish before choosing an output, so an earlier show request cannot undo the
test's explicit monitor focus.

## Not verified / manual acceptance

Actual physical hotplug, other GPU drivers, a human keyboard accessibility audit
and every wallpaper/low-opacity combination remain unperformed. In Settings →
Top bar → Background, select each style, pick a color, change opacity, choose a
monitor and disable inheritance. Confirm the other bar is unchanged. Re-enable
inheritance and use Reset background to return the global style to transparent.

## Recovery

Before implementation, preferences were copied and byte-verified in
`~/.config/swiftshell/settings.json.bak-swiftshell-bar-20261101T132953Z`.
Reset background restores the transparent default without resetting unrelated
preferences. Clear individual overrides with Use all-screen background. Stop only
SwiftShell with scripts/stop.sh to remove all its layer surfaces/effects. No
Noctalia, autostart, services, monitor mode or user Lua changed in this increment.
The separately approved Super+Space handoff remains as documented in
launcher-shortcut.md. Next: B2 bar ergonomics and shared frosted popovers.
