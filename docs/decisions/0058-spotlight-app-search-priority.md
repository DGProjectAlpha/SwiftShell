# Spotlight app search priority

Date: 2026-11-13.

The app ranker already recognized Discord from `dis`, but LauncherCard built
Settings and window provider rows above its app grid. Those rows also occupied
selection index zero, so description/keyword matches such as Weather's “disable”
could take priority over an actual app-name prefix. Typing the complete app name
only appeared to fix the ranker because the broad Settings matches disappeared.

For ordinary searches with matching apps, suppress generic Settings, window and
session-action suggestions. The first ranked app becomes the visible/keyboard
choice. No-app searches retain these fallbacks and the existing explicit web
fallback. Calculator/conversion, clipboard and capture intent remain prioritized;
explicit `window`/`windows` queries still access open-window results.

App names and desktop IDs retain fuzzy matching, exact/prefix/word/substring scores
and deterministic name tie-breaking. Generic names, descriptions, keywords and
categories retain literal matches but no longer admit arbitrary subsequences.
No history model, online lookup, preference schema or launch behavior changes.

Validation:

- `scripts/check.sh`: exit 0; 31 QML suites, 263 passed, 0 failed, 0 skipped;
  static, JavaScript, Python and installer suites pass.
- Node regression covers dis/DIS/disc/discord/dsc, irrelevant description rejection
  and literal keyword retention.
- Actual LauncherCard QML regression types `dis`, checks selected Discord ahead
  of Settings, verifies settings-only fallback and calculator priority over a
  matching app. Existing navigation/favorites/provider cases remain passing.
- Temporary windowless native LauncherCard with the real desktop catalog selects
  Discord for dis/DIS/disc/discord on the current host. No app launched, focus
  changed or screen pixels captured. Fullscreen safety preflight was clear, but
  no interactive compositor/UI pass was needed or claimed.

Rollback is a source revert of this commit. Existing saved settings, favorites,
recents, shortcuts and other-shell integrations remain compatible.
