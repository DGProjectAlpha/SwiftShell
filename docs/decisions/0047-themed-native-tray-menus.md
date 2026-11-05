# Themed native tray action menus

Date: 2026-11-05

Exported application tray menus now use SwiftShell's shared frosted surface,
Theme colors, radius, spacing, typography and native compositor backdrop effect.
The menu remains backed by Quickshell's actual QsMenuOpener/QsMenuEntry objects:
actions, disabled rows, separators, checkboxes, radio buttons and submenu updates
retain their application-owned behavior. Native labels are already cleaned by
Quickshell, so literal ampersands are preserved.

Submenus use a Back row in the same surface. Ancestor openers stay alive until
the menu closes; actions return before their native entries are released.
Navigation supports arrows, Home/End, typeahead, Enter/Space, Back and Escape.
An outside click or a click on the host bar's empty space dismisses the menu.
Placement follows the actual host screen and is clamped to its logical bounds.
No GTK/system theme or application configuration changes are required.

Verified against installed Quickshell 0.3.2 metadata, official versioned type
documentation and upstream DBusMenu implementation. The native fixture uses its
own D-Bus session and synthetic StatusNotifier/DBusMenu service, never the user's
Steam, Discord or other application's actions.

Validation:

- `node tests/menu.test.js`: native caption/shortcut handling, navigation,
  disabled/separator guards and Qt 6.4 indexed-model compatibility passed.
- `tst_tray_menu.qml`: seven checks passed, including native state preservation,
  ancestor lifetime, deferred action dispatch, keyboard and blank-bar dismissal.
- Existing `tst_tray.qml`: seven checks passed.
- `python3 tests/static_check.py`: passed, 127 QML files.
- `python3 tests/live/tray-menu.py --live`: passed on HDMI-A-1 and DP-1 using the
  actual native menu API and compositor geometry. Real synthetic menu actions,
  disabled action suppression, check/radio states, submenu/Back, Escape,
  blank-bar dismissal and both dark/light shared appearance passed.
- Owned QML surface captures for both outputs and themes were visually inspected.
  An opaque background in the same owned scene prevents desktop/application pixel
  capture. These item captures demonstrate layout and colors; they do not measure
  compositor Gaussian blur strength. Native backdrop attachment is checked
  separately by the fixture.

A tray item which exports no menu handle can only invoke its app-owned popup
through the original native fallback. That popup cannot be styled by SwiftShell.
Menu depth is bounded to 16 to retain a predictable number of native openers.
The main running shell was not restarted by this change's isolated tests.

Recovery: revert this commit to restore the previous native QMenu path; no user
settings migration or external configuration cleanup is needed. Original tray
sources were additionally backed up under `/tmp/swiftshell-tray-theme-backup-m235wf22`
before editing. Tests remove only their own fixture windows/processes and restore
focus/cursor after execution.
