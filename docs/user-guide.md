# Using the SwiftShell alpha

SwiftShell draws its own bar, launcher, settings window, wallpaper layer, and optional notification host. Hyprland still owns windows. Noctalia is left in place.

## Install and start

From a checkout:

```sh
./install.sh
swiftshell doctor
swiftshell activate
swiftshell start
```

`swiftshell start` runs Quickshell against the installed copy. It does not replace another config. `swiftshell stop` stops that copy only. Noctalia is the `noctalia` executable. Do not stop it with a Quickshell kill.

If `~/.local/bin` is not on `PATH`, the installer says so and does not edit your shell startup files.

A new settings file reserves space for the bar. An older file that still says `"reserveSpace": false` stays an overlay. Leave it false while Noctalia is also drawing on that output.

## Bar

The bar follows the focused monitor, then the first screen, unless `bar.targetMonitor` names a connector or a Hyprland description. Workspace clicks use the Lua dispatch `hl.dsp.focus({ workspace = N })` unless the settings file selects `legacy`.

The clock opens the calendar. The mark at the right opens the control center. Search opens Spotlight on the monitor that is focused at that moment. `swiftshell` does not capture Super+Space. See `docs/launcher-shortcut.md` if you want to point that chord at SwiftShell yourself.

## Settings

Open Settings from Spotlight or from the control center. It is one normal window. The compositor's move and resize binds are what move it. Escape closes it. A second request raises the same window.

Appearance, the top bar, wallpaper, the display preview, preferred chords, audio, and notification rules are stored in `~/.config/swiftshell/settings.json`. Undo and Reset on Appearance write that file. Search hides controls that do not match. Escape in a filled search field clears the query before the next Escape closes the window.

High contrast is a text setting. A manual hex color still wins. Automatic text still follows a sampled png.

## Wallpaper

One background layer is drawn per output when wallpaper is enabled. An empty path uses the packaged crimson image. Cover crops. Contain shows the whole picture. Turning wallpaper off removes SwiftShell's layers and does not stop hyprpaper or swww.

The slideshow walks the paths stored in settings. It does not scan a folder. The clock waits at least one minute. Jpeg and webp can be shown. Only png pixels are sampled for contrast.

## Services

The control center volume slider writes the default PipeWire sink when that service is present. A microphone row appears when PipeWire has a default source. Play, pause, next, and previous run only when the player allows them. A tray icon activates on click, or opens its menu when that is the only action. An icon that cannot be used is not shown.

Bluetooth lists devices the adapter already knows. This shell does not start a scan. Battery reads UPower when the display device is ready. Lock, suspend, restart, and shut down ask for a second confirmation, then run `loginctl`.

Network and brightness stay unavailable. The pages say so. There is no scan button and no software dimming presented as hardware brightness.

## Notifications

Ownership stays off until Settings asks a second time. The preview card is labeled Preview and does not take the bus. Do not disturb keeps an ordinary notification in history and still banners a critical one. Hide drops an application, including a critical notification. Quiet keeps a normal notification in history. Sounds are not played.

## Recovery

`swiftshell doctor` prints versions, says blur is unavailable, and reports notification ownership without printing the settings file. It does not edit Hyprland or Noctalia.

`swiftshell rollback-settings` restores `settings.json` from `settings.json.bak-swiftshell` only. Copy the settings file aside before the first launch of a new version if it contains keys the settings window does not know.

`swiftshell uninstall` removes the installed copy and keeps settings. `--purge-settings` removes `~/.config/swiftshell` and nothing else under `~/.config`.
