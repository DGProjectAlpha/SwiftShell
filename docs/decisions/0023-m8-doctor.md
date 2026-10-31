# M8.1 Doctor and settings rollback

## Status

Accepted for the source tree. The commands were run in a temporary home directory. They have not been run on a Hyprland session.

## Decision

- `swiftshell doctor` reports Quickshell and Hyprland versions through the existing dependency check, says blur is unavailable, and says output layout was not measured.
- It reports whether `settings.json` and `settings.json.bak-swiftshell` exist. Notification ownership is `off`, `on`, `absent`, or `unreadable`. The file body is not printed.
- `swiftshell rollback-settings` copies that backup over `settings.json` only. A missing backup or a symlink stops the command.
- Neither command reads or writes Hyprland or Noctalia files.

## Consequences

Doctor does not repair a broken install by itself. Rollback cannot recover a settings file that was never backed up, and the backup is the adapter snapshot from migration, not a byte copy of every hand-added key.
