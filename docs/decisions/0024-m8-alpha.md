# M8.2 Alpha report

## Status

Accepted as the release report for this tree. The product is an alpha. It is not stable.

## Decision

- `docs/release-notes.md` lists the merged milestones and the install commands.
- `docs/user-guide.md` describes the surfaces a first run can exercise.
- `docs/troubleshooting.md` is the recovery path for that run.
- `docs/capability-matrix.md` marks every hardware row **NOT RUN**. Temporary-home installer checks are not recorded as a hardware pass.
- Unsupported behavior stays labeled: blur, network, brightness, notification sounds, display apply, shortcut install, folder scanning, and jpeg or webp sampling.

## Consequences

The next step is a live session. A green `scripts/check.sh` does not close that step. Revert a milestone by its merge commit if a live run needs the previous tree.
