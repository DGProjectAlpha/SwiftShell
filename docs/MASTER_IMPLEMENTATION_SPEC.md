# SwiftShell: Master Product and Implementation Specification

**Version:** 1.0 | **Date:** October 30, 2026  
**Intended repository location:** `docs/MASTER_IMPLEMENTATION_SPEC.md`  
**Target:** Quickshell / Qt 6 / Hyprland, initially Arch Linux and CachyOS  
**Audience:** Cursor autonomous coding agent and reviewers  
**Status:** Long-term instructions for every milestone after the in-flight M3.2 Spotlight / monitor-autodetection work.

> **The product:** A fully integrated, elegant desktop shell that a normal user installs with one guided command, without editing JSON, Lua, or twelve unrelated utilities. The UI must feel native and unified: transparent top bar, centered Spotlight, a genuinely floating Settings window, first-class wallpaper/slideshow, responsive color adaptation, reliable system controls and notifications, and polished individually frosted panels.
>
> **The aesthetic:** iOS 7-era translucent restraint refined for modern desktops. Near-monochrome, elegant, crisp, understated. Soft Gaussian-looking backdrop blur *when actually supported*. Rounded floating surfaces, no outlines, no permanent colored bar, no oversized Material widgets, no bounce or spring animations.
>
> **The engineering rule:** Working behavior first. Do not fake a feature, invent an API, claim visual testing in a headless container, or change a user's working Hyprland/Noctalia session without explicit authorization.

---

## 0. Mandatory instructions to Cursor: read this before coding

This document is a **multi-PR build specification, not a request for one gigantic PR**. Each increment must be a working vertical slice with tests, documentation, migration and an honest hardware-verification status. Never rush through all milestones to create the appearance of progress.

### 0.1 Working sequence at the start of EVERY PR

1. Read `README.md`, `AGENTS.md`, this file, `docs/compatibility.md`, `docs/architecture.md`, `docs/testing.md`, `docs/install.md`, and relevant decision records. Read the *current* files, not cached assumptions.
2. Inspect `origin/main`, open PRs, relevant changes and migrations. The known baseline at specification creation was merged PR #9 (M3 stabilization), plus the default wallpaper at `assets/wallpapers/swiftshell-default-crimson.png`. M3.2 was in progress. **Never assume these hashes or code paths are still current.**
3. Identify the smallest user-visible behavior that can be fully implemented and verified. List which modules, system services and external APIs it needs.
4. Inspect available Quickshell / Qt / Hyprland versions and official API contracts. If cloud has no actual Wayland session, do not claim you inspected target graphics behavior. Mark unknowns.
5. Implement functionality, error paths and regressions in one reviewable branch. Do not edit other shells, active config, system services or installed packages merely to make tests pass.
6. Run static, pure-logic, QML load and install tests, plus feature-specific tests. Report command, result and skipped checks.
7. Audit the actual loaded component tree, the user's Lua-dispatch constraints, focus lifecycle, mixed DPI, and persistence.
8. Finish with a PR description including exact functional changes, files, test evidence, **not-yet-run live hardware tests**, limitations and a safe rollback plan.
9. Wait for explicit merge/activation as necessary. If the user is unavailable, continue only with repo-contained, nondestructive implementation and documented test plans. Do not interpret silence as permission to take over live services.
10. Keep this document and other repo docs current when an accepted implementation establishes a new invariant.

### 0.2 Absolute safety boundaries

- No destructive commands: no blanket `pkill quickshell`, `killall`, `git reset --hard`, `git clean -fd`, force push, surprise service disable or system-wide display mutation.
- Preserve Noctalia. On reference hardware it is the **`noctalia` executable**, not the `qs` process belonging to SwiftShell. Stop SwiftShell by its own `scripts/stop.sh` or selected Quickshell config path.
- Never directly rewrite `~/.config/hypr/config/binds.lua`, `monitors.lua`, `decorations.lua`, or arbitrary hand-authored Lua. Read or preview only without authorization. Any future managed integration must be opt-in, backed up, syntax-validated, transactionally applied and reversible.
- No default shortcut reassignment, autostart change, notification service takeover or compositor blur rule insertion without authorization.
- No arbitrary commands constructed from Spotlight search text, network names or image filenames; prefer typed APIs and validated arguments.
- No user passwords, Wi-Fi credentials, notification bodies, local document contents or private image pixels in logs or cloud calls.
- No claims of real blur, monitor positioning, window movement, input focus or GPU performance based solely on offscreen QML mocks.

### 0.3 Definition of done for every feature

A feature is **complete** only when: (1) its GUI is operable by pointer and keyboard; (2) it reaches a real, verified backend; (3) displayed values represent actual state; (4) changes persist appropriately or are explicitly temporary; (5) errors and unsupported capabilities have truthful UI; (6) regression tests would detect its known failure modes; (7) focus, close, startup and shutdown are safe; and (8) required live-machine tests are performed or clearly marked as pending. A functioning source file or a rendered mockup does not equal a complete feature.

### 0.4 Gates

- **Gate A: M3.2.** Focused-monitor Spotlight, safe explicit Super+Space handoff, arbitrary monitor and workspace names, no invalid defaults, runtime validation.
- **Gate B: Native Settings.** Real floating/movable/resizable window, navigation, persistence, search, working controls for currently available features; one theme foundation.
- **Gate C: Appearance/wallpaper.** Native wallpaper plus GUI image/folder chooser, slideshow, adaptive contrast and manual tint overrides; actual compositor blur capability proven or clearly unsupported.
- **Gate D: Display and keybinds.** Real monitor drag/drop with safe keep/revert and a controlled shortcut backend, not direct Lua replacement.
- **Gate E: OS integration.** Audio/network/Bluetooth/media/brightness/tray/power and notifications wired to live services.
- **Gate F: Release.** One-script guided install, optional reversible takeover, all relevant hardware QA, uninstall and documentation.

---

## 1. Reality check: what is built, and what failed before

**Currently present in repo (not all live-verified):** Quickshell root; top bar; multi-output discovery base; workspace indicators and Lua-compatible switching; clock/calendar; basic control-center popover; working PipeWire volume slice; Spotlight launcher/model, desktop entries and themed icons; atomic JSON SettingsStore; developer launch/stop scripts; installer; test stubs and a default crimson wallpaper PNG. Native Settings application, wallpaper renderer, true backdrop blur, monitor-layout GUI, service-rich controls and a notification daemon do not yet exist as complete features.

**Known defects and permanent lessons:**

| Previous failure | Permanent prevention |
| --- | --- |
| `QtObject` directly contained unnamed children and failed to load | Correct parent types (`Scope`, `Singleton`, `Item`, etc.); QML root instantiation test |
| `implicitWidth` / `implicitHeight` assigned on `Column`, `Loader`, `Text` and similar read-only types | Understand Qt 6 inheritance; use an `Item` wrapper when explicit implicit sizing is required; retain static regression and real QML load tests |
| `BarLabel is not a type` from absent import | Explicit local imports and transitive component resolution; fail build when new project type is not imported |
| `Qt.rgba(255,255,255,...)` | Normalize byte colors to 0.0–1.0 and test values |
| Lua dispatch received legacy `workspace 5`, causing a parser error | Preserve working `hl.dsp.focus({ workspace = N })` dispatch on Lua builds; verify backend before using legacy syntax |
| Launcher indexed empty desktop entries at startup | Handle asynchronous `DesktopEntries.applicationsChanged`; index full catalog, not visible first 12 rows |
| Application theme icons degraded to letters | Use supported `Quickshell.iconPath` lookup, with legitimate monogram fallback |
| Bar reservation did not return after overlay mode | Explicit `ExclusionMode.Normal` when enabling exclusive zone, test false→true and scale behavior |
| Hidden fullscreen overlay could hold keyboard | Release focus/grab before hiding; test Escape, outside click, monitor loss, repeated open, stop |
| Prototype hardcoded HDMI-A-1 and workspace IDs 4–6 | Discover monitors and workspaces dynamically; local preferences may preserve that reference layout but universal defaults never embed it |
| Settings contained a `panelBlur` preference but only drew a scrim | Distinguish **real compositor backdrop blur** from alpha/transparency and wallpaper-only simulation |
| Cloud checks passed while on-device QML failed | Test entire loaded QML root, use accurate stubs, keep real hardware gate distinct |

**Important test-maintenance requirement:** Existing static/logic tests previously asserted 28px bar height, HDMI-A-1 and fixed workspaces. When those become configurable/dynamic, update tests to assert **the new intended invariant**, not the old prototype literal. Never make a feature fail because the tests canonized temporary hardware assumptions.

**Existing technical constraints:** Quickshell 0.2/0.3 API differences, Qt 6 property restrictions, Hyprland Lua mode, Wayland surface roles, fractional scaling, service ownership and Noctalia isolation must drive design. The repo's documentation has some stale M1 text; correct it as milestones land.

---

## 2. Immutable visual and interaction language

### 2.1 Product style

- **Top bar:** Fully transparent. Text and icons float over the desktop. An optional **separate-looking, soft top-edge gradient** may improve readability, with color/intensity/height adjustable. Never use a visible full-width painted bar, outline, bottom rule or permanent pill.
- **Floating UI:** Spotlight, Settings, control center, popovers and notifications should appear as distinct softly blurred rounded surfaces with low-contrast shadows, not nested cards. The corners must clip correctly; a rectangular blur behind a rounded rectangle is not acceptable.
- **Color:** Default grayscale, soft off-white/charcoal text. A subdued wallpaper-derived tint may affect the frost. Avoid saturating the UI to match a crimson wallpaper; the accent is restrained. Manual override mode must let users choose foreground, icons, gradient, surface tint and background independent of each other.
- **Typography:** Crisp system font with carefully selected weights and hierarchy. Prefer clear size/weight contrast over borders. Real icons should look coherent at 1x, 1.5x and 2x.
- **Layout:** Compact, aligned to a shared spacing scale, readable labels, consistent baselines, no giant padded Material buttons or rows. User-adjustable density.
- **Motion:** 100–160 ms subtle fades/short translations for entrance, 80–120 ms for exit. **No bounces, wavy settling or rubber-band animations.** Respect reduced motion and allow animation speed/off.
- **Focus:** Clear keyboard focus state without a heavy outline; accessible subtle highlight/glow/underline is valid. Do not sacrifice keyboard usability to pure aesthetic minimalism.
- **Contrast:** Aim for WCAG-like readable contrast for small text on *effective frosted background*, using a stronger scrim when required. Automatic selection should not flicker on image transitions.

### 2.2 Shared design tokens (initial guidance, adjustable)

All sizes are **logical pixels**. Never manually multiply by screen devicePixelRatio in QML when compositor/Qt already handles scaling.

| Token | Suggested default / relationship |
| --- | --- |
| Bar height | 28 logical px; GUI adjustable approx 22–52 px and safe accessibility mode |
| Bar font | About 0.42 × bar height, clamped to sensible readable range (10–22px); separate optional font scale |
| Bar icons | About 0.58 × bar height, clamped 12–30px; optional independent icon scale |
| Bar gap / inset | Derived from bar size, starting ~12 / 10px, not copied literals across files |
| Floating surface radius | Around 10–14px; adjustable, but not cartoonishly pill-shaped |
| Settings preferred window | Around 900 × 620 logical px; responsive minimum around 640 × 440, with scroll and adaptive navigation |
| Spotlight search width | Target 440–520 logical px max, centered on active/focused output |
| Settings control row | Approx 32–38px compact, adjustable for accessibility |
| Default focus transition | 70–100ms or none with reduced motion |
| Gradients/shadows | Low intensity; avoid hard edges and over-wide opaque panels |

Design tokens **must be centralized** in Theme and shared components. Compute consistent derived sizes for each bar-height update; don't independently hardcode font, icon, reserved zone and panel offsets. Restore defaults section by section.

### 2.3 Material/blur stack

1. Wallpaper/background.
2. **Compositor blur of the actual scene behind**, only when tested and supported.
3. Transparent material tint/scrim, independently adjustable, to make text readable.
4. Foreground text/icons with automatic or manual contrast.
5. Optional subtle shadow/focus treatment.

**Critical distinction:** QML `color: Qt.rgba(..., 0.7)` is translucency, not Gaussian blur. A blur of a pre-rendered wallpaper image is not the same as blurring applications behind a settings window. A visible effect must be labeled accurately. Do not implement a screenshot permission workflow merely to make the UI sample the user's other windows.

### 2.4 Accessibility / interaction

Every page and control must work with mouse and keyboard. Avoid dependence on arrow keys on a 60% keyboard; support Tab / Shift+Tab / Enter / Escape and optionally Alt+J/K for lists where text input stays unaffected. Include focus states, sensible hit areas, reduced motion, disabled explanations, usable font scaling and high-contrast fallback. Don't intercept typing inside text fields. Never leave an invisible full-screen input barrier after closing overlays.

---

## 3. Architecture to build, not a pile of utilities

### 3.1 Module ownership

| Location / service | Responsibilities |
| --- | --- |
| `shell/settings/` | Main Settings window, navigation/search, pages and previews |
| `shell/components/` | Shared label, button, toggle, slider, color input, row, group, dialog, tooltip, error, progress, focus and scroll primitives |
| `shell/themes/` | Design tokens, color policy, readable contrast, inheritance, material capability, animation policy |
| `shell/background/` | Per-output wallpaper surfaces, transitions, slideshow and image source control |
| `shell/services/SettingsStore.qml` (evolve) | Versioned user preferences, validation, migration, atomic write and change notifications |
| `shell/services/MonitorService` / Hyprland adapter | Live outputs, modes, topology, focused monitor, staging/rollback |
| `shell/services/WallpaperService` | Image/file/folder choice, per-output state, slideshow and cache |
| `shell/services/ColorAnalysisService` | Regional wallpaper sampling, foreground selection, palette smoothing |
| `shell/services/AudioService`, `NetworkService`, `BluetoothService`, `MediaService`, `NotificationsService` | Single source of truth for each OS integration, capability and error state |
| `shell/services/KeyboardShortcutsService` | Read bindings, detect conflicts, managed opt-in integration, backups |
| `shell/services/CapabilityService` | Version/capability detection; no fake support switches |
| `shell/logic/` | Pure validation, geometry, palette decisions, conflict logic and math |
| `helpers/` (only if unavoidable) | Small, typed, tested and packaged helper for missing native API, e.g. image statistics or crash-resilient display rollback |
| `tests/`, `scripts/`, `packaging/` | Unit/QML/live tests, installer, update, safe activation, rollback |

Do **not** reimplement NetworkManager, PipeWire, BlueZ, MPRIS or Hyprland. Integrate their supported IPC/APIs behind one native GUI; that's how the product can be self-contained to a user without being an unmaintainable second operating system.

### 3.2 Settings data model

Move toward a versioned schema (e.g. v2 after migration) with domains: `general`, `appearance`, `bar`, `wallpaper`, `launcher`, `displays`, `shortcuts`, `audio`, `network`, `bluetooth`, `media`, `notifications`, `power`, `integrations`. Maintain compatibility with the existing `clock`, `bar`, `appearance` and `launcher` keys. A version number by itself is not a migration.

**Persistence rules:** atomic JSON writes; back up malformed/older files; schema validation; preserve valid existing values; preserve unknown extension keys when possible (current JsonAdapter may discard unknown keys on rewrite, so audit before upgrade); do not overwrite file on failed load; use XDG directories, not developer-specific paths. Distinguish persisted *preference* from live OS *observed state*. Don't save sensitive secrets in JSON. Sliders may preview continuously but persist only on release/debounce, not every render frame. Manual colors survive an auto-mode toggle. Include per-page Reset, global Reset with confirmation, export/import, schema migration tests and clear errors.

**Service rules:** each page observes central service state, never writes arbitrary scripts itself. Services expose `available`, `reasonUnavailable`, `busy`, `error`, `currentState`, `set...` methods with clear successful/failed responses. When a device disappears, UI updates. If backend is absent, control becomes disabled with explanation, not pretend-responsive.

### 3.3 Version and compatibility discipline

- Verify Quickshell version and available QML modules on the target; Qt/Quickshell APIs vary by release. If a QML attached type is not available in old version, **referencing it unconditionally may prevent the entire shell from parsing**. Gate by separate compatible components or supported version boundary, not a JavaScript `if` after QML parse.
- `QtObject` has no default `data` slot. Qt's `Column`/`Row`/`Loader`/`Text` and other types have read-only implicit sizes. Check actual root types before implementing layout. Use `Item` wrappers where necessary.
- Proper local `import` for every project QML component. Confirm from real shell entry, not just isolated tests.
- Native Settings **must be a real Wayland toplevel, movable/resizable by Hyprland**, not a nonmovable layer-shell `PanelWindow` merely decorated to look like one. Investigate Quickshell's suitable window support at installed version. If required, a lightweight Settings executable/front end packaged **as part of SwiftShell** sharing the model/theme is better than a fake layer surface. Do not spawn another always-on shell service.
- On Wayland, arbitrary window coordinates are compositor-controlled. Don't assert setting `x,y` centers a native toplevel if compositor ignores them. Verify focus/centering using supported Hyprland rules/APIs with permission and safe fallback.
- Qt Quick Dialogs `FileDialog` / `FolderDialog` exist on relevant Qt 6 builds, but native portal fallback and supported properties differ. Check installed Qt version and validate file URLs.
- The reference machine uses Hyprland Lua config. Legacy `hyprctl dispatch workspace 5` semantics are NOT equivalent to the user's dispatch wrapper. Preserve verified Lua activation, don't write invalid command syntax.

---

## 4. Native Settings application: exact UX and feature catalog

**This is the highest-priority major feature after M3.2.** A floating, normal, independent desktop window. A polished first-party Settings experience, not a reskinned JSON editor or control-center popup. Implement it in slices, but plan the architecture for every category below. Never fill incomplete pages with live-looking fake switches.

### 4.1 Window and navigation requirements

- **Launch:** From Spotlight search/action, top bar, control center, a desktop entry, and eventually Super+Z after the user opts into managed shortcuts. Repeat launch should focus existing Settings window rather than creating 20 copies.
- **Window:** Normal Wayland toplevel, compositor movable/resizable/focusable. Default approximate dimensions 900×620 logical px, responsive to smaller displays; safe minimum and sensible default position on focused monitor. Save/restore window size and last active category where possible. No invisible keyboard grab when closed.
- **Surface:** Glass/frost aesthetic with genuine compositor backdrop blur when demonstrated. Graceful translucent scrim fallback if unavailable. Rounded corners, faint shadow, no visible outlines or bright panel background. Sidebar and main content share one coherent visual material, with only subtle differentiation.
- **Sidebar:** Search, Appearance, Top Bar, Wallpaper, Displays, Keyboard & Shortcuts, Spotlight, Audio, Network, Bluetooth, Media, Notifications, Power & Battery, General, About & Diagnostics. Group related entries. Sidebar may collapse into compact category picker on narrower widths.
- **Main pane:** Clear category title, short functional descriptions, section groupings, adjustable controls with units, a compact preview where helpful, current-value status and reset link. No sprawling marketing cards or separate modal for every checkbox.
- **Search within Settings:** Index real settings labels, keywords and category context. Results navigate to the exact control and scroll into view. Disabled features may be discoverable but show why unavailable. Search must be fully local and private.
- **Interactions:** Keyboard Tab/Shift+Tab, Enter/Space, Escape/back, mouse drag/sliders/scroll, focus and hover states. No arrow-key-only navigation. Keyboard focus remains within usable window scope, but native window switching is unharmed. Validate clipping at minimum window size.
- **State:** Show pending changes vs saved values; use live previews for safe appearance and bar changes; destructive operations use explicit Apply/Keep/Revert. Support section/global reset and offline-recovery export.
- **Error UX:** Missing service, failed apply, permission denial, unsupported mode and disconnected monitor have coherent, nontechnical but precise messages plus a safe recovery action. Don't show a fake enabled toggle if only a config preference was saved.

### 4.2 Appearance page: exhaustive controls

**Themes & global policy**
- Theme mode: Auto (wallpaper/system policy), Dark, Light. Define exactly what Auto observes. Manual retains earlier choices when reenabled.
- Wallpaper-derived foreground: on/off, regional sensitivity, contrast-strength (within readable bounds), optional accent extraction, saturation limiter.
- Material profiles: Clear, Frosted (default), Subdued, High Contrast, Custom. Profile changes preview instantly and never overwrite hidden manual values without explicit Reset.
- Optional appearance preset import/export with sanitized file format.

**Independent manual color controls**
- Primary text and icons; secondary text; disabled text; active/selected; focus; hover; control fill; surface frost tint; gradient tint; shadow tint; optional accent. Use a native color picker with hex/RGB/A entry and valid preview, contrast warning and reset for each.
- Per-surface inheritance: global default applies to Bar, Settings, Spotlight, Control Center, Popovers and Notifications; user can override any surface without creating contradictory toggles. Provide “Use global” and “Use automatic” in correct order.
- Dark and light overrides stored separately where useful. Auto-off restores previous manual palette.

**Material controls**
- Backdrop blur enabled when verified supported; blur strength/radius if backend genuinely permits scope; otherwise show explanation, not functional-looking dead slider.
- Material tint/scrim alpha, color, frost saturation/vibrancy if supported, optional subtle noise (off by default), shadow softness/opacity, corner radius, corner smoothing if possible, internal padding.
- Optional global vs per-surface blur. Explicitly disclose if underlying Hyprland blur settings are global; don't pretend independent radius if backend lacks it.
- Accessibility: high contrast, minimum readable contrast enforcement or warning, reduced transparency, reduce motion.

**Text & density**
- UI font family picker limited to installed fonts with fallback, base font size, line height if feasible, weight, overall UI scale and compact/comfortable density.
- Icon scale, module label scale, tooltips, control row height, panel spacing, popover padding.
- Animation enabled/speed/duration/fade preference. Absolutely no spring or bounce animations.

**Top-edge gradient**
- On/off independent of text adaptation.
- Auto tint from regional wallpaper analysis vs Manual gradient tint/color.
- Opacity, height/falloff curve, gradient top intensity, smoothing/feather. Does not create a painted rectangular bar.
- Per-output overrides when multiple displays show substantially different wallpapers.

### 4.3 Top Bar page: exhaustive controls and dynamic scaling

**Geometry and monitor policy**
- Bar height slider + numeric input. Initial 28 logical px; proposed safe normal range 22–52 with accessible text scale option. Underlying implementation must derive **font size, icon size, hit areas, workspace indicators, gaps, insets and reserved work area** consistently from bar height; optional separate icon/text scale if user wants.
- Position top/bottom if backend supports, select one monitor/all monitors/auto-follow focused; otherwise explicitly mark unsupported positions. Do not hardcode monitor names.
- Reserve screen space vs overlay, hide/reveal on fullscreen, optional auto-hide when robust, margin, horizontal inset, vertical alignment, module gap, row layout.
- Restore defaults for sizing without breaking a maximized window. Preview should not require manual shell restart.

**Modules, order and visibility**
- Reorder visible modules with drag/drop plus accessible keyboard move controls; show a live preview. User can add/remove from supported types: Workspace, Focused app title, Search, Clock/Calendar, Tray, Network, Bluetooth, Volume, Media, Battery, Notifications, System status (only if real source), Power menu.
- Per-module show/hide, label/icon mode, priority when space is tight, overflow handling, optional compactness and conditional visibility. No module should clip or overlap another on 1080p, 1440p, or small laptop screen.
- Workspace indicators: show current monitor's workspaces from Hyprland state, optionally include empty known slots; auto-detect instead of `[4,5,6]`; auto/order/manual profile with user-configured IDs only if desired. Preserve switching correctness in Lua.
- Clock: 12/24h, seconds on/off with reasonable update frequency, date format, locale, timezone display, calendar first weekday, ISO week numbers, optional alternate date.
- Focused app: show/hide, abbreviation or full title, max width, fade/truncate strategy, empty/privileged title handling.
- Audio/tray/network/battery: module-specific icon/label rules and click/scroll actions consistent with actual services.

**Interactions and performance**
- Click or scroll to workspace only when a real action exists; hover tooltips, disable tooltip if user desires, mouse target scale, no excessive polling.
- Exclusive zone update works after overlay→reserved toggles and bar resize; maximize respects reserved region, true fullscreen follows compositor policy.
- Multiple output bars must not reserve space on wrong monitor or leak surfaces when a display disconnects.

### 4.4 Wallpaper page: required user interactions

- Large thumbnail preview for selected monitor plus current source and crop. Default included image: `assets/wallpapers/swiftshell-default-crimson.png` (already committed).
- **Choose Image...** opens a real `QtQuick.Dialogs.FileDialog`; image is previewed and applied with immediate feedback. Validate file URI, decoder, permissions and reasonable dimensions before commit.
- **Choose Folder...** opens a real `QtQuick.Dialogs.FolderDialog`; builds a local slideshow library without cloud uploads. Display image count, unreadable files and clear folder/remove actions.
- **Mode:** Fit, Fill/Crop (default), Center, Stretch; Tile optional when truly implemented. Crop anchor/focal-point editor if feasible. Color fill for letterboxing.
- **Target:** Current display, selected display, or apply same to all. Per-monitor source choices survive restart, monitor rename/disconnect and hotplug where possible.
- **Slideshow:** On/off, folder selection, interval in minutes/hours, shuffle/sequential, avoid immediate repeats, crossfade on/off, transition duration (including zero), optional pause on battery/lock/fullscreen, optionally synchronized transitions between monitors. Show next change time if known.
- **Color adaptation:** Auto foreground on/off, auto gradient tint on/off, auto accent on/off. Manual foreground, secondary, icon, gradient tint/opacity/height, glass tint/opacity, panel-specific inheritance, one-click restore automatic.
- **Gallery:** Bundled original wallpapers, Recent, Favorites, reset to default, optional user color/gradient background. No account, no web feed, no watermark.
- No manual filesystem path typing required in normal workflow, but advanced details may show the resolved local path for diagnostics.

### 4.5 Displays page: Windows 11-style visual arrangement

**Nonnegotiable:** A genuinely interactive drag-and-drop diagram of detected monitor rectangles. The UI must visually represent each output and allow users to move them around, select them, and apply geometry without editing `monitors.lua`. The backend must be safe even when one output goes black.

**Topology canvas**
1. Enumerate connected outputs and hardware metadata through verified Hyprland/Quickshell API. Show human-friendly display name and a short connector label; choose stable identifiers (EDID where available; document limitations).
2. Calculate rectangles from output mode, transform, effective logical dimensions and scale. Normalize virtual desktop coordinates for an interactive canvas; maintain aspect ratios, adjacency and accurate pointer-to-position conversion.
3. Drag a display anywhere, snap/align near adjacent edges, show ghost preview and guide lines, display positional offsets. Support one, two, three, four displays, portrait rotation, unequal scales, negative coordinates, disconnected outputs and clones when backend allows.
4. Enforce or warn about invalid topology if compositor disallows a layout, huge gaps, overlaps, a monitor outside reachable work area, or disabling the last usable output. Do not snap in a way that makes arrangement impossible to control.
5. Keyboard alternative: move selected display left/right/up/down by meaningful steps, align with another output, restore last arrangement. Accessibility metadata for diagram selections.

**Per-display controls**
- Choose resolution and refresh rate from real advertised supported modes, not guessed combinations. Show current setting, physical dimensions if available, actual scale, logical dimensions, model/connector and orientation.
- Scale slider/list using compositor-supported range (including fractional); rotation (0/90/180/270) and mirror mode only if actually supported. Position, enable/disable with safety rules. Primary/focused preference only where backend meaning is clear.
- HDR/10-bit must be capability gated based on exact monitor/GPU/compositor support; never reuse stale `DP-1 10bit` assumptions from reference hardware. Do not permit an unsupported HDR switch that drops display output.
- A reset/revert action for each display and the entire layout. Prefer live preview before commit.

**Apply / Keep / Revert transaction**
1. User manipulates a **staged** model. Before applying, validate proposed modes/topology against current connected outputs.
2. Snapshot the last-known-good full output configuration. Save a durable rollback plan BEFORE any risky compositor call.
3. Apply via a **verified** backend compatible with the installed Hyprland Lua configuration. Do not blindly reuse legacy text `hyprctl` examples.
4. Show large modal “Keep these display settings?” with visible 15-second countdown and **Keep** / **Revert**. The countdown must be robust to Settings process crashes, lost monitor/focus and compositor disconnections: an independent watchdog or equivalent tested recovery method is required; a QML-only Timer that dies with its owner is inadequate.
5. Timeout, crash or lost visibility reverts to last-known-good configuration automatically. Only after Keep is the accepted configuration made persistent.
6. Persist via a tested managed overlay / opt-in integration path with backup, diff, syntax check, atomic write and known recovery. Do NOT rewrite hand-authored arbitrary Lua or assume direct output persistence works across sessions. If safe persistence cannot be established, explicitly show a read-only or temporary-only mode with no fake Save promise.
7. Test missing modes, output disconnect during countdown, only-monitor disable attempt, refresh-rate unsupported, scale mixups, HDR failure and bad monitor ID. The UI remains recoverable by keyboard.

**Config strategy:** Existing `~/.config/hypr/config/monitors.lua` is owned by the user. SwiftShell may propose a separate managed file included voluntarily or a supported runtime configuration API, after version-specific proof. Do not regex-edit or destructively overwrite it.

### 4.6 Keyboard & Shortcuts page

- Read current active bindings accurately, including custom Lua. Show categorized action, chord, current owner, scope and whether a binding is safely editable. If arbitrary Lua cannot be parsed reliably, show such binds read-only with honest limitation.
- “Record shortcut” control captures modifiers + key without accidentally executing or persisting another shortcut; Escape cancels, Enter confirms where appropriate, reserved/duplicate combos detected and explained.
- Editable categories: Spotlight, Settings, Control Center, screenshots, workspaces, move/focus windows, floating, maximize, fullscreen, lock, media, notifications, user application launches. 60% keyboard-first, no dependence on Fn+arrow.
- Explicit collision policy: show existing binding and offer cancel or deliberate replacement; no silent override. Preserve ability to undo/revert every change.
- **Never regex-rewrite `binds.lua`.** Prefer a documented, validated, opt-in SwiftShell-managed shortcut overlay or a verified structural API; provide exact proposed diff, backups, syntax validation and safe reload. If unavailable, UI remains a binding viewer and only supports safe managed entries.
- Super+Space handoff to SwiftShell Spotlight occurs **only after the launcher is proven** and owner approves, with one-click rollback; opening SwiftShell is not blanket permission to replace Noctalia's shortcut.
- Offer optional “Restore shortcut defaults” for SwiftShell-managed shortcuts only; not global reset of the user's entire Hyprland keyboard layout.

### 4.7 Spotlight/Launcher page

- Search from bar or Super+Space once explicitly assigned; centered on **focused monitor**, not necessarily the bar monitor. Reuse current launcher request mechanism rather than spinning up another daemon.
- Editable pinned/recent apps, result categories, count/height/width and optional icon/label layout. Search scope order: applications first; later files, settings, arithmetic, commands only after each provider is verified.
- File search: user-approved local directories, privacy exclusions, index limits, refresh/reindex, no upload of content. Command execution only in explicit secure command mode, never implicit raw text execution.
- Keyboard selection via Tab/Shift+Tab and Alt+J/K; Enter launches; Escape/outside click closes; repeat Super+Space toggles where robust. Search input remains visible during scrolling.
- Clear history, recent items retention and privacy options. Apps use native desktop entry execution semantics and theme icons.

### 4.8 Audio & Media page

- Default output and input device, volume/mute, microphone level, device details, optional boost beyond 100% with clear warning, per-application streams if service supports, device hotplug behavior, playback test if safe, scroll volume step.
- Media/MPRIS: player selection, now playing, play/pause, skip, seek only if supported, album art, active-player priority, media panel/bar visibility, idle/no-player state, privacy.
- All sound changes through PipeWire/WirePlumber or verified service API. Settings, bar and control center must observe the same state; no competing local volume caches.

### 4.9 Network & Bluetooth pages

**Network:** Wi-Fi toggle where supported, SSID scan, signal/security, connect/disconnect, saved connections and forget, Ethernet status, VPN overview, airplane mode only when supported, IP/DNS info read-only where appropriate, link diagnostics. Credentials passed to OS-approved secret handling; no plaintext file or logs. Handle NetworkManager absent or permission denied.

**Bluetooth:** Adapter enable, discovery start/stop, scan results, pair/unpair, connect/disconnect, trust/forget where supported, device battery and capabilities, pairing prompts, invalid PIN, disappearing device, bluez unavailable and discovery timeout. Use BlueZ; do not keep scanning when UI closes.

### 4.10 Notifications page

- Enable native SwiftShell notification handling *only after service ownership handoff*, banner placement, display target, duration, app grouping, sounds, urgency rules, history retention, Do Not Disturb, scheduled quiet hours, per-app overrides, clear history, lock-screen privacy.
- “Who owns notifications right now?” status and explicit safe activate/deactivate path; no silent battle with Noctalia or other daemon.
- Preview notification design visually but label it **Preview** until the protocol is actually owned.

### 4.11 Power, General, About & Diagnostics

- **Power:** Lock, suspend, logout, restart, shutdown with confirmations and real error handling; inhibitors, permissions, battery/AC/battery saver where published. Hide unsupported charging-limit controls on desktops.
- **General:** Language/time formats where available, startup behavior, autostart with opt-in, shell restart, check for updates and update preference, image/cache budget, clear recent activity, troubleshooting, export/import, reset preferences, backup/rollback list, version and licenses.
- **Diagnostics:** Show Quickshell/Qt/Hyprland versions, connected outputs and scales, wallpaper state, blur mode + reason, audio/network/Bluetooth service status, notification owner, current settings schema, last errors (redacted), “Copy diagnostic report”. No secrets/private paths by default.
- **Advanced:** Explicitly labeled experimental compositor features, managed config opt-in, system action guardrails, accessibility, performance/low-memory mode. Never default to an experimental disruptive option.

### 4.12 UX acceptance for Settings as a whole

Users must be able to configure **supported** shell features entirely from this floating GUI without opening a text editor. A changed value must visibly affect the correct component, survive restart, and show failure when it cannot apply. Every live control needs validation and a backend test. Implement category pages gradually, but never “complete” an entire category with dead placeholder toggles.

---

## 5. Native wallpaper engine: rendering, slideshow and color intelligence

### 5.1 Per-output background lifecycle

Implement a background-layer surface **per live monitor**, based on Quickshell/Wayland layer shell with proper namespace and a completely non-interactive surface: no pointer interception, no keyboard focus, no exclusive zone, no unwanted overlay over windows or lock screen. Layer order must actually put it behind normal windows. Ensure the background is hidden/stopped independently when SwiftShell stops. A disconnected output should release images/texture resources and not break the remaining monitor.

A user with one laptop display, another user with three monitors, and the reference DP-1 + HDMI-A-1 system must all work without hardcoded names, workspaces, pixel ratios or image paths. Resolve bundled asset from installed app resource root; the source file exists today at `assets/wallpapers/swiftshell-default-crimson.png`. The installed app must copy/include this asset and be able to find it offline. Missing asset = neutral solid/gradient fallback with diagnostic warning, not crash.

**Coexistence:** Existing `hyprpaper`, `swww` or another wallpaper process may be installed. Running both can create visual conflicts, but SwiftShell must never kill/disable another wallpaper daemon automatically. At optional activation, detect apparent ownership where possible and explain how to switch safely. SwiftShell's native renderer is the long-term default, no external wallpaper utility required for basic image, transitions and slideshow.

### 5.2 Image pipeline

1. Resolve user file URL or chosen folder via Qt native/fallback file dialogs. Validate local scheme or explicitly handled portal URIs, decoder availability, type, readability, file size/dimensions and decompression risk. Reject invalid source without abandoning working wallpaper.
2. Read display orientation, logical size and scale. Compute transformed crop rectangles (fill/fit/center/stretch). For Fill, use consistent crop anchor/focal point in both preview and final render. Rotation and odd aspect ratios must not distort unexpectedly.
3. Load/resize asynchronously or outside UI hot path. Preload next slideshow image, apply bounded cache (texture count and byte budget), release old textures after fade. Do not decode every 8K PNG synchronously on each frame.
4. File change/deletion/permission: keep previous last-good image if possible and show warning. Folder move/empty folder: pause slideshow and display fallback, no infinite busy loop.
5. Multiple outputs: either independent sources/slideshows or same-to-all with separately calculated crops. Persist choices against stable output identity when available, fallback to connector name with documented nonportable limitations.
6. Respect reduced motion and power/performance settings. When slideshow disabled, engine is event-driven and does not render extra frames.

### 5.3 Slideshow state machine

States: Disabled, Scanning, Ready, Waiting, Preloading, Transitioning, Paused, Error. Transitions must be deterministic and tested. Choose folder -> scan with filtering -> show count -> choose first valid image -> persist configuration -> schedule next at configured interval. Shuffle avoids immediate repeat, or honors an explicit sequential order. If chosen folder changes during transition, cancel stale work and reload safely. If last-good image is deleted, recover cleanly.

Crossfade: keep two image layers and interpolate opacity for a configured 0–1000ms (initial recommendation ~350–500ms) transition. Never fade the entire desktop to opaque black. Fade should work at high refresh without a busy CPU timer; ensure no memory leak after hundreds of slides. If settings reduced motion, switch instantly and still update color analysis. Optional pause-on-battery/fullscreen/lock must listen to OS/compositor state, not guess.

### 5.4 Automatic contrast: what “knows what is underneath” really means

A normal Wayland shell cannot freely sample every pixel under every UI element from arbitrary windows. **SwiftShell knows the wallpaper it rendered and exactly how it cropped it**. Base automatic adaptation on wallpaper-local regions. Don't request screen capture permissions or pretend it measures live application windows.

Build a `ColorAnalysisService` that:

1. Takes decoded low-resolution wallpaper data plus crop/fit transform and monitor geometry, not raw arbitrary compositor capture.
2. Samples near the **top edge** behind the bar and, where practical, each module's horizontal region. A global average will fail when wallpaper is dark on one side and light on the other.
3. Derives luminance using a documented sRGB->linear conversion and calculates candidate text-to-background contrast. Choose near-white foreground for dark regions and near-black for light regions; use the subtle edge gradient/scrim when neither candidate meets the readability target over a busy patch.
4. Optionally samples behind each floater's expected geometry to choose neutral light/dark material tint, knowing that open app windows may change the actual backdrop. When real compositor blur is active, a safe scrim must preserve contrast regardless of unknown window content.
5. Constrains auto accent/tint saturation and luminance so the UI remains chiefly monochrome even on the red wallpaper.
6. Uses hysteresis and smoothing so small color differences, motion or slideshow crossfades cannot flicker text rapidly between black/white. When fading between drastically different wallpapers, temporarily increase contrast scrim or plan transitional colors across endpoints.
7. Recalculates only on source, crop, monitor layout/scale, top gradient/height or saved-theme changes. Cache by image identity + transform + region, and debounce rapid slider moves.
8. Exposes `analysisAvailable`, detected mode, confidence and explicit fallback. Error -> neutral accessible palette.

**User preferences remain independent:** `automaticTextContrast`, `automaticGradientColor`, `automaticAccent`, `gradientEnabled`, `gradientHeight`, `gradientAlpha`, `manualPrimaryText`, `manualSecondaryText`, `manualIcons`, `manualGradientColor`, `manualMaterialTint`, `manualSurfaceOpacity`, `manualShadow`. Each surface can inherit global or override. Auto-off must recover exactly the user's stored manual colors. Don't overwrite manually chosen tint just because the wallpaper changed.

**Required color fixtures:** pure white, pure black, 50% gray, split black/white top edge, low-contrast busy noise, saturated red/black generated default, pale pastel, portrait crop, two monitors using opposite luminance images, rapid slideshow change. Assert contrast, deterministic mode and no oscillation. Verify physically with screenshots at bar left/center/right.

### 5.5 True backdrop blur: separate feasibility milestone, not wishful QML

**This is the visual centerpiece and an integration risk.** The existing SwiftShell preference `appearance.panelBlur` currently controls no genuine blur in the 0.2-era UI. Do not repeat that mistake.

**Implementation investigation:**

1. Detect installed Quickshell and Hyprland versions, Wayland protocols and compositor capabilities. Check official docs and confirm the *installed* types. Quickshell 0.2-era docs lack some newer background effect types; referencing a nonexistent attached type in loaded QML aborts parsing even if logic would hide it.
2. Determine namespace(s) for each SwiftShell surface: bar, popover, launcher, notification and native Settings toplevel. On Hyprland, layer rules and normal window rules differ. If Lua configuration is used, consult **Lua-specific** layer-rule documentation and use a reviewed mechanism rather than copying legacy `layerrule = ...` text.
3. Build an isolated one-panel experiment on target Wayland system. Put a checkerboard or text-filled application BEHIND the floating panel. Show observable defocus of that application; mere tinted see-through surface does not count. Confirm corners clip, no rectangular blur halo and reasonable GPU cost. Test both wallpapers and application backgrounds.
4. Decide backend: verified compositor layer/window blur rule, newer supported Quickshell effect, or graceful translucent-frost fallback. Do not require unofficial compositor plugins by default.
5. Any compositor integration affecting live config must be **opt-in with preview, backup and rollback**. Avoid enabling global blur against user's wishes. If backend only supports global radius/pass settings, Settings must disclose that; don't show a per-surface blur radius slider that changes nothing.
6. If true blur is impossible on a given system, show disabled `Backdrop blur` with a short reason and maintain a visually attractive high-contrast translucent scrim. An optional wallpaper-only blur may be labeled honestly as wallpaper simulation, not genuine behind-window defocus.
7. Recheck when compositor version, namespace, capability or global settings change. Never use a plugin/API before testing on its supported version.

**Acceptance evidence:** real screenshot/video with a recognizable patterned/lettered window blurred behind a rounded Settings, Spotlight and popover surface; no opaque fill strip or sharp rectangular background; verified blur disabled fallback; acceptable CPU/GPU performance and no window/input interference.

Primary references for agent verification (review current versions rather than assuming these pages remain unchanged):
- Hyprland layer rules: https://wiki.hypr.land/Configuring/Window-Rules/
- Hyprland Lua layer rules: https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/rules/layer-rules.md
- Qt FileDialog: https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html
- Qt FolderDialog: https://doc.qt.io/qt-6/qml-qtquick-dialogs-folderdialog.html

---

## 6. Native OS controls: full service integration

**Principle:** The control center is a compact view; Settings is its expanded configuration view; the bar is its lightweight status view. All three observe **the same central service model** so they cannot disagree. No dummy buttons. One service backend per domain. Real hardware tests for each domain are mandatory, not merely “a D-Bus call was written.”

### 6.1 Audio / PipeWire / WirePlumber

Current code already supports default sink volume. Expand: default output sink and input source, list devices/ports, real volume and mute state, microphone gain and mute, per-app stream volume where available, headphone hotplug and selected default sink, optional volume boost with warning, scroll step, device names, output unavailable behavior and system-state changes from outside SwiftShell. Only manipulate bound tracked objects. Clamp valid range. Ensure that Settings, bar and control center respond identically to sink changes. Fallback on missing PipeWire module must not prevent shell startup.

### 6.2 Network / NetworkManager

Network state via typed D-Bus or verified supported API, NOT parsing English `nmcli` output on each UI refresh. Wi-Fi available/powered/scanning, SSIDs and signal, connect/disconnect/forget, Ethernet link, VPN when available, errors and timeouts, permissions and airplane mode when supported. Respect NetworkManager ownership and use OS secret handling/agent for credentials. Never store SSID passwords in SwiftShell settings or logs. Scan at sensible user-triggered/limited intervals and cancel stale scans.

### 6.3 Bluetooth / BlueZ

Adapter available and power toggle, discovery start/stop, paired/available devices, pairing interaction, connect/disconnect, trust/remove with confirmation where appropriate, battery if advertised, device capability labels, no-adapter state, delayed operation, permission denial and device disappearing mid-action. Stop discovery on UI dismissal or timeout. Don't run continuous radio scans to drive an icon.

### 6.4 Brightness

Distinguish laptop backlight, external DDC/CI brightness, unsupported external monitor and software gamma dimming. Use verified hardware-safe interface; external monitor may need extra package and permission. **Never call software dimming “hardware brightness”.** Display disabled state with reason when unavailable. Don't make brightness control a mandatory dependency that prevents desktop loading.

### 6.5 System tray / StatusNotifierItem

Real protocol model and DBus menus, app-owned icons and context menus, proper click/middle/right actions, overflow, per-module visibility and scale. Handle tray owner changes, icons disappearing, large menus, missing image sources and multi-monitor placement. Bar must never show a tray icon that can't be clicked properly.

### 6.6 Media / MPRIS

Live active-player model, selectable players, play/pause/next/previous/seek if supported, title/artist/artwork, optional track progress/volume, empty state, automatic bar hiding when idle, changing players, art loading bounds and privacy preferences. No periodic high-frequency polling for track state if signals exist.

### 6.7 Battery, power and system session

UPower or appropriate native service for laptop/UPS battery where available; charge percentage, AC, estimated life only when valid, power state, optionally power profiles if supported. No invented charging limit slider. Lock/suspend/logout/reboot/shutdown use supported session APIs with confirmation and polkit behavior respected. Don't claim success before action is accepted; expose inhibitors and permission errors clearly. Don't replace the compositor lock screen without an explicit separate milestone.

### 6.8 Common backend test matrix

For every service: no daemon, daemon present, no device, one device, multiple devices, unsupported feature, permission denied, user canceled, service restarted, hotplug, operation delayed, busy state, repeated toggles, UI closes mid-call, shell restarts, real OS state changes externally, and fixed-action rollback. UI must not freeze, guess, silently fail or leak processes.

---

## 7. Notifications: proper protocol ownership, not a war with Noctalia

Implement native banners, history/notification center, grouping, urgency, app icon, action buttons, replacing existing ID, close/expire, Do Not Disturb, per-app overrides, sounds (if supported), privacy on lock, retention and clear history. Keep appearance consistent with individually floating frosted panels. Text wraps and truncates predictably; oversized content/images are capped.

**One daemon owner per session** is a hard requirement. Detect ownership of `org.freedesktop.Notifications`. On the reference system Noctalia may already own notifications. Do NOT take over DBus name, stop the current daemon or steal notifications merely because SwiftShell is launching in development mode. Provide a visible diagnostics/activation handoff that asks permission and can restore the previous owner. Silent conflict is a release blocker.

Notification store: bounded queue/history, optional persistence, safe redaction and storage location, no log of sensitive body text. DND must still correctly respond to protocol interactions as appropriate. Respect urgency and timeout semantics while allowing user preferences. Test multiple applications, replacing notifications, click action, transient notification, critical urgency, daemon conflicts, notification source disappearing, DND schedule, screen lock and session restart.

---

## 8. Spotlight, top bar and cross-cutting shell behavior

### 8.1 Spotlight target behavior

M3.2 is already under development. After merging, it must open centered on the **focused Hyprland monitor** independently of bar location. Super+Space must be opted into through a reversible change, not stealth-installed. The existing `scripts/request-launcher.sh` / `swiftshell request-launcher` request channel should be reused where suitable. Escape, outside click and repeat request close the overlay and release focus. Search field remains visible while results scroll, keyboard works without dedicated arrows, DesktopEntries index loads asynchronously, app icon themes resolve, `DesktopEntry.execute()` launches apps without shell interpolation.

Later enhancements: safe file search with explicit user-selected scope and exclusions; arithmetic using bounded parser; Settings search; optional command mode with visible opt-in and a no-execute-by-accident policy. Search must remain fast and offline by default. Never upload local file content for app discovery. Do not add an always-running second launcher daemon.

### 8.2 Bar behavior and geometry regression traps

Fully transparent bar surface with optional independently controlled top-edge gradient. No permanent solid rectangle. Module hit areas and popovers aligned and clipped per display. Automatic text/icon scaling derived from the bar height. Graceful overflow if many modules enabled. Active workspace and focused app title reflect the **bar's actual output** and actual Hyprland workspace state. Don't assume exactly 3 workspaces or one active output.

When `reserveSpace=true`, tiled/maximized windows should respect the logical-height reserved area. Switching `false -> true` must actually change `ExclusionMode`, not just reassign a numerically unchanged height. True fullscreen may legitimately cover the bar. When Noctalia is still shown on same output, overlay mode can remain an explicit setting. Bar never steals keyboard focus. Popovers close when their anchor disappears, target output disconnects, or another popup replaces them.

### 8.3 Responsive multi-monitor contract

Read outputs and workspaces from live Hyprland + Quickshell; persist user preferences separately; no names or resolutions baked into defaults. Behave sensibly with one eDP laptop screen, two desktop screens, external unplug/replug, portrait output, primary change, scale 1.0/1.5/2.0 and different DP/HDMI connector names. Respect compositor's logical coordinate system and safe fallback if a preferred output vanishes. Reconnect should restore preference when identifiable and should not trap a window off-screen.

---

## 9. One-script installation, updates, repair and safe activation

**End-user objective:** A user should be able to obtain SwiftShell, run one documented guided command and end up with a complete functioning shell without opening a config editor. “Zero dependency nonsense” means **zero manual dependency juggling**, not that the project rewrites every mature Linux service.

### 9.1 Installation flow (explicitly implemented and tested)

1. **Preflight:** Detect distro, pacman (initial supported automatic installer), Hyprland session, Quickshell/Qt versions and required modules, XDG directories, system services, display/scale information, portal availability and ownership conflicts. Report unmet prerequisites with exact package names. Support offline installation when packages/assets are already present.
2. **Consent:** Explain required packages and optional integrations; request approval before package manager invocation or privileged change. Don't run internet shell scripts from arbitrary sites. Don't silently run sudo, overwrite desktop config or stop another shell.
3. **Dependencies:** Use distro package manager on supported systems; ensure package names/versions are correct; separate runtime from test/dev dependencies; don't vendor incompatible Qt builds or bundle a second NetworkManager. Components without optional services should degrade gracefully rather than block installation.
4. **Deploy:** Place SwiftShell's Qt/QML, helper (if needed), binary assets/wallpaper, .desktop entry, CLI, metadata and icons under owned XDG paths. Confirm resources work both from repo checkout and installed tree. Use stable filenames and appropriate executable bits.
5. **Configuration:** Generate first-run hardware-agnostic settings, based on actual connected outputs where available. Never bake in `HDMI-A-1`, `DP-1`, 2560×1440 or `[4,5,6]`. Existing settings are preserved; schema migration copies a backup first, validates after and can revert. Unknown settings should not disappear because JsonAdapter rewrote the file.
6. **Health check:** Static/load tests as applicable, visible diagnostic summary, no missing executable/module/assets; if in a live Hyprland session, optionally launch SwiftShell **in isolated development mode** for preview without replacing Noctalia. Don't say “working” because `scripts/check.sh` ran in headless cloud.
7. **Activation:** Explicit separate opt-in to make SwiftShell the active/default shell. Detect current bar/wallpaper/notification/shortcut ownership. Back up only the integrations SwiftShell is authorized to change. No blanket replacement of config directories; retain previous shell start command. Provide a visible rollback path and safe fallback if SwiftShell exits unexpectedly.
8. **First run:** Show simple GUI setup: wallpaper, appearance, outputs, bar placement, optional shortcuts, and service status. All optional; defaults work out of the box. Not a wizard requiring the user to edit a `.lua` file.
9. **Reinstall/update:** Idempotent on repeated execution, preserving settings and user files. Version checks, migration, backups, rollback to previous installed version. Show release notes and restart safely. No forced updating while user is gaming.
10. **Uninstall:** Stop only SwiftShell processes, reverse only SwiftShell-managed integrations, optionally restore previous shell, remove files owned by SwiftShell, keep user settings by default unless explicit `--purge-settings`, and do not uninstall shared OS services.

### 9.2 CLI and GUI recovery

Retain/extend clear commands analogous to `swiftshell check`, `start`, `stop`, `status`, `doctor`, `activate`, `deactivate`, `rollback`, `update`, `uninstall`. Names must match actual implementation and help text. `swiftshell doctor` should report system versions, missing service, module support, blur status, output mapping, corrupted config/backup and notification ownership, without leaking secrets. Settings GUI should expose status, log export/redaction, and a “Restart SwiftShell” operation once reliable.

**Critical recovery:** Every risk-bearing installer step logs what it owns and backs it up. If activation fails to render a bar/launcher within the supported check, offer/carry out a safe rollback that preserves the previous desktop. Never require `git reset --hard`, system-wide service reinstalls, or guessing a `qs` PID.

### 9.3 First-run test matrix

Fresh local account; existing Noctalia install; standalone Hyprland; eDP laptop; external monitor; `pacman` missing; empty PATH; read-only HOME; package missing; interrupted install; duplicate install; old schema; corrupted settings; failed shell launch; missing wallpaper; no NetworkManager/PipeWire/BlueZ; notification daemon already active; no admin approval; login after reboot; uninstall/restore; asset paths; roll back after installer dies mid-step. The package must never break the current session merely by being installed.

---

## 10. Sequential Cursor PR roadmap: implementation order and deliverables

**Do not build all of this in one PR.** These are dependencies and acceptance gates. If needed, split further but don't combine unrelated backend/visual work into a speculative mega-commit. Each PR includes docs, unit/QML tests, capability handling and a live target test plan.

### M3.2 — Finish current in-flight work before new settings milestones

- Spotlight on actually focused monitor, compact centered card; Super+Space handoff documented/safely opt-in; monitor autodetection and arbitrary workspace IDs.
- Remove universal HDMI-A-1, DP-1, fixed workspaces. Preserve reference machine's personal settings.
- Test monitor changes, focus, QML startup, desktop entries, input release, bar reservation. Hardware gate A requires the owner to validate actual Wayland behavior.

### M4.0 — Architecture, schema and Settings window feasibility

**Scope:** Build the technical foundation, not a mountain of empty pages.

- Audit Quickshell/Qt version and prove **real native floating Settings toplevel**. Produce isolated smoke test; if Quickshell APIs unsuitable, document and use the smallest bundled companion frontend with the same SwiftShell services/theme, not an always-on extra daemon.
- Expand Settings schema, migration/backup, live value vs saved preference types, capability registry; safe handling of unknown keys and failures.
- Define shared GUI primitives for row, toggle, slider, picker, menu, sections, focus, tooltip, error and disabled states, respecting fonts/scale.
- Show a minimal real Settings window with working launch/close and current supported Appearance controls.
- Test schema migration from current `settings.json`, missing/corrupt file, window lifecycle/focus and QML root startup. NO live config mutation.

**DoD:** Real floating window verified on target or explicitly held at visual hardware gate; no fake settings navigation advertised as completed.

### M4.1 — Settings navigation, appearance preview and general UX

- Native sidebar, responsive layout, searchable settings index, keyboard/mouse navigation, real category grouping, reset/undo for implemented controls.
- Appearance page controls for mode, text size/weight, density, panel opacity/tint, shadow/radius, reduced motion, top gradient enabled. Only actually applicable controls active.
- Unified theme tokens across existing bar, Spotlight, popovers and Settings. Settings changes propagate immediately and persist after restart. User should not edit JSON.
- Tests for navigation, search focus, open-repeat behavior, color and persisted values. First real screenshot/style review; don't defer appearance QA until the end.

### M4.2 — Bar configurator and sizing engine

- Bar height with derived icon/font/spacing/zone scaling; controls for monitor placement/policy, reserve space, module visibility and drag reorder where real backend exists.
- Clock/date/workspace configuration and per-module options. Support overflow, narrow screens and fractional scaling.
- Tests min/max height, false→true reservation, fullscreen/maximize, output reconnect, font clipping, workspace empty state and touch targets.

### M4.3 — True material/backdrop blur capability proof

- Investigate and prototype correct compositor backdrop blur for SwiftShell surfaces on supported Hyprland Lua setup. Determine safe optional integration, supported namespaces and version gates.
- Add material service with explicit capability report. Implement blur for one surface, expand to other floaters only after measurement.
- If no supported mechanism, implement visually acceptable translucent fallback and labeled unavailability; don't rename alpha to Gaussian blur.
- Real checkerboard/app-behind-panel screenshot is **required** before marking real blur complete.

### M4.4 — Native wallpaper renderer + choose image

- Default crimson PNG shipped through package/resource path. One background surface per output, no input focus, safe coexistence, crop/fit modes.
- Wallpaper settings page with per-output preview, FileDialog, apply/reset, file validation, missing source fallback, memory limits.
- Test resolution, scale 1.5, portrait, output remove, 8K image, invalid file, app restart, installation asset references.

### M4.5 — Slideshow + adaptive contrast + manual colors

- FolderDialog, image scan, slideshow intervals/shuffle/crossfade, safe textures, transition cancellation.
- Regional wallpaper analysis and per-surface light/dark text, gradient/intensity decisions, graceful transition between palettes.
- Manual color picker and independent overrides for foreground, icons, material tint, gradient tint, opacity and shadows. Auto-off preserves manual values.
- Validate fixtures for pure white/black, split, busy, red/black and multiple monitors. Measure slideshow memory/CPU.

### M4.6 — Displays topology UI and safe transaction backend

- Windows 11-like display rectangles drag/drop layout, snap guides, sensible coordinate math, live mode/scale/rotation lists, preview and cancel.
- Apply/Keep/Revert with crash-safe independent watchdog. Stable backend verified against Hyprland Lua before any persistent write.
- Managed opt-in persistence path with backup, diff, safe reload and rollback; if not verified, status must be read-only/temporary, not pretend-success.
- Test single monitor, dual mixed scale, rotated output, output disconnect, invalid mode, countdown crash, reboot/recover.

### M4.7 — Shortcut GUI and safe managed keybind integration

- Read active bindings where supported; categorized viewer; record shortcut and conflict resolution; expose first-class SwiftShell actions; optional managed overlay.
- Explicit Super+Space and Super+Z handoff to SwiftShell after verification; keep backup and rollback. Do not rewrite arbitrary Lua.
- Tests 60% keyboard, Alt/Super modifiers, duplicate binds, Escape cancel, previous config untouched and recovery.

### M5.1 — Audio / media / system tray

- Finish audio device/input/app streams, MPRIS playback and icons, StatusNotifierItem tray; unify bar/control-center/Settings service models.
- Test actual hardware, no-audio fallback, hotplug and layout/overflow at multiple sizes.

### M5.2 — Network, Bluetooth, brightness, power

- NetworkManager, BlueZ, hardware brightness where available, battery/session actions. Secure connection credentials, permission/error handling, no continuous radio scanning.
- Verify every interactive control against actual OS state and service restart. Distinguish optional unavailable hardware.

### M6.1 — Notifications ownership and functional center

- Safe opt-in daemon ownership workflow; protocol compliant banners, history, actions, replacement IDs, DND, urgency, privacy. Noctalia coexistence must remain intact.
- Test ownership conflicts and handoff both directions, not only `notify-send` when SwiftShell is alone.

### M6.2 — Notification preferences and integration polish

- Per-app policies, schedules, sounds/privacy where supported, grouped/collapsible history, battery/media/network notification behavior, settings integration.

### M7.1 — Holistic UI/UX polish

- Visual review of every state and surface, exact icon/typography/spacing consistency, proper rounded blur clipping, subtle shadow, no hard outlines or giant tiles; remove bounce animations.
- Review low/high contrast backgrounds, long labels, high DPI, overlapping windows, variable Settings size and keyboard focus.
- Ensure fallback looks intentional where true blur unavailable. No unapproved proprietary UI assets.

### M7.2 — Performance, fault tolerance and accessibility

- CPU/GPU/memory profiling with high-refresh gaming and slideshow; reduce image decode and polling; cap caches; verify suspend/resume, monitor hotplug, service restarts, 1000 launcher apps and notifications burst.
- Keyboard and pointer/a11y pass, high contrast, reduced motion, no orphan surfaces, error-handling audit.

### M8.1 — One-command install and packaging

- Complete guided installer, dependencies, native assets, package metadata, activation health, migration, rollback, safe uninstall, repair/doctor, Arch/CachyOS package. Test temporary homes and live clean-user account.

### M8.2 — Release candidate certification

- Run full matrix in Sections 11–12, close launch blockers, docs/user guide, troubleshooting, release notes. All unsupported features explicitly labeled with capability status. Only mark “stable” after real-system acceptance.

**Maintenance PR policy:** Urgent bugs get small regression PRs between milestones. Every fix includes a test of the exact root cause, rather than patching one failing QML file and waiting for the next missing import to appear.

---

## 11. Mandatory automated tests, real hardware tests and visual proof

### 11.1 Automated checks on every PR

Run `scripts/check.sh` and report exit status, counts and relevant warnings. Expand it as new features arrive, but **do not mask failures to turn CI green**. Tests should cover:

1. **Static/import:** Every project QML type has valid import, modules exist, braces and inheritance are correct, no direct QtObject unnamed children, no writes to read-only implicit sizes or Loader status, correct normalized rgba values.
2. **QML compilation/instantiation:** Load each changed component and a shell-root path using accurate Quickshell stubs. Distinguish a real Qt runtime test from a stubbed compositor. Add load tests for SettingsWindow, WallpaperHost, wallpaper surface, service adapters, notifications and dialogs as they are introduced.
3. **Pure logic:** Validators, migrations, shortcuts conflicts, display topology math, monitor autodetection, workspace assignment, proportional bar scaling, cropping, adaptive color/luminance, slideshow state machine, gradient color and service error states.
4. **Integration mocks:** D-Bus service present/absent, denied, hotplug, delay, stale events, settings reopen, file unreadable, notification owner conflict, display revert watchdog.
5. **Installer:** Temporary HOME/XDG environments, no changes to foreign Hyprland/Noctalia files, re-install preserves preferences, failure cleanup, uninstall preserves user data, asset installation and package dependencies.
6. **Performance unit/load:** Application catalogue 10/100/1000+ items, image folder 0/1/1000 files, rapid slider changes, 100 notification bursts, repeated overlay open/close, cache boundedness.
7. **Safety invariants:** No unapproved `sudo`, system service ownership, shell script arbitrary execution, secret logging, bogus output names or static connector assumptions in defaults.

**Prior mistake to avoid:** `qmllint` can miss read-only property overrides; offscreen QML stubs can still miss runtime Quickshell attached properties. Implement both layers of tests and a real-session gate. A static test asserting the old HDMI default or constant 28px height MUST be updated when that is no longer the product rule.

### 11.2 Real hardware acceptance matrix

For each milestone, provide a table with **PASS / FAIL / NOT RUN**, evidence, exact version and notes. Agent must never label NOT RUN as PASS. Minimum matrix:

| Test | Required observed behavior |
| --- | --- |
| Start/stop in existing Hyprland session | SwiftShell launches independently, doesn't disable Noctalia/config, and exits cleanly |
| Single-monitor laptop (`eDP-*`) | Bar, Spotlight, Settings and wallpaper choose correct output automatically |
| Multi-monitor 1080p + 1440p | Dynamic output and workspace mapping, no hardcoded names |
| Fractional scale 1.5 and scale 2.0 | Correct logical size/offsets, no clipping or double-scaling |
| Output hotplug / focused-output change | UI falls back without crash/input trap and restores intended placement |
| Bar height minimum/default/maximum | Font/icons/gaps/exclusive zone scale proportionally, no clipped modules |
| Maximized versus true fullscreen | Correct reserved zone, true fullscreen policy, no overlay conflict |
| Spotlight search | Dolphin/Helium and arbitrary desktop entries found; icons display; launch, focus release, repeat/close |
| Settings normal floating window | Actually movable/resizable, no offscreen restore, keyboard focus sane, one instance |
| Settings search/migration | UI changes real state, survive restart; corrupt config handled safely |
| Wallpaper choose image | Correct crop, per-output behavior, missing file fallback, no separate wallpaper tool needed |
| Wallpaper slideshow | Folder choose, empty folder, shuffle, pause, crossfade, resource bound |
| Adaptive color | Black/white/split/busy/crimson examples readable; manual overrides persist |
| **Real** Gaussian blur | Checkerboard/text application BEHIND panels visibly blurred and corners properly clipped; distinguish from alpha |
| Displays drag/drop | Correct diagram, snapping, modes; preview/Keep/Revert; auto recovery when timer expires or Settings crashes |
| Shortcut GUI | Correct inventory, conflicts, record cancel, explicit handoff and rollback |
| Audio | Output/input/device/app change affects real service and all SwiftShell UI |
| Network/Bluetooth | Real connection, permission/timeout errors, absent service fallback |
| Tray/MPRIS/brightness/battery | Only available hardware/services show actionable controls; correct icons and response |
| Notifications | Conflict detection, opt-in ownership, action, replace, DND and restoration |
| Locked/fullscreen/high GPU load | No shell crash, stuck focus, runaway wallpaper rendering or corrupted display |
| Clean install/reinstall/update/uninstall | Existing shell and personal files survive; one-command path works |

### 11.3 Visual screenshot review per PR

On supported reference outputs, capture before/after for normal, hover, focus, selected, disabled, unavailable, busy, open/close and edge-of-screen states. Inspect: no visible solid top strip, no outlines, independent floating surfaces, rounded blur edges, color adapts to current wallpaper region, proper light/dark text, compact spacing, no overlapping controls, icon alignment, acceptable popover anchors, no overly wide glass rectangle, no giant rounded Material toggles, no bounce motion. Test white and dark wallpaper, not only the attractive red default. Screenshot evidence cannot prove input focus or crash recovery; test those functionally too.

### 11.4 Performance targets and evidence

Define measurable goals with target hardware rather than inventing numbers. Idle shell should be signal-driven with negligible unnecessary CPU; normal Spotlight typing shouldn't stutter with hundreds of apps; Settings slider drag shouldn't block compositor frames; slideshow shouldn't cause repeated full-resolution decode or texture growth. Test during 1440p high refresh/game fullscreen, monitor hotplug and multiple simultaneous popovers. Profile before promising exact latency/memory/GPU numbers. Do not render offscreen backgrounds every frame simply because an animation loop was convenient.

---

## 12. Cursor regression prevention checklist: stop repeating the same mistakes

### 12.1 Before writing QML

- [ ] Read existing component and actual module documentation at target installed version.
- [ ] Know root type inheritance and default child property. No unnamed child under QtObject.
- [ ] Know whether width/height/implicitWidth/implicitHeight/status are writable for *this exact type*.
- [ ] Verify all imports including `../components`, `../services`, `../themes`, local helper modules and QtQuick.Dialogs.
- [ ] Do not use a version-specific attached type in a file that an older supported QML engine parses.
- [ ] Use normalized RGB fractions with `Qt.rgba`, not 255.
- [ ] Resolve icons through tested theme API, not synthetic paths.
- [ ] Make Settings and service state single-owned and event-driven; no duplicated polling.
- [ ] Prototype unfamiliar component with a small root load test BEFORE expanding the feature.

### 12.2 Before sending commands to Hyprland

- [ ] Detect Lua vs legacy dispatcher. The reference system's working call was `hl.dsp.focus({ workspace = N })` through `Hyprland.dispatch`.
- [ ] Verify API and installed version; do not use commands copied from unrelated legacy tutorials.
- [ ] Check target output, scale and fullscreen state from compositor, not hardcoded user hardware.
- [ ] For persistent display/shortcut changes: explicit opt-in, backup, diff, validation, atomic write, crash-safe rollback. Never regex-rewrite arbitrary Lua.
- [ ] Do not inadvertently modify existing gaps, focus policy, HDR modes, color depth, Noctalia, autostart or user services.

### 12.3 Before claiming blur, wallpaper intelligence or UI polish

- [ ] Real compositor blur visibly affects apps behind the floater. Alpha alone does not qualify.
- [ ] Rounded clipping correct, no sharp rectangular halo, fallback doesn't lie.
- [ ] Wallpaper analysis uses own rendered image and crop geometry only, not unauthorized screen capture.
- [ ] Automatic text readable at top-left/top-center/top-right on split images.
- [ ] Manual colors saved independently from auto mode and preserved after restart.
- [ ] Colors/panel materials consistent across Settings, Spotlight, bar modules and notifications.
- [ ] No bounce animation or massive permanent UI chrome.

### 12.4 Before claiming Settings category complete

- [ ] Every interactive setting changes a real backend and reflects actual system state.
- [ ] Values persist or clearly show staged/transient; failures and unsupported state are truthful.
- [ ] GUI flows work without editing JSON or Lua.
- [ ] All controls work with mouse and keyboard, and resizing doesn't clip content.
- [ ] Monitor and dangerous changes have working Keep/Revert, including crash case.
- [ ] Reset and migration preserve unrelated values.

### 12.5 Before opening PR

- [ ] Run scripts/check.sh with results and new targeted tests.
- [ ] Load changed QML through actual root test and inspect non-stubbed incompatibilities.
- [ ] Confirm no regression to workspaces, bar reservation, launcher icons/catalog and focus release.
- [ ] Review installer/assets/dependency declarations; check checkout and installed resource paths.
- [ ] Scan for secrets, shell injection, process kill, service takeover and unexpected user-config writes.
- [ ] Update README, architecture, compatibility, tests and docs/decisions as appropriate.
- [ ] Supply live target test checklist and classify evidence honestly.
- [ ] Identify rollback commands and preserve the working Noctalia environment.

---

## 13. Autonomous PR handoff format (mandatory)

**At the beginning of a PR, Cursor must post:**

1. Milestone name and one-sentence definition of usable behavior.
2. Base commit, prior dependency and current repository state.
3. Concrete files/services expected to change.
4. Known API/version questions and target hardware requirements.
5. Explicit risks and safe rollback strategy.
6. Proposed automated tests and real-hardware checks.

**At completion, every PR description must contain exactly these substantive sections:**

- **User-visible changes:** describe actual working behavior, not aspirations.
- **Architecture:** major modules, backend types, persistence and compatibility reasoning.
- **Files changed:** list key paths and why.
- **Test results:** exact commands, exit codes, counts and warnings.
- **Cloud/unit verified:** facts supported by headless source/tests.
- **Real Hyprland verified:** ONLY actions truly tested on the target compositor, with evidence.
- **Not verified:** everything requiring unperformed physical or privileged tests, prominently displayed.
- **Manual acceptance:** numbered checklist for user using the actual Lua-based Hyprland, with output names used only as examples.
- **Known limitations:** no fake controls, fallback descriptions, version gates and blockers.
- **Recovery:** stop only SwiftShell; restore user settings and prior shell, with a verified safe command/GUI flow.
- **Next milestone:** precise dependency, not a vague “continue building the rest.”

If a dangerous integration is impossible to verify in the cloud, prepare source, mocks, read-only inspections and a safe experimental plan. **Do not auto-activate or call it production ready.** Owner may be unavailable: no need to ask a trivial question about button labels, but never interpret owner absence as permission to change hardware modes, shortcuts, notification ownership or system startup.

### Example acceptance response structure

    Milestone: M4.2 — Bar configurator
    Implemented: Slider updates bar height, derived typography/icons, exclusive zone and persists value.
    Automated: scripts/check.sh PASS; bar-scaling unit 18/18; QML root PASS.
    Real Wayland: NOT RUN (cloud environment does not provide Hyprland).
    Manual tests: 22/28/52px, secondary output at 1.5x, fullscreen vs maximize, false->true reserve.
    Safety: No edits to ~/.config/hypr, Noctalia, services or autostart.
    Rollback: Revert PR or restore prior Settings snapshot, stop SwiftShell path only.

---

## 14. Definition of initial public release

SwiftShell reaches a genuine initial public release only when:

1. An Arch/CachyOS Hyprland user with **arbitrary monitor names and geometry** can install with one guided command and get sensible output/workspace defaults.
2. A real movable/resizable Settings application exposes completed appearance, bar, wallpaper, displays, keybinds and common service controls without manual JSON/Lua editing.
3. The bar is truly transparent with optional refined readability gradient; floaters are individually rounded, coherent and use genuine blur on systems verified to support it, with honest fallbacks elsewhere.
4. The built-in default crimson wallpaper and user-chosen image/folder slideshow render per monitor, crossfade smoothly and drive reliable regional text contrast and optional restrained tint.
5. The user's manual text, icon, tint and gradient choices operate independently and persist through restart and auto-mode switching.
6. Spotlight opens on focused monitor via explicitly activated Super+Space; application search works with desktop entries and closes without focus traps.
7. Audio, network, Bluetooth, brightness where supported, tray, media, power and notifications are real integrations with tested absent-service behavior; notification ownership never silently conflicts.
8. Display arrangement and shortcut operations have verified opt-in, backup, staging, validation and revert. Disruptive actions do not strand user on a black monitor or without a launcher.
9. Install/update/restart/uninstall preserve other shells and user files, handle dependencies via package manager with consent, provide health diagnostics and offer rollback.
10. Automated test coverage and the **actual hardware test matrix** pass for declared supported capabilities. Critical unverified behavior cannot be marketed as stable.

**Scope boundary:** SwiftShell is a desktop shell, not a new compositor or OS. Advanced Hyprland window physics, compositor patching, speculative HDR and global app-menu extraction are later research features, not reasons to destabilize core functionality.

**North star:** One polished product; one installer; one Settings GUI; no dependency scavenger hunt; no fake functionality; no repeat of the QML/Wayland/Lua errors that plagued the prototype.

---

## 15. First action for Cursor after receiving this specification

1. Confirm M3.2's state on current `main` / open PRs. Do not assume it is merged.
2. Inspect actual SettingsStore/schema and QML root APIs. Identify the **minimum safe implementation for a real floating Settings window** and how the chosen QML/Qt version supports it. Put a brief feasibility note in docs/decisions.
3. Start **M4.0 only**, not wallpaper, notifications and everything at once. Build Settings schema foundation, native window smoke test, capabilities and shared components with real migration/load tests.
4. Do not modify Noctalia, the actual Hyprland Lua files, compositor blur settings, startup, notification daemon or hardware output modes.
5. Produce a reviewable PR with required test evidence, known blockers and exact on-machine verification checklist.
6. After M4.0 is accepted, follow the milestone sequence above. Revisit this specification at each PR start and update the lessons learned when failures are discovered.

**End of master specification.**
