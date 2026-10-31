# M4.6 Display preview

## Status

Accepted for the source tree. The diagram has not been shown on a Hyprland session, and no layout has been applied.

## Decision

- The page projects connected outputs into a preview, keeps their aspect, and accepts drag and Alt+H/J/K/L moves. Snap, overlap, negative coordinates, portrait size, and mixed scale are covered by the logic tests.
- Apply stays disabled. There is no countdown and no write. A crash-safe Keep/Revert transaction needs a verified compositor call this floor does not have.
- Current size is shown. Resolution lists, rotation, and HDR are not offered, because no verified mode list is connected.

## Consequences

A real dual-monitor session still has to confirm the rectangles match the outputs. Nothing in this change can move a display.
