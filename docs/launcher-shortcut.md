# Super+Space

SwiftShell never silently changes this shortcut. A handoff requires explicit approval and a backup. The local owner approved the one-line handoff on 2026-11-01; Super+Space now invokes this checkout’s launcher script.

The launcher opens from the bar’s Search control. Requests now use direct, scoped Quickshell IPC. From a checkout:

```sh
scripts/request-launcher.sh
```

After `./install.sh`, the same action is `swiftshell request-launcher`. Both commands call `swiftshell launcher toggle` on the selected configuration path. The checkout script selects this checkout; the installed command selects its installation. A missing or outdated shell returns a failure with guidance instead of silently queuing a token. Neither command edits Hyprland or starts another shell.

A request opens Spotlight; another closes it. Search on the bar always opens. The old watched-token channel remains for older external callers, but the supported request scripts no longer depend on it. Direct commands are `qs ipc -p /path/to/shell call swiftshell launcher open`, `close`, or `toggle`.

The card is placed on the Hyprland monitor that is focused at the moment of that request. That can be a different output from the bar. DP-1 and HDMI-A-1 are both handled from the live screen list, including HDMI-A-1 at scale 1.25, because the shell uses each screen's logical size. It does not hardcode those connector names for Spotlight. If focused-monitor information is missing, the first connected screen is used. If the chosen screen disappears while Spotlight is open, Spotlight closes and drops its keyboard grab.

The intended result, after the handoff below, is: Super+Space opens Spotlight on the focused monitor, typing filters applications, Enter launches the selected row and closes Spotlight, and Super+Space again closes it. Escape and a click outside the card also close it.

## Handing Super+Space over

Do this only after Search already opens the launcher on the hardware, and only if that shortcut should stop launching the other tool. This repository does not perform the edit.

1. Copy the live binds file before changing it. On the reference layout that path is `~/.config/hypr/config/binds.lua`. If the file lives somewhere else, copy that file instead.

   ```sh
   cp -- ~/.config/hypr/config/binds.lua ~/.config/hypr/config/binds.lua.bak-swiftshell
   ```

2. Open the original file and find the existing Super+Space entry. Change only the command that entry runs. Point it at the absolute path of `scripts/request-launcher.sh` in this checkout, or at `swiftshell request-launcher` if that command is on `PATH`. Leave every other bind as it is. Do not replace the file with an example from this repository. This session's Lua shape is the authority, and the current local session has read-only audited that command.

3. Reload Hyprland the way that session is normally reloaded. SwiftShell does not run that reload, and it does not change autostart or Noctalia.

4. SwiftShell has to be running already. The script calls the running shell directly and returns an error if it cannot reach it.

## Rollback

1. Copy the backup back over the binds file you edited.
2. Reload Hyprland the same way as in the step above.
3. Search on the bar still opens the launcher. Noctalia is not part of either step.

Keep the backup until the edited shortcut has been tried. If the edited command cannot be found, the rollback is the backup file, not a new binds file written from memory.

## Approved local handoff, 2026-11-01

The owner explicitly authorized backups and applying the prepared change. Only
the existing Super+Space exec command changed, from Noctalia’s launcher command
to `/home/daniel/SwiftShell/scripts/request-launcher.sh`. No other Noctalia
binding, process or service changed. An exact timestamped backup is retained at
`~/.config/hypr/config/binds.lua.bak-swiftshell-launcher-20261101T132508Z`.

The replacement was syntax-checked with `luac -p`, atomically written and loaded
by Hyprland’s automatic configuration reload. Configuration errors stayed empty.
Both output modes, transforms, scales and positions stayed unchanged. All 94
binding descriptions, chords, flags, dispatcher kinds and submaps were preserved.
Opaque Lua callback addresses change during reload and were compared by callback
kind after an initial strict check detected that expected address change and
safely rolled back.

`python3 tests/live/launcher-shortcut.py --live` injects real Wayland Super+Space
key events through the effective compositor binding: opening on the focused
output, repeated toggling and Escape passed on both connected monitors. This
exercises the actual global binding, rather than calling launcher IPC directly.
It does not claim a human physical-keypress or reboot test.

For rollback, restore the old exec command from the timestamped backup, preserve
any subsequent edits, syntax-check and allow Hyprland to reload. If no subsequent
changes exist, the full backup is also an exact restoration. Do not overwrite
newer unrelated binding edits with an old whole-file backup. This checkout must
remain at its current location; moving or removing it requires updating that
explicit command or restoring the previous launcher binding.
