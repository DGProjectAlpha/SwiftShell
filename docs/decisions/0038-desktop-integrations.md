# Native default applications and managed desktop shortcuts

Date: 2026-11-01. Roadmap E1 and the safe managed portion of D.

## Default applications

Settings → Default applications discovers installed desktop entries from XDG data
directories, honors user masks and unavailable TryExec programs, and shows actual
application names/icons. Browser, email, calendar, terminal, file manager, images,
media and PDF are distinct roles. Only applications advertising a relevant MIME
type are offered, except terminal/calendar categories where a shell preference is
explicitly identified. Terminal has no universal freedesktop default; choosing it
only affects SwiftShell's terminal action. A calendar app without MIME registration
is likewise a shell preference. This workstation currently has no registered
calendar application; the UI does not invent one.

Changes go through xdg-mime and are read back before success. Before changing
anything, the helper backs up existing user MIME preference files and its own
role state into a restricted, timestamped JSON file in SwiftShell's state directory.
An incomplete change restores the associations it already changed. Undo restores
only MIME keys owned by that role to their previous defaults, preserving unrelated
keys/comments and refusing to overwrite a subsequent external change. When a key
previously had no explicit association, undo removes only SwiftShell's matching
default, retaining normal desktop fallback. Symlinked preference files stay links.
Malformed/future SwiftShell preference state is protected rather than overwritten.

Opening an application uses gio's desktop-file parser. HTTP/HTTPS links go to
xdg-open and the actual system browser. No desktop Exec string or URL is evaluated
by a shell. Calendar launch opens the chosen app without claiming date-specific
navigation. No application is launched merely by listing defaults.

## Desktop shortcuts

Settings → Keyboard shortcuts provides a searchable effective view of the actual
Hyprland binding registry and a separate editor for SwiftShell-managed shortcuts.
The native reference session reports 94 active bindings, including physical
code:N workspace bindings and Lua dispatcher callbacks. The owned catalog covers
Spotlight, Settings, Control Center, preferred terminal, directional window focus
and movement, floating/fullscreen/maximize, and workspaces 1–10.

The recorder uses the installed Quickshell 0.3.2 ShortcutInhibitor with the actual
Settings window. It waits for compositor confirmation before accepting a chord,
lets Escape cancel, and releases inhibition after apply/cancel/timeout/destruction.
This prevents ordinary global shortcuts from executing while they are recorded.
Reserved console combinations and unmodified typing keys are rejected.

Collision checks include both named keys and physical keycodes, resolved through
the active keyboard's libxkbcommon layout. An existing Super+1 code:10 workspace
shortcut is correctly detected, not silently shadowed. Fixed action dispatchers
are created through public hl.bind; only the returned handles stored in
_G.__swiftshell_shortcuts may be removed. The helper never unbinds a user's chord.
Changes are backed up, read back from Hyprland, atomically saved, and reversed if
verification fails. Remove affects only the selected owned shortcut; Undo change
restores the prior managed set after another collision check. The service reapplies
saved choices when SwiftShell starts and after a compositor configuration reload.
Conflicts introduced elsewhere are reported and left alone.

### Important API limitation

The verified Hyprland 0.57 Lua query API has no public get_binds handle query.
j/binds exposes an opaque callback reference in arg, not the original dispatcher
arguments or Lua closure. The HL.Keybind wrapper exposes enable/remove and metadata,
but no rebind/invoke operation. Consequently existing user-authored Lua bindings
are displayed read-only. The UI states this limitation; it does not pretend to
edit all arbitrary Lua actions, regex-rewrite binds.lua, or replace an unrecoverable
callback. Managed shortcuts are persistent while SwiftShell participates in the
session; they do not install autostart or alter user Lua.

## Evidence and recovery

- python3 tests/test_defaultapps.py: 10 tests, passed.
- python3 tests/test_shortcutsctl.py: 12 tests, passed.
- python3 tests/live/default-apps.py: actual xdg-mime selection/readback,
  timestamped backups and scoped undo passed in isolated XDG directories.
- Actual read-only active-layout verification resolves keysym 1 to code:10 and
  reports the existing primary workspace shortcut as a conflict.
- scripts/check.sh passed after the rebuilt pages and accurate inhibitor stub
  were added. Full native capture/apply evidence is recorded below.

Own files: $XDG_STATE_HOME/swiftshell/default-apps.json and shortcuts.json;
restricted backups/default-apps-*.json and shortcuts-previous.json are retained.
Use per-role Undo or managed shortcut Undo change/Remove for normal recovery.
Noctalia, existing global binds, user Lua, display modes, autostart and services
remain outside these integrations. No actual lock, suspend or shutdown is used in
tests. No calendar account/event synchronization, arbitrary macros or global
user-Lua rewrite support is claimed.

API references: the freedesktop MIME Applications specification
(https://specifications.freedesktop.org/mime-apps/latest/), Hyprland binds
(https://wiki.hypr.land/configuring/core/binds/), and version-matched Hyprland
v0.57.0 LuaBindingsQuery.cpp, LuaBindingsToplevel.cpp and LuaKeybind.cpp sources.

Native shortcut evidence: python3 tests/live/shortcuts-native.py --live passed on
the real Hyprland session. A separately named, temporary-XDG audit loaded the real
Shortcuts page in its own window. The compositor confirmed shortcut inhibition;
actual Super+Space reached the recorder without opening live Spotlight. An unused
Ctrl+Super+F12 was recorded, applied through hl.bind, read back, and removed through
its owned handle. The complete original 94-entry effective binding registry was
unchanged after cleanup. The audit closed its own window/process and restored the
previous active window. No user-authored shortcut, MIME preference or Lua file was
changed by this audit. This verifies the native recorder/backend, not arbitrary
Lua editing or persistent behavior after a physical reboot.
