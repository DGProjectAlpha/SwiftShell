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


### Notifications and Clock activity

The bell in each bar opens grouped notification history. Open a notification or
its action buttons, dismiss it, or snooze for 5 minutes, 15 minutes or an hour.
The Snoozed view offers Show now. Clear history removes archived notifications;
Do Not Disturb and Pause stop ordinary banners while keeping history. Critical
notifications can still interrupt. Settings → Notifications controls the display,
default duration, history limit and per-app Show/Quiet/Hide rules. History lasts
for the current shell session; app actions stop being available when the source
closes its notification. Images are shown when provided by the app. Reply-capable notifications offer Reply in the banner, then a focused field in the drawer; Send or Enter delivers it to the source app.

Timer and stopwatch activity appears next to the date/time while running or paused.
Click it to return to the relevant tool. Timer completion and stopwatch pause use
the notification drawer, with Open Clock actions that select the correct tab.

### Workspace overview and bar layout

Alt+Tab opens the focused display's workspace overview. Press it again to move the
selection, use arrow keys or Tab, then Enter to choose a desktop. Click a miniature
to focus its window; Escape or an empty-background click closes the overview.
Windows retain their compositor arrangement in each workspace card. A client that
cannot provide a preview gets a labeled fallback. Workspaces settings provides an
Open overview button and an Alt+Tab switch; turning the switch off restores the
original window-cycle binding. Custom/unknown bindings are preserved.

Settings → Top bar lets each display use Top, Bottom, Left or Right placement,
additional content scaling, widget visibility, grouping and order. Drag a handle
in Widget order to move an item; Escape cancels, and the list scrolls at its edges
while dragging. Alt J/K on a focused handle also reorders. Hover hints no longer
cover bar controls. Side bars use
vertical groups. Desktop monitor modes/scales are unchanged; bar scale is extra
control sizing. Select the same display to change its background. Use the all-screen
layout option to remove a display override.

### Spotlight desktop tools

Search an open window's title or app name, or type `windows`, then select it to
focus that window. Settings results open the matching control. Type `screenshot`
to capture an area or the focused display, or click the camera in the bar. Review
the image, then choose Copy PNG or Save as… for a local PNG file. Area selection
supports Escape to cancel; optional 3/5-second delays let you prepare the screen.
Capturing never overwrites the clipboard until you choose Copy PNG.
The Capture utility stays open when you click elsewhere or open Spotlight. Close
it with Close, or Escape while Capture has keyboard focus. To capture Spotlight
or another panel, set a 3/5-second delay, start Capture, then open the target panel.
Only Capture itself hides during acquisition and returns afterward; target panels
are left visible.

Clipboard history is off by default. Enable it in Settings → Spotlight Search to
remember text copied from then on. Type `clip` or `clip some text` to browse/search
it, then Enter to copy an item. History stays in memory, expires after 20 minutes,
and keeps at most 30 items. Turning it off or Clear history removes its entries.
The Clipboard bar widget opens searchable history with copy, individual removal
and Clear. Keep open gives it an independent movable/resizable floating window;
closing that window leaves recording unchanged. Window geometry is remembered,
but clipboard contents are never saved to disk.
Sensitive-format hints are respected, but text without a hint can include secrets;
leave history off when that is unsuitable. Open-window search can also be disabled.

The Performance bar widget shows CPU/GPU/memory percentages. Click it for recent
graphs, CPU/GPU temperatures, RAM usage and graphics memory. Missing sensors show
Not reported. Sampling is shared across monitors and stops when no bar or panel
uses it. Screenshot, Clipboard and Performance can each be hidden/reordered per
display in Settings → Top bar.

Terminal-based apps such as Cachy-Update open in the terminal selected in
Settings → Default Apps, with an installed supported terminal as fallback when
none is selected. Unsupported terminal launchers produce an error instead of
silently running an interactive program without a terminal.

Network & Devices now reports operations, recoverable errors and authentication
retry state. Password entry is masked with an optional Show control. Cancel targets
only a connection observed activating; a connection that already finished is left
alone. Bluetooth pairing uses the system's existing PIN/confirmation agent.


### Notification quiet hours, privacy and sound

Settings → Notifications now includes a local-time quiet-hours schedule with
weekday selection. An overnight schedule belongs to its start day: Friday
22:00–07:00 also covers Saturday morning. Matching start/end times mean all day
on the selected days. Manual DND and timed pauses work alongside the schedule.
Turning quiet mode off does not replay old banners. Critical banners can still
appear, but sounds remain silent while quiet mode is active. A default critical
notification stays visible until dismissed; an app's explicit timeout is honored.

Choose App name only to hide text, images and reply actions in banners. Open the
drawer to read and respond. Replies stay in memory, survive incoming updates and
are never logged or saved. A source that closes its notification can no longer
receive replies. Notifications with no reply capability show no reply field.

Notification sounds are optional and start off. Enable them, choose a volume and
use Preview sound to hear the short SwiftShell tone. The volume affects this tone,
not your system volume. DND, quiet hours, silent hints and rapid replacement updates
do not cause repeated sounds. Missing multimedia support or an audio output has a
clear unavailable state. Preview banner shows an actual temporary banner when
SwiftShell owns notifications, without adding history or sounding an alert.

### Weather

Open **Settings → Weather**, enable weather and search for a city, postal code or
address. Choose a result to show current conditions, hourly weather, seven daily
forecasts and air quality. Expand a day for its hourly outlook. Choose Celsius or
Fahrenheit and the update interval in Settings. **Top bar → Widgets → Weather**
controls its position and visibility independently on each display.

Weather starts off. Search sends the entered place to the named map provider;
**Use approximate location** performs an explicit IP-based lookup. Nothing looks
up your location automatically. Cached forecasts stay available offline and show
their age. Weather is an estimate rather than an emergency-alert service.

### Settings sections and appearance

Click a section heading to collapse or expand it. Settings remembers that choice;
a search temporarily opens matching sections. Dragging a slider highlights its
thumb and track and stays within the control. One drag is one Appearance Undo
step. **Appearance → Colors → Accent color** sets the shared control accent.
**Application windows → Keep windows opaque** prevents inactive videos and apps
from fading into the wallpaper when the desktop appearance integration is enabled.

Settings opens on the display where its button was clicked. Reopening keeps its
saved size and centers it on that display. Resize at the visible window edge or
corner. **Top bar → Peek in fullscreen** optionally reveals the bar when the
pointer pauses at its display edge; it starts off.

### Desktop shortcuts

**Settings → Shortcuts** shows your desktop's effective shortcuts. Choose **Change**
where available, press a new combination and apply it. Capture temporarily inhibits
global shortcuts so recording a key does not launch its action. The original action
stays the same, changes are saved to their original configuration, and **Undo change**
restores the preceding edit. Generated or ambiguous shortcuts stay visible but
cannot yet be edited individually. Existing 60% keyboard combinations are retained.

Selecting a terminal in **Default apps** also updates a safely recognized desktop
terminal shortcut. On the reference desktop, Super+Enter now follows Konsole.
**Undo** in the terminal row restores the preceding choice. Configurations which
cannot be safely linked explicitly show that the choice is used only by SwiftShell.

### Lock, sleep and switching desktops

Use the bar's Power panel or Spotlight's bottom actions. **Lock** signs out of this
desktop and returns to the same system login screen shown at boot. It closes your
apps; save work first. **Log out** has the same destination. Select the action twice
to confirm, or Escape to cancel.

**Suspend** also ends this desktop session, then sleeps the PC. On wake, use the
normal system login screen. A logind delay inhibitor coordinates accepted sleep
with ending this session; denied sleep leaves the desktop open. SwiftShell does
not launch Hyprlock or use a separate unlock password. Restart and Shut down retain
their existing confirmation and system routes. Errors appear in Power or Spotlight.
