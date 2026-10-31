# Foreground tokens

## Status

Accepted for the source tree. The bar modules were instantiated offscreen with stub services. They were not shown on a Hyprland session.

## Decision

- `Theme.text` is not a token. Bar battery, media, and tray text use `textPrimary`.
- `panelText` and `panelMuted` follow the surface colors, so a manual hex and automatic png text reach panels as well as the bar.
- Hover uses the palette hover color. The static check rejects a `Theme` name that `Theme.qml` does not declare.

## Consequences

A missing token fails `scripts/check.sh` before a session. The transparent bar color is unchanged.
