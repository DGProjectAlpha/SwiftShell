# Spotlight grid and private local search

Date: 2026-11-01. Implements the owner's Spotlight 2.0 request as an independent
increment alongside the coordinated clock and Settings work.

Spotlight is a centered, bounded floating layer containing a 680×560 logical
pixel maximum card, large search field, scrolling application icon grid and
Settings / Lock / Suspend / Restart / Shut down icon strip. It uses the shared
floater material, text, radius, real rounded BackdropEffect and optional shared
RectangularShadow. Older Qt cleanly omits the unsupported shadow component.
Exclusive keyboard focus exists only while open; Escape/outside click/repeat
Super+Space release it. App icons use the desktop catalog and native theme lookup,
with a monogram only when no real icon is available.

All apps includes the entire catalog, rather than truncating the visible grid to
12 apps. Favorites uses the existing validated, persistent pinned desktop IDs;
right-clicking a tile adds/removes its favorite. Missing/uninstalled favorites are
omitted without deleting the stored preference. Recent lists only desktop IDs
launched from SwiftShell. Settings → Spotlight Search now selects a persistent opening view: All apps,
Favorites, or Recent apps. Each new invocation starts with that saved view; manual
tab changes within the open panel leave the preference unchanged. Existing
settings acquire All apps without losing favorites. The page uses the shared
ChoiceBox and includes a real Open Spotlight action; no decorative options were
added. Favorite membership and the opening view persist across restarts. Ctrl+1/2/3 chooses All/Favorites/
Recent; Ctrl+D adds/removes the selected app favorite, Menu/Shift+F10 opens its
keyboard-operable context menu. Tab/Shift+Tab and Alt+H/J/K/L browse while typing stays in the search field.

Search providers are pure local functions. A bounded recursive-descent calculator
supports numbers, parentheses, arithmetic, powers, pi and e, without eval or source
execution. Units cover common length/mass/volume and temperature conversions,
including 42f → 5.6 °C. Matched Settings categories can be opened directly. If no
local app/provider matches, Enter explicitly opens a clearly labeled Google search
through Qt.openUrlExternally and the user's XDG browser. HTTP(S) addresses can be
opened directly; unsafe schemes, credentials, malformed hosts/ports/control text
are rejected. No request leaves the machine while typing, and queries are not
persisted or logged. Calculator Enter explicitly copies the result using the
supported Quickshell clipboardText property.

The live audit found existing loginctl suspend/reboot/poweroff commands invalid on
the target. Shared power argv now uses systemctl --no-ask-password for those
verbs and loginctl lock-session for the configured session lock listener. Actions
still require a second confirmation. Spotlight tracks the real subprocess exit
and displays refusal/unavailability instead of assuming a detached command worked.
The real destructive actions were not triggered during tests. Lock requires a
working session lock listener; SwiftShell does not invent or install one.

Validation: Node spotlight-providers.test.js and existing logic suite passed.
The new always-run tst_spotlight.qml passed 9 cases including setup/cleanup: full
35-app scrolling, actual context-popup and keyboard favorite edits, calculator/web rows and
first-confirmation safety. Tests fail on binding loops/type errors. Native
spotlight.py passed on DP-1 scale 1 and HDMI-A-1 scale 1.25: actual keyboard 2+2,
real right-click favorite changes with restoration, All/Favorites selection,
Settings icon activation, Escape, geometry and blur attachment. The existing
actual Super+Space open/repeat/Escape regression passed on both outputs.

A separate controlled checkerboard shielded the entire card for bounded captures.
Actual on/off blur edge contrast was HDMI 0.347/4.755 and DP 0.415/7.026; lower is
blurred. The off-blur empty material edge had exactly two alternating colors from
the owned pattern. The DP capture was visually inspected: readable six-column
icons, compact actions, consistent glass, rounded corners and no opaque fake blur.
Captures are /tmp/swiftshell-spotlight-{output}-{on,off}.png. The test restored
panelBlur and explicitly returned the previously unowned compositor state to
rounding 10 / blur size 5 / passes 4, with no managed overrides remaining.

No browser/network search, app launch, lock, suspend, reboot or poweroff was invoked
by this regression. Browser and clipboard APIs were checked against official Qt/
Quickshell documentation; desktop launch retains the existing parsed entry.execute
path. File indexing, online suggestions and categories remain future additions. This is not a claim to implement all later roadmap items.
No Lua, Noctalia, autostart or service file is changed by Spotlight. Rollback is a
source revert; existing favorite and recent preference formats remain compatible.

Favorites now support direct drag/drop and Alt Shift H/L ordering. Saved ordering
retains temporarily missing desktop entries. Crossing the drag threshold cannot
launch an app; a real pointer drag and disk-save audit passed on both monitors.
