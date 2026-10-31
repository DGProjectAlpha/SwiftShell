# Settings backup bytes

## Status

Accepted for the source tree. The backup path was exercised with temporary files. It has not been run inside Quickshell on a Hyprland session.

## Decision

- A migration backup is the original settings text, written with `FileView.setText`.
- `JsonAdapter` is not used for that file. An older backup shaped as `{ "document": "<json>" }` is unwrapped by rollback when the inner text is a settings object.
- A backup that already restores is not replaced.
- The original file is rewritten only after that backup step succeeds.
- A file that is not JSON is left unchanged.

## Consequences

Unknown keys move into `extensionsJson` on the migrated file. The backup still has them in their original places. Rollback restores that backup, not the migrated layout.
