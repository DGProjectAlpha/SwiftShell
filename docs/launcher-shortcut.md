# Super+Space

SwiftShell does not change this shortcut. The running session keeps whatever Super+Space already does.

The launcher opens from the bar's Search control. It also opens when a running SwiftShell sees a new token in the XDG state file. From a checkout:

```sh
scripts/request-launcher.sh
```

After `./install.sh`, the same action is `swiftshell request-launcher`. Both commands create only `$XDG_STATE_HOME/swiftshell/launcher.request` (or `~/.local/state/swiftshell/launcher.request`). They do not read or write Hyprland's configuration.

## Handing Super+Space over

Do this only after the Search control already opens the launcher on the hardware, and only if you want that shortcut to stop launching the other tool.

1. Copy the live binds file before changing it. On the reference layout that path is `~/.config/hypr/config/binds.lua`. If the file lives somewhere else, copy that file instead.

   ```sh
   cp -- ~/.config/hypr/config/binds.lua ~/.config/hypr/config/binds.lua.bak-swiftshell
   ```

2. Open the original file and find the existing Super+Space entry. Change only the command that entry runs. Point it at the absolute path of `scripts/request-launcher.sh` in this checkout, or at `swiftshell request-launcher` if that command is on `PATH`. Leave every other bind as it is. Do not replace the file with an example from this repository. This session's Lua shape is the authority, and this repository has not read that file.

3. Reload Hyprland the way that session is normally reloaded. SwiftShell does not run that reload.

4. SwiftShell has to be running already. The script only writes the request token. The shell opens the launcher when the token changes. A token that was already there at startup does not open the launcher.

## Rollback

1. Copy the backup back over the binds file you edited.
2. Reload Hyprland the same way as in the step above.
3. Search on the bar still opens the launcher. Noctalia is not part of either step.

Keep the backup until the edited shortcut has been tried. If the edited command cannot be found, the rollback is the backup file, not a new binds file written from memory.
