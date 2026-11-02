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

## Native Settings window

Drag the title bar to move Settings and its edges or corners to resize it.
Double-click the title bar or use □ to maximize/restore. − minimizes Settings;
open Settings again to bring it back. × closes it. Normal size and position are
remembered. The sidebar contains every page, including Workspaces between
Displays and Shortcuts. Search also opens matching pages.

Appearance controls surface transparency, compositor blur, corner radius and
soft shadows. Unavailable effects are disabled. Displays edits are staged until
Apply; use Keep before the countdown expires, or Revert. An independent watchdog
restores an unconfirmed layout even if Settings or SwiftShell exits. Kept layouts
can be restored explicitly without changing your Hyprland Lua files.

## Bar background

In Top bar → Background, choose Transparent, Solid or Frosted. Color and opacity
change the painted surface. Frosted uses actual compositor blur when available;
otherwise SwiftShell shows a readable solid fallback. The optional readability
gradient remains independent in Appearance. Corner radius follows Appearance.

Apply to All screens changes the shared background. To customize one output,
choose its monitor name and turn off Use all-screen background. Turn that switch
back on to inherit again. Reset background restores the shared transparent style;
individual overrides remain until you return those monitors to inheritance.

## Choosing colors

Color selection stays inside Settings and follows its theme. Drag the color
square and hue strip, select a neutral swatch, or enter a six-digit hex color.
Use color applies your choice; Cancel, Escape or clicking outside discards it.
Draft changes do not affect your bar or wallpaper. Opacity is controlled separately.

### Bar layout and clock

Right-click a bar to choose modules for that monitor, inherit the global choices,
or open Bar settings. Bar settings also provides per-monitor visibility, compact
left/center/right placement, module order, optional Search text, 12/24-hour time,
seconds and date styles. Reset positions restores the arrangement derived from
module order. Calendar and Control Center share the Settings material; Escape or
an outside click closes them. Opening Settings or Spotlight dismisses bar panels.

### Clock and dedicated bar widgets

Click the **date** for Calendar or the **time** for Clock. Clock offers digital and
analogue faces, countdown timers, and a stopwatch with laps. Timers keep their
remaining time across panel closure, sleep and restart. The calendar opens your
chosen calendar application when one is installed; it does not claim unsupported
date-specific navigation. Alarms, world clocks and reminders are future features.

The former three-dot menu is now **Audio**. Audio includes device/volume controls
and playback; the activity animation follows playing state and respects Reduced
motion. **Network & Devices** and **Power** have their own widgets. Right-click
blank bar space to choose visible widgets for that monitor. Right-click a tray
application to open that application's menu; the bar menu no longer intercepts it.
All published tray items appear. An installed application that is not running or
not publishing an icon will not appear merely because it has a background process.

### Spotlight Search

Super+Space opens Spotlight. Use All apps, Favorites or Recent; choose the default
opening view in **Settings → Spotlight Search**. Right-click an app or use Ctrl+D
to add/remove a favorite. In Favorites, drag tiles to arrange them; Alt+Shift+H/L
also moves a selected favorite. Ordering and the default view survive restart.

Type an app/setting, calculation such as `2+2`, common unit conversion, or URL.
When there is no local result, the labeled web result opens only after Enter or a
click. There are no automatic online suggestions or network requests while typing.
The bottom icon strip provides Settings and confirmed session actions.

### Desktop appearance and device settings

**Appearance → Window borders** switches active and inactive application borders
off or changes their width. Corner radius also controls normal desktop windows;
individual application rules may override it. Blur strength uses the compositor's
shared blur profile, including other blurred desktop surfaces. SwiftShell writes
only its own recovery state, never your Lua. Restore desktop appearance returns
owned options to their recorded originals.

Appearance reflows into two columns in a wide Settings window and stacks on a
narrow window. Workspaces provides a discovered screen selector and draggable
indicator handles. Removing an indicator does not close applications or destroy
that compositor workspace.

**Network & Devices** combines connections and Bluetooth. It offers actual device,
radio, saved connection, discovery and pairing actions where supported. Enterprise
Wi-Fi needs an existing profile; pairing may require your system's pairing dialog.
**Power** exposes the power modes actually provided by your computer.

**Default apps** selects installed applications using standard associations where
available. Terminal/calendar shell preferences are used by SwiftShell; existing
custom shortcuts that name a program are not rewritten. **Shortcuts** shows your
active desktop bindings and lets you record/apply/remove managed actions with
collision checks and Undo. Existing opaque Lua actions remain read-only.
