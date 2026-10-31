# Per-output wallpaper

## Status

Accepted for the source tree. The state machine was tested in Node. No wallpaper was shown on a Hyprland session.

## Decision

- An output with its own image path stays on that file while the slideshow runs for the other outputs.
- A second load or finish event does not advance the slide again.
- A slide that fails to decode returns to waiting and keeps the current image.
- Sampling uses the slideshow path when one is showing, and a late response from an older request is ignored.
- The decode request sets one edge. A portrait result switches to the height cap of 3840.

## Consequences

This workspace has no `QtQuick.Dialogs` and no folder-list module, so a folder is still entered as paths. Jpeg and webp are still displayed and not sampled.
