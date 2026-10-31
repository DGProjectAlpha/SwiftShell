# M7.1 Surface polish

## Status

Accepted for the source tree. No panel has been shown on a session for this pass.

## Decision

- A button or switch that is narrower than its label elides the label. The control's own width still follows the label when nothing else sets it.
- Keyboard focus keeps a 1px border. Resting controls stay without a border. The display diagram keeps its 1px edge.
- Motion stays on `Easing.OutCubic`. Bounce, elastic, back, and spring animations are rejected by the static check.
- The popover card has a radius and does not set rectangular clipping. That is not a rounded blur mask. Backdrop blur is still unavailable.

## Consequences

A long label can be cut off with an ellipsis. The missing words remain in the accessible name. A checkerboard behind a panel will still show a translucent scrim, not blurred corners.
