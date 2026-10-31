# M5.2 Network, Bluetooth, brightness, and power

## Status

Accepted for the source tree. None of these services has been used on a session.

## Decision

- Network stays unavailable. Quickshell 0.2 does not document a NetworkManager type. The page does not scan and does not store a Wi-Fi secret.
- Brightness stays unavailable. There is no documented backlight or DDC call, and software dimming is not presented as hardware brightness.
- Bluetooth uses `Quickshell.Bluetooth`. The adapter can be turned on or off. A known device can be connected, disconnected, paired, cancelled, or forgotten. The shell does not start discovery.
- Battery reads `UPower.displayDevice` only when `ready` is true. An estimate is shown only when UPower reports a positive time. The bar module has no width otherwise.
- Session actions reuse the launcher's confirmed `loginctl` arguments. The first activation arms the button. The second runs it.

## Consequences

A session still has to confirm a real adapter, a battery, and a lock. This change does not claim the notification bus.
