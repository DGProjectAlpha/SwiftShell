# 0049 — Real lock, suspend and current-session logout

The previous Lock action only called `loginctl lock-session`: that emits a request,
not a lock screen. The reference desktop had no installed/listening locker. Logout
was absent from the action catalog. The bar dispatched detached commands and
reported a request even when a command subsequently failed; Spotlight used a
separate process and displayed only a generic failure.

A shared `SessionActions` QML singleton now invokes one fixed, allowlisted helper.
Both Spotlight and the bar/Settings power section observe its availability, busy
state and readable errors. No action is built from launcher query text. Lock acts
on one click; suspend/logout/restart/shutdown retain explicit confirmation.
The Spotlight strip includes Log out and computes widths from its actual action
count so controls fit at narrow widths.

`sessionctl.py` validates the active local graphical session against logind and
its UID, rejecting stale, foreign and ambiguous session IDs. It queries logind's
CanSuspend/CanReboot/CanPowerOff APIs and uses verified Hyprland 0.57 Lua IPC for
current-compositor logout (`hl.dispatch(hl.dsp.exit())`). It never terminates an
entire user or another session. The exact-version dispatcher source registers
`exit` with zero arguments:
https://github.com/hyprwm/Hyprland/blob/0aa6745f705f2c4b0a5004eb019ef76e5bbdb426/src/config/lua/bindings/LuaBindingsDispatchers.cpp

Lock launches the installed hyprlock and waits for `hyprctl -j locked` to confirm
that the compositor is securely locked. Starting a process alone is not success.
Suspend requires that acknowledgement, checks the lock again and calls logind's
`Suspend(true)` with interactive authorization allowed. It does not bypass sleep
inhibitors. Reboot/poweroff keep their previous working systemctl routes. A void
D-Bus success reply is handled without attempting to parse an empty JSON string.
Failures and missing providers remain visible instead of being reported as success.

Existing user `hyprlock.conf` takes precedence. A restrained neutral fallback is
bundled inside SwiftShell; no user-authored Hyprland file is overwritten. Hyprlock
owns authentication and its PAM conversation; SwiftShell receives no password.
The reference owner authorized installation of the signed hyprlock 0.9.7-2.1
package. The resolved transaction installed only that package, including its own
standard PAM service; it upgraded no dependency and changed no autostart/service.
The dependency checker warns when the optional locker is absent.

Validation includes helper unit tests for lock acknowledgement, timeout/failure,
suspend ordering, authorization/inhibitors, exact logout scope, existing power
routes, session resolution, user-config precedence and non-disruptive dry runs.
QML tests cover confirmation, shared error propagation, missing-provider states
and helper crashes. Native `tests/live/session-actions.py --live` loads the actual
QML/Process implementation in a private copy whose replaced helper can only record
IDs and refuse requests. It cannot perform real system actions. Production helper
snapshot/dry-run on the real system reports lock/suspend/logout available.

Actual lock/unlock authentication, suspend/resume and logout to the greeter were
not triggered during development, to preserve the running session. Owner acceptance
is still required. A missing package or custom locker configuration can fail closed
with a visible reason; the shell never substitutes an insecure overlay.

Recovery: revert this feature commit and restart only SwiftShell. The source backup
is `/tmp/swiftshell-session-actions-backup`. Hyprlock can remain installed; package
removal is a separate owner choice. User Lua, monitor modes, Noctalia, existing
shortcuts and service startup were not changed.
