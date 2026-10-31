# M4.1 Settings navigation

## Status

Accepted for the source tree. The window has not been shown on a Hyprland session.

## Context

M4.0 opened one Appearance page with the controls that were already wired to buttons. The theme already applies text size, weight, padding, spacing, shadow, icon scale, and motion scale. Those values had no window controls. A sidebar of unfinished categories would have looked like settings that do nothing.

## Decision

- The window keeps a single Appearance category. Search matches that page's labels, sections, and keywords. A query with no match says so. Alt+J and Alt+K move the match while the search field is focused. Enter focuses that control. Bare letters stay in the field.
- Escape clears a non-empty search field. Escape on an empty field, and Escape while another control is focused, closes the window.
- Below 720 logical pixels the action column stacks above the page. At 720 and above it stays on the left.
- Density writes `panelPadding` and `panelSpacing` together. The other sliders write the one setting they name. Motion scale is stored while reduced motion is on, and the row says the motion is paused.
- Wallpaper tint is text, not a switch. The palette is still not sampled. Backdrop blur stays the capability sentence from M4.0.
- Undo and Reset use `reduceAppearanceHistory`. Undo is session state for the open window. Reset writes the appearance defaults and leaves that previous state on the undo stack. The settings file updates through `SettingsStore.setAppearance`.

## Consequences

Headless tests cover search, density rounding, history, and which rows a query shows. They do not show the window, the scroll position, or a saved file after restart. The next source milestone is M4.2, the bar height and module controls, as a separate change.
