# Using SwiftShell

SwiftShell provides bars, Spotlight, native Settings, wallpaper and optional
notifications/tools. Hyprland owns application windows; existing shells and
services are not stopped automatically. This is an alpha with
[documented capability limits](capability-matrix.md).

For installation and scoped start/stop use [install](install.md). Development
uses `scripts/launch.sh` and `scripts/stop.sh`. User preferences are stored under
`$XDG_CONFIG_HOME/swiftshell`; existing preferences survive installation.
Use [first run](first-run.md) for the smoke checklist and
[troubleshooting](troubleshooting.md) for recovery.

Open Settings from Spotlight or a bar menu. Every page has Collapse all / Expand
all below Search; search temporarily expands matching sections. Collapse all
clears an active search. Settings validates and atomically saves preferences.
Wallpaper supports image/folder selection, slideshow and crop-aware contrast;
optional module/decoder absence has an explicit fallback. Network/Bluetooth,
audio/media/tray and power controls follow actual backend capability.

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

Choose the display once in **Apply to** at the top of the Top bar page. Background
controls immediately customize that display; no inheritance switch is required.
**All displays** updates the edited background property on every bar, preserving
unrelated colors, styles or opacity. **Use shared settings for this display**
removes that display’s bar customizations and follows the shared settings again.

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
module order. Calendar and the dedicated panels share the Settings material; Escape or
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

Ordinary searches prioritize matching applications: short names such as `dis`
find Discord before Settings or open-window suggestions. Settings, window and web
results provide fallbacks when no app matches. Calculator/conversion results and
explicit `clip`, `window` and `capture` commands retain their direct behavior.
App names support partial/fuzzy matching; descriptions and categories require
literal matches to avoid unrelated suggestions.

After an explicit shortcut handoff, Super+Space opens Spotlight. Use All apps, Favorites or Recent; choose the default
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
collision checks and Undo. Existing opaque Lua actions remain read-only unless a supported source-backed edit can preserve them.


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

When its optional shortcut integration is enabled, Alt+Tab opens the focused display's workspace overview. Press it again to move the
selection, use arrow keys or Tab, then Enter to choose a desktop. Click a miniature
to focus its window; Escape or an empty-background click closes the overview.
Windows retain their compositor arrangement in each workspace card. A client that
cannot provide a preview gets a labeled fallback. Workspaces settings provides an
Open overview button and an Alt+Tab switch; turning the switch off restores the
original window-cycle binding. Custom/unknown bindings are preserved.

Settings → Top bar has one **Apply to** selector for size, edge, reserved space,
background, widgets, clock labels and fullscreen reveal. Select a display to
change only its bar. **Bar size** resizes its text, icons and reserved strip
together, without changing desktop resolution or scale. **All displays** applies
the setting you edit to every bar, including bars with custom values. When sizes
or edges differ, those controls show **Mixed**. **Where bars appear** is a separate,
explicitly global control for All, Focused, Primary or one specific display.

Drag a handle
in Widget order to move an item; Escape cancels, and the list scrolls at its edges
while dragging. Alt J/K on a focused handle also reorders. Hover hints no longer
cover bar controls. Side bars use vertical groups. Widget visibility and grouping
have one control each; Focused title is managed in the widget list.

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
pointer pauses at its display edge; it starts off. While hidden, the bar passes
all clicks through to the fullscreen application. Its controls become clickable
when the peek is visible, and stop accepting clicks when it hides again.

### Desktop shortcuts

**Settings → Shortcuts** shows your desktop's effective shortcuts. Choose **Change**
where available, press a new combination and apply it. Capture temporarily inhibits
global shortcuts so recording a key does not launch its action. The original action
stays the same, changes are saved to their original configuration, and **Undo change**
restores the preceding edit. Generated or ambiguous shortcuts stay visible but
cannot yet be edited individually. Existing 60% keyboard combinations are retained.

Selecting a terminal in **Default apps** also updates a safely recognized desktop
terminal shortcut. **Undo** in the terminal row restores the preceding choice. Configurations which
cannot be safely linked explicitly show that the choice is used only by SwiftShell.

### Lock, sleep and switching desktops

Use the bar's Power panel or Spotlight's bottom actions. **Lock** uses Hyprlock
and keeps your apps running. Use your normal Linux login password to unlock.
**Suspend** locks first, waits for the compositor to confirm the secure lock, then
sleeps. Wake returns to the lock screen with your apps preserved. **Log out** closes
your apps and returns to the system login screen, where you can choose a desktop.
Suspend, Log out, Restart and Shut down require confirmation.

To check the actual Hyprlock PAM profile without locking the desktop, run
`python scripts/test-hyprlock-auth.py` locally in this checkout. Enter your password
only in that local diagnostic dialog. It makes one authentication attempt and
reports only a success flag/PAM code; no password is accepted in command arguments,
saved or printed. A failure leaves the desktop accessible. Do not repeatedly retry
failed authentication, since the system's normal failed-attempt policy still applies.
