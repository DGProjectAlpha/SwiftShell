# 0048 — Edit existing Lua desktop shortcuts, preserving actions

The Shortcuts page lists the effective compositor bindings and edits uniquely
matched, supported `hl.bind` source calls. It no longer presents another parallel
catalog of replacement bindings. The legacy managed helper remains for backward
compatibility with existing installations.

A non-executing lexer follows the loaded `require` graph under the configuration
root. Only constant key expressions and supported literal options are editable;
generated loops, shared keys, unsupported expressions and submaps remain visible
with an explanation. The original action is never reconstructed from displayed
text. This integration is verified specifically on Hyprland 0.57 Lua, whose
`j/binds.arg` identifies the callback in Lua's registry. Other versions fail closed.

Each edit locks its own journal, records original source bytes and hashes, validates
with `luac -p`, preserves source permissions, pauses automatic config reload, and
replaces only the existing live binding using its original callback and options.
It verifies binding count and every unrelated entry before atomic source replacement.
The prior automatic-reload policy is restored. No full compositor reload is issued.
An independent watchdog restores the source, original action and policy if the
editing process dies. Undo rejects source changes made elsewhere rather than
replacing them. Journals are private in SwiftShell's state directory.

Default Apps uses the same transaction to update a uniquely recognized literal
`TERMINAL` variable and its default-terminal launch callback. Actions which run a
task inside a terminal, such as `TERMINAL .. " -e btop"`, are separate actions and
do not make default-terminal detection ambiguous. The original launch prefix is
retained. Unsupported configuration forms remain shell-only and are labeled that
way; no alternative bind is silently installed.

Validation on 2026-11-05:

- Source helper: 16 tests; default-app helper: 13; legacy shortcuts: 12.
- `tests/live/source-shortcuts.py --live`: private no-op source span edit, original
  callback execution, exact bytes/mode Undo, and independent recovery after an
  interrupted helper. All 94 original bindings remained unchanged.
- `tests/live/source-shortcuts-ui.py --live`: native recorder inhibited Super+Space,
  captured Ctrl+Super+F12, applied it to a private source binding and restored it
  with Undo. No user action or game received those captured keystrokes.
- Authorized real fix: selected Konsole was synchronized to the existing default
  terminal shortcut. Only the literal in `variables.lua` and that one live callback
  changed. The other 93 effective bindings and all other loaded source files were
  unchanged. File mode and the original reload policy were retained. No terminal
  app was launched and no global reload/display mode change was performed.

The owner should verify Super+Enter opens Konsole. Actual login/reboot was not run.
Future launches read the modified original source. The original variable and
callback are recoverable through Default Apps → Terminal → Undo, or the private
transaction journal (`ba2127753a494d2c86500dafef5cb2cd` on this reference session).
Restore only SwiftShell-owned transaction changes; do not replace an entire
Hyprland configuration directory or reload display modes to undo a shortcut.
