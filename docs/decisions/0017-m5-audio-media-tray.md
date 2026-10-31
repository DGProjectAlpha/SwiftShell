# M5.1 Audio, media, and tray

## Status

Accepted for the source tree. PipeWire, MPRIS, and the tray have not been exercised on a session.

## Decision

- The default sink, the default source, and up to six application audio streams use the Quickshell 0.2 PipeWire objects. A device change writes `preferredDefaultAudioSink` or `preferredDefaultAudioSource` only when PipeWire is ready and the node is in that role's list.
- Playback calls `togglePlaying`, `next`, or `previous` only when the player's matching `can*` flag is true.
- Tray rows are status-notifier items that can be activated, or menu-only items that have a menu. Anything else is omitted. The bar module has no width until one of those rows exists.
- Each service is loaded on its own. A missing module leaves that section labeled Unavailable.

## Consequences

A session still has to confirm the sink, a player, and a tray icon. This change does not scan Wi-Fi, claim notifications, or edit Hyprland.
