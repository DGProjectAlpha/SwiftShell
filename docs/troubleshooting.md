# Troubleshooting

## Missing bar or startup failure

Run `swiftshell doctor`, then `swiftshell start` and inspect the terminal/log.
The supported floors are Quickshell 0.3.2, Hyprland 0.57 and Qt 6.9. A default
Quickshell config does not prevent explicit `--path` launch. Development launch
and installed launch use different source trees; reinstall after updating source
if you intend to run the installed copy. A lazy-loaded component may require a
scoped restart to test a fresh definition.

## Another shell overlaps

SwiftShell never stops Noctalia or another wallpaper service. Coordinate output
placement and reservation before running both bars. Turn Draw wallpaper off to
remove SwiftShell's background layer. Stop only the selected SwiftShell config;
Noctalia is a separate executable, not a `qs` instance to kill.

## Blur or a service is unavailable

Check the Appearance capability message and [compatibility](compatibility.md).
Real blur needs supported compositor protocols; transparency alone is not blur.
Missing audio/network/Bluetooth/power hardware or tools produces disabled controls
and a reason. Hardware brightness has no packaged backend. Do not insert random
compositor rules or install packages merely to hide an unavailable state.

## A change affects the wrong display

Top bar's Apply to controls the scope of the property you edit. Select one display
for a local override; All displays updates that property across custom bars too.
Where bars appear is global. Use shared settings for this display removes that
bar's customizations. Output identity currently follows connector matching;
reconnecting through a different port may require selecting the new output.

## Preferences or geometry look wrong

Inspect Settings' save/error state. Existing files are validated and migrations
backed up; malformed/future files are protected. `swiftshell rollback-settings`
restores only its own backup. Back up the current file before manual recovery.
Do not overwrite settings blindly or reset compositor configuration. Native
Settings placement and geometry are compositor-controlled, not QML x/y promises.

## Notifications, app search or shortcuts

Notification ownership starts off and requires explicit confirmation. Another
owner may keep the bus; constructing a host is not proof of a handoff. Turning
SwiftShell ownership off does not restart another daemon automatically.

Spotlight indexes DesktopEntries asynchronously; check the desktop entry and
selected search mode. Terminal apps use the selected supported terminal. Search
text is never executed as shell code. Source-backed shortcut edits require an
unambiguous recognized Lua source and compiler validation; generated/opaque
bindings remain read-only. Do not rewrite binds.lua as a workaround.

## Safe stop and removal

```sh
swiftshell stop
swiftshell deactivate
swiftshell uninstall
```

Use `scripts/stop.sh` for the checkout. If path shutdown cannot see the process,
inspect `qs list --all` and kill only that instance ID. Uninstall retains settings;
`--purge-settings` explicitly removes only SwiftShell preferences. Recovery for
live integrations is subsystem-specific; see the relevant decision and recorded
backup rather than assuming a Git revert restores session state.
