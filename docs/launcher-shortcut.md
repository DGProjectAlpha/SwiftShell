# Super+Space

SwiftShell does not change this shortcut. The running session keeps whatever Super+Space already does until the steps below are done by hand.

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

## Local conflict audit, 2026-11-01

The effective Super+Space binding still points at Noctalia's launcher. It was
not changed by the invocation repair. The prepared local handoff replaces only
that binding's exec command with the absolute checkout request script. It must
be explicitly approved, backed up, syntax-checked and verified after compositor
reload. Reverting that single line restores the previous launcher; no other
Noctalia binding or service needs to change. The physical Super+Space acceptance
test remains pending until the handoff is authorized.
