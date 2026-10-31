# M4.7 Preferred chords

## Status

Accepted for the source tree. The page has not been shown on a Hyprland session, and no compositor bind has been read or written.

## Decision

- Spotlight, Settings, and the control center can each store one preferred chord in `shortcutsJson`.
- Record, Enter, Escape, and Clear change that stored chord. A duplicate among those three actions is refused.
- The save does not install the chord. Super+Space remains the documented handoff. The active compositor binds are not inventoried, because this floor has no verified read of them.

## Consequences

A session still has to confirm the page records and cancels. Nothing in this change can add or remove a bind.
