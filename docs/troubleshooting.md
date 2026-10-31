# Troubleshooting the alpha

These notes are for the first live run. They are not a record of a session that already passed.

## The bar does not appear

Run `swiftshell doctor`. It should find Quickshell at 0.2.0 or newer. Then run `swiftshell start` and read the terminal. `swiftshell stop` stops only the SwiftShell path.

If another Quickshell config is already the default `shell.qml`, `swiftshell start` is still the launch command. `activate` does not replace that file.

## Noctalia and SwiftShell overlap

That can happen. SwiftShell does not stop Noctalia. Set `bar.reserveSpace` to `false` while both draw on the same output, or stop Noctalia yourself with its own command. Do not use a Quickshell kill to stop Noctalia.

## The panels look flat

That is the current material. Quickshell 0.2 has no backdrop-blur type, and this shell does not change Hyprland blur rules. A translucent scrim is the surface. The corner radius is not a clipped blur mask.

## Wallpaper did not replace the other wallpaper

SwiftShell draws its own background layer. It does not kill hyprpaper or swww. Turn **Draw wallpaper** off to unload SwiftShell's layer. If the picture is missing or rejected, the crimson image is used.

## Settings look wrong after an update

`git pull` and `./install.sh` do not rewrite an existing settings file. `swiftshell rollback-settings` restores the SwiftShell backup if that file exists. If doctor says the settings file is unreadable, move it aside and start again so a new file can be created. Doctor will not print the file.

## Notifications did not move

Ownership starts at off. The page asks a second time before the server is created. If another program already owns notifications, SwiftShell leaves that owner in place when the server cannot be created. Release ownership from the page to hand it back. Sounds are not played.

## A control does nothing

Network, brightness, display apply, and shortcut install are labeled unavailable on purpose. Bluetooth does not start a scan. A tray item with no action is hidden. A player button stays idle when the player says the action is not allowed.

## The launcher misses an application

Search uses Quickshell's application list. A desktop id has to be visible to that list. The query is not run as a shell command. At most 24 matches are shown.

## Removing it

```sh
swiftshell stop
swiftshell deactivate
swiftshell uninstall
```

Hyprland config files are not part of that removal. Add `--purge-settings` only when you also want `~/.config/swiftshell` gone.
