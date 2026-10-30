# M2 stability corrections

## Status

Accepted as a correction to M2. Local rendering is still unproven. These decisions replace the blur lookup and the `itemRect` anchor in `docs/decisions/0003-m2-panels.md`. They do not add M3.

## Context

The merged M2 panels passed JavaScript and Python checks and had not been loaded by Quickshell. Three of those checks still allowed defects: `Qt.rgba` was given a byte channel, blur was a dynamic property read, and popup placement used `itemRect`.

## Decision

- Palette channels are 0–255 bytes. `Qt.rgba` receives 0.0–1.0. Alpha is already a unit and is not divided by 255. The light bar gradient is white at 0.55 alpha, not a channel of 255.
- `appearance.panelBlur` remains in the settings file. It does not enable an effect. Quickshell 0.2.0 has no `BackgroundEffect` type. The 0.3 API is a declared attached object and requires `ext-background-effect-v1`. This tree does not name that type, does not look it up, and does not edit Hyprland blur. The scrim is the panel surface.
- Popup position comes from `contentItem.mapFromItem` with the item's width and height, inside `PopupAnchor.anchoring`. The result is clamped in logical pixels. `itemRect` is not used because its documented equivalent has zero size. `devicePixelRatio` is not a multiplier.
- One popup phase per bar window owns visibility, the focus grab, and the click mask. Closing releases the grab immediately. A fade that has not become visible finishes immediately. A finish signal is ignored unless the phase and the opacity still match. Monitor loss and destruction clear the grab.
- PipeWire writes carry the sink id captured for that gesture. A missing id, a missing node, or a different id produces no write. Unimplemented status rows stay text.

## Consequences

The cloud tests cover the decisions above as pure functions, plus a Qt 6.4 `qmllint` pass that cannot see Quickshell. A CachyOS session still has to show the bar, the scrim, focus release, fractional scale, and a real default sink before those behaviors can be called working.
