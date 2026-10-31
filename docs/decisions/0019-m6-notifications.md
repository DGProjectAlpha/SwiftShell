# M6.1 Notification ownership

## Status

Accepted for the source tree. The server has not been created on a session, and no bus name was claimed in the cloud run.

## Decision

- `notifications.ownership` defaults to `off`. The notification host is loaded only when it is `on`.
- Settings asks a second time before that value becomes `on`. Release sets it back to `off` and clears live banners.
- While ownership is off, incoming notifications are not stored. A preview card on the page is labeled Preview and is not sent through the server.
- Do not disturb keeps non-critical notifications in history and still shows critical ones.
- A replaced id updates the existing row. History is capped at 40. Bodies are not logged.
- If the host fails to load, the shell warns once and leaves the current owner alone.

## Consequences

A session still has to confirm the handoff in both directions. Per-app policies are not in this change. Action buttons are not invoked. The server advertises no markup, images, or inline replies.
