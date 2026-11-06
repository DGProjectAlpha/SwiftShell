# 0051 — Restore Hyprlock after a non-locking PAM check

The owner requested Hyprlock again after clarifying the distinction between
locking and logging out. This supersedes decision 0050. Lock keeps applications
running behind Hyprlock; Suspend waits for a secure lock then requests logind
sleep; Log out ends the current desktop and returns to the system login manager.
The shared helper and confirmation rules from decision 0049 are restored. Power
and Spotlight now explicitly distinguish preservation of apps from signing out.

Before activation, the owner entered their password in the local, non-locking
`scripts/test-hyprlock-auth.py` dialog. The actual current user's `hyprlock` PAM
service returned authenticated=true, pamCode=0. No password was put into commands,
files or logs, and no locker/session was opened during the check. The owner also
reported that the dialog passed. No PAM configuration was changed.

This proves the entered password is accepted by the exact PAM service Hyprlock
uses. It does not identify the cause of the earlier rejection or prove real
lock-screen keyboard/input handling, physical suspend/resume or unlocking after
resume. Those remain explicit owner acceptance checks. No automatic unlock
backdoor, temporary password or authentication bypass was added.

Recovery: revert this restoration and restart only SwiftShell. The previous
sign-out behavior is backed up in /tmp/swiftshell-hyprlock-restore-backup; the
prepared restoration patch/config are retained in /tmp for audit/recovery. User
Hyprlock configuration takes precedence over the restored bundled fallback.
