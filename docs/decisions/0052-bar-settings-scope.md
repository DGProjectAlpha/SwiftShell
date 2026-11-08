# One scope for Top bar settings

Date: 2026-11-08

The previous page repeated monitor selectors in Background, Position and Widgets,
while Bar height and behavior controls still wrote global preferences. Choosing
a monitor therefore did not constrain the height slider. The page also exposed
both height and scale for the same rendered size, and title visibility twice.

One Apply to selector now covers Size & position, Background, Widgets, Clock &
labels and Fullscreen apps. Selection initializes once to the focused display;
focus changes and disconnects do not silently redirect edits. Where bars appear
is an explicitly global setting with one placement selector. There is one Bar
size slider, and background overrides are created directly by editing them.
Use shared settings removes only the selected output’s bar overrides.

The existing layoutOutputsJson map now accepts sparse size, behavior and clock
fields. Resolution combines legacy global values, shared fields and output
fields in that order. Existing edge/scale/order/group records still load with
their original appearance. Sizing uses an output height relative to the existing
base Theme metrics, so typography, hit targets, the painted surface, wallpaper
sampling and exclusive-zone dimensions change together on that output. Legacy
scale is preserved until the size control is edited; that edit writes one
absolute size and resets the corresponding extra scale to one.

All displays updates the edited fields on existing custom outputs as well as
the shared fallback for future outputs. Unrelated fields survive. Background
edits, individual widget visibility and widget grouping preserve other custom
properties rather than replacing an entire output’s preferences. Clock widgets,
fullscreen reveal and title layout read the same resolved output settings as
the page. The global clock remains the fallback for other clock surfaces.

Every Settings page also has Collapse all / Expand all below Search. They batch
the current page’s section states in one validated update. Collapsing during a
search first clears the search so search’s automatic expansion cannot negate
the requested action. Other pages’ section preferences remain unchanged.

Regression evidence is recorded in docs/testing.md. Native audit windows remain
hidden and use temporary XDG preferences. No user settings, compositor Lua,
display modes, shortcuts, Noctalia or service ownership are changed by the audit.
Visual pointer interaction on the reorganized live page remains a manual check.

Recovery: use shared settings for a selected display to discard its bar-specific
overrides. The source change is one reviewable commit on codex/bar-settings-scope;
return to its parent to restore the old UI. Keep a settings backup before running
an older version, whose validator does not understand the new nested fields.
