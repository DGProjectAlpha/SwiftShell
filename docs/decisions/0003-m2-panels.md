# M2 panel boundaries

## Status

Accepted for the second milestone. Local rendering is still unproven. The M1 bar has still not been loaded on the target machine. M2 was added because that work was explicitly requested.

The blur lookup and the `itemRect` anchor described below were corrected in `docs/decisions/0004-m2-stability.md`. This record stays as the original M2 boundary. Follow 0004 for color units, blur, anchoring, and popup phases.

## Decision

- The bar stays fully transparent. The top-edge gradient is off until `appearance.topGradient` is set, and it is drawn inside the existing 28px window.
- One `PopupWindow` per bar window is the only popover. It does not reserve screen space and it does not register a shortcut.
- The visible panel is a scrim. The original blur path looked up `BackgroundEffect` dynamically. That lookup did not create an effect. Decision 0004 removes it. The scrim remains the compatible surface.
- Outside click dismissal uses `HyprlandFocusGrab`. Escape closes the popup when it has key focus. Both are released when the panel closes.
- The calendar's month controls, today control, and week-number control change real state. Day cells are not buttons.
- PipeWire default-sink volume and mute are the only live hardware writes. Other status rows are text.
- Wallpaper tint is a stored preference. The palette provider does not sample an image.
- Appearance changes are written through the existing atomic settings file. Version stays 1. Missing appearance keys mean the defaults.

## Consequences

Opening a panel can hold a Hyprland focus grab until the panel closes or this shell stops. Stopping SwiftShell is the recovery. Noctalia and the Hyprland configuration are not modified.

Blur, the grab, PipeWire writes, and the 1.5 scale placement need a session on the target machine before they can be called working.
