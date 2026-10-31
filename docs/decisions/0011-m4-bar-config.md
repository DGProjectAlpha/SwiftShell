# M4.2 Bar height and modules

## Status

Accepted for the source tree. The resized bar and the exclusive zone have not been measured on a Hyprland session.

## Decision

- `bar.height` is 22 to 52 logical pixels. The default remains 28. Font, icon, horizontal margin, module gap, workspace gap, hit height, and the reserved zone are derived from that height and the existing icon scale. At 28 and icon scale 1 the derived numbers match the previous fixed tokens.
- The modules the bar already draws are `workspaces`, `title`, `search`, `clock`, and `control`. Order is persisted. Hide removes a module and keeps its place. Earlier and Later swap neighbors. There is no module for tray, network, or battery.
- The Top bar settings page writes those values. Search for a bar label switches to that page. An empty monitor name stays automatic.
- Workspace dispatch is unchanged.

## Consequences

A version 2 settings file migrates to version 3 after the backup file is written. New keys use these defaults. Cloud checks do not show the bar at 22 or 52, and they do not prove the reserved strip.
