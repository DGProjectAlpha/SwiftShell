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
