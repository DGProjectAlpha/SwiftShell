# Notification lifetime

## Status

Accepted for the source tree. Native dismiss and expire were exercised as function calls. The host was not created on a Hyprland session, and no other notification owner was present.

## Decision

- Dismiss calls the notification's `dismiss()`. A timeout calls `expire()`. `expireTimeout` of 0 does not expire. A negative or missing timeout uses five seconds, and the wait is at least one second.
- The banner timer does not repeat.
- A `closed` signal removes the banner without calling dismiss a second time.
- Action buttons call `invoke()` on the matching action. Images, markup, and inline reply stay off. The server does not advertise persistence.
- `notificationOwnership` stays the saved choice. `NotificationsModel.serverState` is `running`, `failed`, or `off`. A failed server leaves the saved choice on and the page says the server is not running.

## Consequences

History is still memory only and is capped at 40. Sounds are still not played. Ownership still defaults to off.
