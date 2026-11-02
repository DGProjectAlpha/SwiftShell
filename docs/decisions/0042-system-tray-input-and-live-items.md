# System tray: complete registration visibility and native item actions

Date: 2026-11-01. User-reported missing tray items and unavailable context menus.

The bar's tray previously copied four item snapshots into a Repeater, displayed an
unclickable overflow count, accepted only left clicks, and chose only one primary
action. Consequently application menus were unreachable even when published.
Snapshots also stopped reacting to native title, icon and menu-readiness changes.
The bar's separate high-z right-click handler additionally intercepted tray clicks;
its placement is corrected by the accompanying bar integration.

TrayModule and TraySection now consume the real Quickshell SystemTray.items
ObjectModel directly. Every registered object is represented, including items whose
menu is still loading. There is no fixed four/twelve-item cap or inert overflow
label. Delegates retain the actual native object rather than looking it up by a
potentially duplicated application id. Icon/title/menu/status bindings update in
place. Missing/failed icons have a readable monogram fallback. Attention state has
a restrained static indicator; application icons keep their own branding.

TrayItemControl centralizes primary activation, right-click menu, middle-click
secondary activation, wheel forwarding, and Menu/Shift+F10 keyboard access. Native
menus use item.display(parentWindow, x, y) with coordinates mapped to that exact
bar/panel window in logical pixels. ItemIsMenu changes primary activation into a
menu action. A menu-only item without a ready menu remains visible but disabled.
Tooltips and labels use plain text and the shared Settings typography/material.

Verified installed API: Quickshell 0.3.2 SystemTrayItem exposes activate(),
secondaryActivate(), scroll(int, bool), display(QObject, int, int), hasMenu,
onlyMenu, icon/title/status, and a native ObjectModel. No subprocesses or extra
tray daemon are introduced. SwiftShell does not take over another application's
notification service or modify Noctalia, autostart, system services or Lua files.

Evidence:

- tests/qml/tst_tray.qml: 7 passed. Seven fixture registrations all remain visible;
  pointer left/right/middle, wheel, keyboard menus, host-relative coordinates,
  transient menu readiness, and live-role delegate identity are exercised.
- tests/live/tray-native.py --live: passed with a hidden actual Quickshell window
  and temporary XDG preferences. Native rendered count/order matched every actual
  StatusNotifier registration (two at audit time). No application was activated.
- Read-only session audit found running Steam and Discord and exactly two watcher
  registrations. Cachy-Update is installed (desktop Exec arch-update), but no
  updater or XEmbed proxy process was running and no updater item was published.

Actual Steam/Discord menu open/dismiss interaction awaits the parent's main-shell
restart and input-routing test; no menu action such as Quit was executed here.
The shell can display registered StatusNotifier tray applications, not every
background process. Legacy XEmbed applications require a compatible bridge that
is absent in this session; this change does not silently install/start one.

Recovery is a source revert. No user preferences or outside configuration files
are changed by this slice. Native registration/disappearance follows the existing
session bus, with no shell-owned cache or retained private notification contents.

Native application menus additionally require root `UseQApplication`; the real
menu audit exposed the missing startup mode, now guarded by the static suite.
The public QsMenuAnchor exposes native menu visibility for open/Escape checks.
