# Repository cleanup — 2026-11-08

Maintenance baseline: `17632ca` on `main`. This pass preserves runtime behavior,
settings schemas, saved identifiers, assets, dependencies and integrations.
It does not change desktop configuration, monitor modes, services or ownership.

## Removed and consolidated

| Change | Evidence / preservation |
|---|---|
| Remove `shell/popovers/ControlCenterPanel.qml` | Only the old static/load tests referred to it. `PopoverHost`'s `controlPanel` already instantiates `AudioPanel`; its saved `control` identifier remains. The actual AudioPanel now receives the former geometry/load coverage. |
| Remove unused `bluetoothComponent` factory in SettingsWindow | `componentForCategory()` maps `bluetooth` to `networkComponent`. NetworkPage still embeds BluetoothPage; the category alias, settings and backend stay intact. |
| Remove eight unused imports | One unused Material JavaScript alias in AppearancePage; unused directory imports in ControlIndicator, ModuleStrip, SettingsToggle, ChoiceBox, PopoverSurface, NotificationsPage and ColorPicker. Explicit symbols and dynamic sources were checked; remaining transitive dependencies keep their own imports. |
| Move `shell/WorkspaceAudit.qml` to `tests/live/workspace-audit.qml` | This is a windowless, read-only diagnostic, not a shell surface. `scripts/test-workspaces-native.sh --snapshot` copies it into a temporary shell tree, preserving Quickshell's import boundary. The existing hidden save/restart mode stays available. No diagnostic is shipped in `shell/`. |
| Consolidate QML invocations in `scripts/check.sh` | One runner loop with the same explicit ordered suite list, flags, failure behavior and optional-module gates. No tests removed. |
| Delete `docs/ALPHA_AUDIT.md` and `docs/RELEASE_CANDIDATE.md` | Superseded cloud-era snapshots told agents that implemented blur, network, displays and shortcuts were unavailable. Git retains the original repair records. Current capability and recovery guides replace these instructions. |
| Replace fragmented/stale entry guidance | README, AGENTS, kickoff, architecture, compatibility, first-run, user guide and troubleshooting now agree with the runtime. The master specification keeps its product requirements and safety boundaries, but retires its one-time M4.0 assignment. |
| Separate evidence from instructions | Dated native results move from `docs/testing.md` into `docs/reports/native-validation.md`. Old branch checkout recipes, duplicated cloud-only milestone results and the BarLabel local-edit workaround are removed. Historical merge notes are labeled as history; current testing and remaining-work pages are concise. |

## Reference, dependency and asset audit

Reviewed all 126 remaining runtime QML documents, 36 logic modules and 19 Python
helpers through filename/type/import searches, singleton exports, dynamic Loader
sources, root IPC routing, native fixtures and install/package manifests. This is
a conservative reference audit, not a claim that static analysis proves all
possible runtime paths. No additional module or helper was proven obsolete.

The old-looking AudioSection, MediaSection, TraySection, BluetoothSection,
BatterySection and PowerSection remain used by actual Settings pages or panels.
SettingsPreview is the active Appearance preview. ControlIndicator intentionally
preserves a saved module identity. The legacy shortcut helper is still used for
existing installations; source-backed editing is not a reason to delete it.

The only regular binary assets are the bundled wallpaper and notification tone;
both have live references. `shell/assets/wallpapers` contains an intentional
checkout symlink, not a second PNG. User install and PKGBUILD replace that link
with the actual image; hermetic installer checks verify it. Optional dialog,
folder, multimedia and image-decoder boundaries remain. Qt Controls, Python,
protocol/input fixtures and all current scripts retain callers or test roles.
No dependency, persisted default, migration or configuration key was removed.

## Validation

- Baseline and final `scripts/check.sh`: exit 0; final static scan covers 126 QML
  files, 31 QML suites / 261 passed / 0 failed / 0 skipped. JavaScript, Python,
  persistence and temporary-home installer suites pass. Dialog/folder suites run
  on this host. The corrupt-image regression emits its expected libpng CRC warning.
- `git diff --check`: exit 0. Local Markdown target/anchor and unused-import scans
  pass. Runtime source no longer refers to the removed implementation.
- `python tests/live/settings-cold-start.py --live`: exit 0; fresh Quickshell
  processes write/read only temporary XDG preferences, without surfaces.
- `scripts/test-workspaces-native.sh --snapshot`: exit 0; native read-only snapshot
  on DP-1 scale 1 and HDMI-A-1 scale 1.25, including the named workspace. The
  existing hidden Settings save/restart mode also passed during this session.
- Temporary native compile audit: exit 0 for `shell.qml`, SettingsWindow and
  AudioPanel using actual Quickshell imports, without instantiating UI. The
  harness uses the same static imports/UseQApplication pragma and runs after
  initialization. It is not a mapped-window startup or focus/blur test.
- Read-only existing-shell IPC: both bars present, HDMI 28px / scalable text and
  DP 32px / native hinted text, content transform 1; no window busy/error state.
  No running-shell restart was required.

Interactive native tests were refused by the fullscreen safety preflight. No
new pointer, focus, mapped-window, blur, hotplug or display-mode acceptance is
claimed. An initial direct launch of the moved diagnostic failed because
Quickshell forbids imports outside its config root; the temporary-tree runner
resolves that and passed. The temporary entry-compile harness needed deferred
execution and static imports; failed harness attempts did not change production
code or the live session.

## Remaining debt and recovery

See [remaining work](../roadmap-progress.md): physical hotplug, lock/sleep/reboot,
GPU/resource profiling, real device authentication/pairing, clean-user installation,
Arch packaging/license and notification-history privacy remain acceptance/design
work. Large SettingsStore/static-check files and repeated native-fixture setup
remain candidates for separately scoped consolidation, with lifecycle coverage.

Revert the cleanup commits to restore removed sources/docs; Git history is intact.
No preference backup or desktop configuration restore is needed for these changes.
Stop only this checkout with `scripts/stop.sh`, or an installed copy with
`swiftshell stop`, if runtime recovery is ever necessary. Reinstallation is needed
only when the installed copy should receive the cleanup.
