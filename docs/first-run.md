# First run on CachyOS

This is the checklist for the Hyprland session. Nothing in this file has been marked passed. Do these steps yourself. Stop if a step damages Noctalia or Hyprland, and use the rollback at the bottom.

Copy `~/.config/swiftshell/settings.json` aside before the first launch of this tree if the file has keys you typed by hand. A version 1 or 2 file is backed up to `settings.json.bak-swiftshell` as the original text, then rewritten as version 3.

## Install beside the current session

```sh
git clone https://github.com/DGProjectAlpha/SwiftShell.git
cd SwiftShell
./install.sh
swiftshell doctor
swiftshell activate
swiftshell start
```

1. Confirm Noctalia is still running if you did not stop it yourself. `swiftshell start` must not stop the `noctalia` executable.
2. Confirm `~/.config/hypr` is unchanged. `swiftshell doctor` must not print the settings file.
3. If both bars share an output, set `bar.reserveSpace` to `false` before judging gaps.
4. `swiftshell stop` stops only this install. Start it again with `swiftshell start`.

## Bar and launcher

5. With **Screens** set to Focused, move focus to the other monitor and see whether the bar follows. Set Primary and confirm it stays on the first screen. Set All and confirm each screen has a bar.
6. Type a monitor name only if you want one specific output. Clear it to use the Screens choice again.
7. Click a workspace. The window should land on that workspace. Super+1 through Super+6 stay the compositor's keys.
8. Open Spotlight with the bar search control. Look for Dolphin and Helium. Launch one. Focus should return to the desktop when Spotlight closes. At most 24 matches are shown.
9. Super+Space is still the compositor's launcher until you edit the bind yourself. See `docs/launcher-shortcut.md`.

## Settings

10. Open Settings from Spotlight and from the control center. There should be one window. Move and resize it with Hyprland's binds. Close it and open it again. The size should return.
11. Change dark, light, high contrast, text size, and a manual text color. The bar and the settings window should follow. Turn automatic text on over a png and confirm the text choice. Restart with `swiftshell stop` and `swiftshell start` and confirm the values are still there.
12. Set the bar height to 22 and to 52, then back to 28. Hide a module and move one. Restart and confirm the order.

## Wallpaper and displays

13. Wallpaper should show the crimson image, then a png you choose. Cover crops. Contain shows the whole picture. Point one output at a different file and confirm that output does not follow the slideshow.
14. Add two png paths to the slideshow. They should crossfade, and a failure should keep the current picture. A jpeg can be shown. It will not be sampled. This shell does not scan a folder.
15. Displays is a preview. Apply stays unavailable. Do not expect the layout to change. `~/.config/hypr` must stay unchanged.

## Services

16. Move the volume slider. It should change the default sink and unmute when raised. The microphone row appears when PipeWire has a default source. An application stream slider should move that application.
17. Start a player. Play, pause, next, and previous should match what the player allows. A tray icon should open its menu under the icon you clicked.
18. Network and brightness stay unavailable. There is no scan button and no password field. Bluetooth lists known devices and does not start a scan. Battery percent should match the session when UPower has a display device.
19. Lock, suspend, restart, and shut down ask a second time before `loginctl`.

## Notifications

20. The page should say SwiftShell is not the owner. Show preview should not post a desktop notification.
21. Own notifications asks again. After the second confirmation, if another program already owns the bus, the page should say the server is not running and that program should keep receiving notifications.
22. If SwiftShell does become the owner, dismiss a banner and confirm the sending application treats it as dismissed. A normal timeout should expire. Do not disturb keeps an ordinary notification out of the banner and still shows a critical one. Sounds are not played.

## Recovery

```sh
swiftshell stop
swiftshell rollback-settings
swiftshell doctor
```

`rollback-settings` restores only the SwiftShell backup. It does not restore Hyprland or Noctalia.

```sh
swiftshell deactivate
swiftshell uninstall
```

Add `--purge-settings` only when `~/.config/swiftshell` should be removed as well.
