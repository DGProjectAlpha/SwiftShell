# M4.3 Backdrop blur

## Status

Blur is unavailable on the Quickshell 0.2 floor. That is a source decision, not a hardware pass.

## Investigation

Quickshell 0.2.0 does not document `BackgroundEffect` or `ext-background-effect-v1`. Those appear in the 0.3 docs. Naming the type in a file this tree parses would stop that file from loading, because the project does not use a version preprocessor. `FloatingWindow` is a normal toplevel, so a layer-shell blur rule would not describe it even if one were added. This repository does not write Hyprland blur rules.

## Decision

`shell/logic/material.js` reports backdrop blur unavailable, fallback `scrim`, and hardware verification false. The bar, popovers, Spotlight, and Settings keep the theme scrim. There is no blur slider and no renamed opacity control.

## Consequences

A checkerboard screenshot behind a rounded surface is still required before anyone marks real blur complete. That screenshot has not been taken.
