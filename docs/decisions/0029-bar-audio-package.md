# Bar screens, tracked streams, and package files

## Status

Accepted for the source tree. Placement was tested as data. PipeWire binding and tray menus were not shown on a session. The package was not built.

## Decision

- `bar.placement` is `focused`, `primary`, or `all`. The default stays `focused`. A named monitor still wins.
- The audio tracker includes application streams that are on screen, not only the default sink and source.
- A tray menu is opened at the clicked item's position in the window.
- The draft package installs `doctor.sh` and the wallpaper PNG as a regular file. The license stays unchosen.

## Consequences

`primary` and `all` do not follow focus. `focused` still does. Volume changes on an untracked stream are still unverified on hardware. The package is not a release.
