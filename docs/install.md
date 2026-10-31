# Install, activate, and remove

SwiftShell installs beside the shell you already use. The installer copies files into SwiftShell's own XDG directories. It does not replace `~/.config/quickshell`, Noctalia, Hyprland startup, keyboard shortcuts, or system services.

These steps were exercised in a temporary home directory with stub commands. They have not been run on a Hyprland session, so a successful install here is not evidence that the bar appears on a monitor.

## Supported systems

Automatic package installation is implemented for Arch-based systems that have `pacman`, including Arch Linux and CachyOS. On any other system the installer still copies files and tells you which packages are missing.

The Quickshell APIs used by the bar were written against the 0.2 and 0.3 documentation. The checker treats Quickshell older than 0.2.0 as too old. Hyprland older than 0.40.0 produces a warning. Those floors are assumptions until a real session confirms them.

## Install from GitHub

```sh
git clone https://github.com/DGProjectAlpha/SwiftShell.git
cd SwiftShell
./install.sh
```

`./install.sh` is safe to run again after `git pull`. It updates the installed copy and leaves an existing settings file in place.

Useful flags:

| Flag | Effect |
|---|---|
| `--install-deps` | On Arch-based systems, ask before installing missing `quickshell` and `hyprland` packages. |
| `--yes` | Answer yes to that package prompt. It does not approve config replacement. |
| `--strict` | Stop before writing files if Quickshell is missing, too old, or unrecognized. |

If `~/.local/bin` is not on `PATH`, the installer prints that fact and does not edit shell startup files. Add the directory yourself if you want the `swiftshell` command.

## Activate, start, and stop

```sh
swiftshell check
swiftshell doctor
swiftshell activate
swiftshell start
swiftshell stop
```

`swiftshell doctor` prints versions, says blur is unavailable, and reports whether a settings file and its SwiftShell backup exist. It prints notification ownership as `off`, `on`, `absent`, or `unreadable`. It does not print the settings file. It does not read or write Hyprland or Noctalia files.

```sh
swiftshell rollback-settings
```

That restores `settings.json` from `settings.json.bak-swiftshell` only. It does not restore any other program's files. If the backup is missing, it stops.

`activate` writes an activation marker, a desktop entry under `~/.local/share/applications`, and a symlink at `~/.config/quickshell/swiftshell` when that name is free. If a default `~/.config/quickshell/shell.qml` already exists, it is left unchanged. Quickshell ignores named configs while that default file exists, so `swiftshell start` is the launch command. It runs `qs --path` against this install.

`activate` does not add the bar to Hyprland's startup list. After you have seen `swiftshell start` behave, you can add that command to your own session startup.

`deactivate` stops this install, removes the symlink when it points at this install, and removes the desktop entry and activation marker. The installed files and settings stay.

## Uninstall

```sh
swiftshell uninstall
```

This removes the installed app, launcher, activation link, and desktop entry. `~/.config/swiftshell` stays, including `settings.json`.

```sh
swiftshell uninstall --purge-settings
```

This also removes `~/.config/swiftshell`. It does not remove other directories under `~/.config`.

## Manual installation

Use this when you want to place the files yourself.

1. Install `quickshell` and `hyprland` with the system package manager.
2. Copy `shell/` to `~/.local/share/swiftshell/app/`.
3. Copy `shell/config/defaults.json` to `~/.config/swiftshell/settings.json` only if that file does not exist.
4. Launch it without registering another config name:

```sh
qs --path ~/.local/share/swiftshell/app --no-duplicate
```

5. Stop that path with:

```sh
qs kill --path ~/.local/share/swiftshell/app
```

Add `--any-display` on Quickshell builds whose `qs kill --help` lists that flag. Quickshell 0.2.0 does not have it. `swiftshell stop` adds the flag only when the installed `qs` advertises it.

Do not copy these files onto `~/.config/quickshell/shell.qml` or into another shell's directory.

## Development launch

From a checkout, `scripts/launch.sh` and `scripts/stop.sh` run the source tree directly. That path is for development. `./install.sh` is the path for a copy that remains after you leave the checkout directory.

## Recovery

`swiftshell stop` or `scripts/stop.sh` asks Quickshell to stop the matching config path. If the command cannot see the instance:

```sh
qs list --all
qs kill --id <instance-id>
```

Read the instance id from the list before stopping anything. Stopping every Quickshell process can stop the shell you were already using.
