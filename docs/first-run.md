# First-run smoke checklist

Use this in an authorized idle Hyprland session. It is a checklist, not a record
of passed hardware tests. Back up your SwiftShell preferences before an update.
See [install](install.md) for commands and [testing](testing.md) for the safety
preflight. Do not run interactive fixtures while an app is fullscreen.

1. Install alongside the current shell, run `swiftshell doctor`, activate and
   start. Confirm foreign config, Noctalia and autostart remain unchanged. Plan
   bar overlap/reservation explicitly; launching never stops another shell.
2. Open Settings from Spotlight/bar. Check one native window, titlebar move,
   edge/corner resize, minimize/reactivation and saved size. Search for a setting,
   navigate every page and use Collapse all / Expand all.
3. In Top bar choose one display in Apply to. Change size, background or clock;
   confirm the other display stays unchanged. Try All displays and verify only
   the edited property becomes shared across custom bars. Restore your values.
4. Verify workspace state and switching on each output, including any saved
   named/empty indicators. Confirm normal maximize respects reserved space,
   fullscreen follows policy and a popup dismisses with one outside click.
5. Open Spotlight, find/launch an installed app, use favorites and dismiss with
   Escape/outside click. Existing shortcuts stay unchanged unless explicitly
   handed over; see [launcher shortcuts](launcher-shortcut.md).
6. Choose an image and slideshow folder, test Cover/Contain, per-output choices,
   contrast and missing-file recovery. Missing optional modules must explain
   their fallback rather than crash.
7. Check available audio/media/tray, network/Bluetooth and power state. Real
   connection, pairing and session actions need deliberate approval; do not
   execute shutdown or change displays merely to exercise a control.
8. Test notifications only after an explicit ownership handoff with recovery.
   Enabling a preference is not proof that SwiftShell owns the notification bus.
   Clipboard, weather and sounds remain opt-in.
9. Restart only SwiftShell and verify preferences persist. Check physical
   hotplug, lock/sleep and GPU load separately with a recovery plan.

## Recovery

`swiftshell stop` stops the installed path; `scripts/stop.sh` stops this checkout.
Inspect `qs list --all` before any instance-specific kill. Never kill all `qs`
processes. `swiftshell rollback-settings` restores only its protected settings
backup, not compositor or other-shell state. `swiftshell deactivate` removes
registration; uninstall preserves preferences unless `--purge-settings` is
explicitly requested. See [troubleshooting](troubleshooting.md).
