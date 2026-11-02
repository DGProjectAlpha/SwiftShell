# Local roadmap progress

Source: owner-provided SwiftShell_Detailed_Roadmap.txt, planning baseline
2026-10-31, read from Downloads on 2026-11-01. This ledger records implementation
and evidence without modifying that external document.

- A: Displays transactions committed in 5f2409d and 3f31267. Native Settings
  redesign in 8048186, completion and mixed-scale evidence in d7f8182. Actual
  hotplug, comprehensive keyboard accessibility and wallpaper contrast acceptance
  remain on the manual checklist; no blanket completion claim.
- C0: complete for the current session. Owner-approved single-line Super+Space
  handoff was backed up, syntax-checked and loaded without config errors. Native
  Wayland chord tests passed open/repeat/Escape on both mixed-scale monitors.
  The persistent Lua command is in place; an actual reboot and physical human
  keypress remain unperformed. See docs/launcher-shortcut.md and docs/testing.md.
- B1: bar surface modes implemented and natively verified: transparent/solid/
  frosted, color/opacity, per-output inheritance and real layer blur without
  compositor rules. Existing transparent defaults preserved. Shared floater
  treatment and B2 context menus/ergonomics remain separate increments.
- Maintenance: bar updates retain module/workspace controls; the color picker
  is a themed in-window draft/commit popup. Native pointer tests passed on both
  scales, and the delegate-lifetime regression quantifies the removed churn.
- B2: clock seconds/date/style, icon-only or labeled Search, left/center/right
  grouping and per-output module visibility are implemented. Real right-click
  menus, keyboard dismissal and independently frosted calendar/control/module
  layers passed native interaction and blur comparisons on both scales. Shared
  shadows, bounded scrolling and theme contrast complete this bar/floater slice.
  Duplicate/queued settings saves have a native regression. See decision 0035.
- Next: C1/C2 Spotlight app grid/favorites/quick actions and richer search;
  D and later milestones remain separate work, not hidden inside this increment.

## Native desktop application increment (2026-11-02)

- B: Dedicated Audio/playback, Network & Devices and Power widgets replace the
  overflow menu. All published tray items render with native menus and live roles.
- C1/C2: Icon-grid Spotlight, saved opening view, Favorites/Recent, persistent drag
  ordering, local calculations/units, explicit URL/web fallback and icon actions.
- D: Effective binding viewer plus inhibited recording and owned apply/remove/undo.
  Existing opaque Lua callback bindings remain read-only; no reconstruction claim.
- E: Default Applications with verified XDG writes/undo, NetworkManager device
  controls, bounded Bluetooth discovery/actions and actual power profiles.
- G: Digital/analogue Clock, improved Calendar, countdown and stopwatch/laps with
  native restart tests. Alarms, world clocks and reminders remain future work.
- A/maintenance: Responsive Settings, workspace handle ordering, validated reads,
  cache-independent atomic preference writes, reversible desktop radius/blur/
  border controls and stable bar delegates. Real visibility checkbox/restart
  readback and actual tray menu/Clock-versus-date context tests passed.

At that checkpoint, workspace-layout rules, overview, performance dashboard,
clipboard, screenshot UI, release onboarding and physical hotplug/GPU-load acceptance
remained separate work. Subsequent progress is recorded below.


## Connected desktop increment (2026-11-02)

- Notifications: actual protocol ownership on this session, themed banners/drawer,
  retained actions, grouping, dismiss/snooze/Show now, DND/pause, per-app policy,
  duration/display/history settings and bounded session memory. Clock events and
  live bar activity share it. Sounds/images/inline reply remain future work.
- Overview: focused-display workspace grid with actual locally rendered window
  miniatures, blur, pointer/keyboard switching and a reversible guarded Alt+Tab
  handoff. Missing capture frames use a labeled fallback.
- Bar: per-display edges, content scaling, order/groups and visibility; actual edge
  wallpaper sampling and coalesced reservation updates. No monitor modes changed.
- Devices: authentication/progress/retry/cancel improvements and complete Bluetooth
  lists. Live connection/pairing side effects still need owner testing.
- Spotlight: native window switching and precise Settings links, local screenshot
  actions, optional bounded session clipboard history with explicit clip searches.
  Screenshot transport used owned pixels; real private clipboard data was not tested.

These changes are separate local commits on codex/live-debug, following the pending
PR baseline. They are not merged into main and do not claim the remaining roadmap
or release/GPU/hotplug gates are complete. See the dated native evidence in testing.
