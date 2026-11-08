# 0050 — Owner-requested return to the system login screen

The owner explicitly redefined Lock as signing out to the login screen shown at
boot, and Suspend as sleeping with that same login screen on resume. This
supersedes decision 0049's Hyprlock behavior. These actions close applications;
Power and Spotlight explain that consequence and require a second selection.
Log out remains an alias for ending the current Hyprland session.

The reference desktop uses Plasma Login 6.8.2, not a Quickshell password screen.
Read-only system-bus introspection confirms its DisplayManager Seats and Seat0
interfaces. Its autologin/relogin configuration is off. Lock dispatches the
verified current-compositor Lua exit route after current UID/session validation.
No password is accepted by SwiftShell and Hyprlock is never started. Its unused
bundled configuration and dependency warning have been removed; installed packages
and user-owned locker/PAM/display-manager configuration are left untouched.

For Suspend, `systemd-inhibit --what=sleep --mode=delay` runs a fixed internal
helper. It requests logind Suspend(true) while the user's session/authorization
agent remains available, waits for PreparingForSleep, and only then ends the
validated current desktop. The delay inhibitor remains while compositor exit is
confirmed. A delayed/refused exit falls back to `loginctl terminate-session` of
only that previously validated session, never a user-wide or unrelated-session
kill. Denial/authorization timeout before sleep acceptance leaves apps running.
The helper does not bypass blocking inhibitors, install sleep hooks/services or
require a privileged resident daemon. The boot greeter is started by the existing
display manager as part of normal session completion.

Tests exercise confirmations, scoped exit, delay coordination, refusal/timeout,
actual bus response formats and unchanged reboot/poweroff paths. Read-only native
probes and a harmless inhibitor acquisition/release pass on the real system.
Actual logout and sleep/resume are intentionally pending owner testing; they would
close the current desktop and running applications. Do not describe the physical
sleep/login round trip as verified by these non-disruptive tests.

Recovery: revert this change and restart only SwiftShell. No system configuration
or service rollback is necessary. Source backup: /tmp/swiftshell-greeter-actions-backup.
