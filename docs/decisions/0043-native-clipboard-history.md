# Native clipboard history surfaces

Date: 2026-11-02

The Clipboard bar panel and optional floating window share the existing
DesktopTools session-only text history. Collection remains an explicit opt-in:
30 recent text entries, at most 4096 characters each, expiring after 20 minutes.
Nothing is written to disk. Advertised sensitive formats are excluded, but a
password copied by an application without privacy hints can still enter history.
The panel states that limit and provides individual removal and Clear actions.
Turning collection off immediately clears history. Image history is not supported.

ClipboardModel owns filtering, copy/remove/clear and the detached window lifecycle;
it does not log clipboard data. Text previews render PlainText even when contents
look like markup. Entry identifiers remain unique for distinct copies occurring
within the same millisecond. Search and Enter/arrow navigation work in both views.
A successful selection closes a bar panel and leaves the detached window open.

The floating window uses the same theme/BackdropEffect/shadow as Settings and
native startSystemMove/startSystemResize. It remembers geometry only (never
clipboard contents), clamped to connected logical monitor bounds. The scoped
helper verifies process ID, application class and title before addressing any
window. A temporary class/title rule prepares first placement; the installed
Hyprland 0.57 matcher has no ordinary public PID rule, so this preparatory rule
is limited by exact SwiftShell Clipboard title/class rather than PID. Actions
on mapped windows always use the verified owned address. Close/destruction remove
the owned temporary rule; the owner check prevents stale cleanup removing a newer
instance's rule. No user Lua or autostart is changed. A process crash before
cleanup can leave the harmless exact-title runtime rule until the next open or
Hyprland reload; it does not create a persistent config entry.

Verification on Quickshell 0.3.2 / Qt 6.12 / Hyprland 0.57:

- `node tests/desktop-tools.test.js`: bounded history, unique same-time IDs,
  filtering, literal preview and multiline metadata passed.
- `python3 tests/test_clipboardwindow.py`: five tests passed, covering PID/title
  scope, first-placement rule, exact-address actions, logical bounds and missing
  windows.
- `tst_clipboard.qml`: seven checks passed, including pointer copy/removal/Clear,
  keyboard search/selection, disabled/expired entries, literal rendering and window
  instantiation.
- `python3 tests/live/clipboard-history.py --live`: real Quickshell copy through
  Qt's private offscreen clipboard passed. Native floating/focus/shared blur
  attachment/Escape/close and first placement passed on DP-1 and HDMI-A-1. The
  fixture uses synthetic history and a reader that never invokes wl-paste. No
  desktop clipboard contents or unrelated pixels were read or overwritten.

Native drag and edge/corner resize gestures are wired to verified installed
Quickshell APIs but were not separately pointer-exercised in this slice. Blur
attachment readback is not an image-based blur-strength measurement. Full text
clipboard collection from ordinary third-party applications remains owner
acceptance; the test intentionally avoids that private data.

Recovery: close the Clipboard window; disabling history clears in-memory entries.
Revert the feature commit for source rollback. Geometry is stored separately as
SwiftShell state `clipboard-window.json`; deleting that own state file resets
placement. No system services or compositor configuration files are modified.
