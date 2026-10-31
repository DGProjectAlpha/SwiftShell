# M6.2 Notification preferences

## Status

Accepted for the source tree. No notifying application has been used on a session.

## Decision

- A desktop id can be `show`, `quiet`, or `hide`. Hide drops the notification, including a critical one. Quiet keeps a normal notification in history and still banners a critical one.
- History on the page is grouped by application name.
- The page says notification sounds are not played. There is no sound switch.

## Consequences

The id has to be typed. This shell does not invent a list of applications that have never notified it. Ownership is still off until the M6.1 confirmation.
