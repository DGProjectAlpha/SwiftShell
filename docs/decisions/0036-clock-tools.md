# A useful clock application behind the bar time

Date: 2026-11-01. Clock and calendar increment following roadmap B2.

Clicking the time opens a compact clock application with four real tabs: Clock,
Calendar, Timer and Stopwatch. It opens on Clock rather than immediately showing
a month grid. Digital and analogue faces share Settings typography, neutral
controls and the existing host's rounded frosted material and shadow. The face
style is saved independently; 12/24-hour and seconds preferences use the same
SettingsStore values as the bar. There is no extra persistent shell process.

The calendar has selected-date feedback, real adjacent-month navigation,
locale-aware week labels, Today, week-number control and a Default Applications
integration. Open calendar launches the selected application without promising a
date-specific deep link. If no calendar application is available it is disabled
with a useful explanation. No account or calendar synchronization is implied.

Countdowns use a persisted absolute deadline, not a decrementing tick counter.
Pause saves remaining time and Resume creates a new deadline. Completion is
retained until dismissed/restarted and a fixed notify-send command delivers to
the existing notification owner, without taking the notification bus. Failure
is shown honestly. Preset and hours/minutes/seconds inputs all set the same real
timer. Closing the panel or restarting SwiftShell does not reset the countdown.

The stopwatch keeps accumulated elapsed time, its start timestamp and up to 50
cumulative laps. Pause/Resume, Lap and Reset are real state transitions. Display
updates are frequent only while a clock panel is visible; background deadline
checks are bounded. Stopwatch elapsed includes time spent asleep, and changes to
the system wall clock may affect elapsed values. This is not a laboratory timing
instrument. Alarms, snooze, reminders and world-clock management are separate
future work and are not advertised through fake controls.

State is stored atomically in SwiftShell's own XDG state directory as
clock-tools.json. Updates are coalesced, identical writes skipped, pending edits
retained during a save, and malformed/future/unreadable files protected against
overwrite. Missing data uses defaults. The service initializes at shell startup,
so an overdue restored timer finishes without requiring its panel to open.
The state contains only tool preferences/timestamps/laps, not notification text
or search history. Existing user-authored Hyprland files are untouched.

API references: Quickshell 0.3 [FileView](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/)
and [FileViewError](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileViewError/).
The native regression uses the actual FileView/Process APIs rather than a mock
save event. Base Controls remain styled with the shared Basic/theme controls.

Validation:

- `node tests/clock-tools.test.js`: deadline gaps/suspend, restart normalization,
  pause/resume, bounds, laps, malformed/future-version data and duration display.
- `tst_clock_tools.qml`: 7 passed, testing actual panel controls, face switching,
  calendar selection/navigation, timer transitions and stopwatch laps/reset. A
  date-only dependency regression proves second ticks retain the exact month
  model/delegates rather than rebuilding the calendar every second.
- `tst_shell_load.qml`: clock/calendar size and real padded-card assertions pass.
- `python3 tests/live/clock-tools.py --live`: real isolated Quickshell process
  writes running tools, exits, restarts and expires its original deadline;
  stopwatch/lap readback and notification argv pass. Its test-only notify-send
  captures fixed arguments without displaying a real notification or taking focus.
- `python3 tests/live/clock-panel.py --live`: both DP-1 and HDMI-A-1 passed real
  pointer face switching, calendar navigation, timer start/pause/resume/cancel,
  stopwatch/lap/pause/reset and actual keyboard Escape. Clicks are bounded to
  observed Hyprland layers, real rounded blur is active and the exact original
  clock state/focus/cursor are restored. No real timer notification was triggered.

The independent state file can be retained when reverting this source increment;
older SwiftShell ignores it. It is not a display/service configuration and has no
compositor rollback requirement. Tests use temporary XDG directories and leave
real timer state intact. Physical human visual acceptance, deliberate suspend/wake timing, system-clock
adjustments and notification-daemon-specific presentation remain unperformed.

Date and time now have independent bar targets: date opens Calendar, time opens
Clock. Rounded panel input excludes its shadow and the allowed focus-grab windows
include its bar, so switching views does not require an extra dismissed click.
Real-pointer context tests passed on both outputs. Timer/stopwatch state survives
view changes; calendar dates remain stable across clock ticks.
