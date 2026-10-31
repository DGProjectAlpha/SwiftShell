# SwiftShell

> **Status:** M2 and the M3 launcher are in `shell/`. On the CachyOS Hyprland session, with Noctalia stopped, SwiftShell has loaded and the bar has rendered. Workspace switching works after the Lua dispatch fix. The launcher has opened and did not find Dolphin or Helium; that discovery path is changed and has not been relaunched. Cloud checks do not show pixels and do not launch applications. Noctalia is its own `noctalia` executable, not a `qs` process.
>
> **Purpose:** A clean, understated, keyboard-first, fully integrated desktop shell built with **Quickshell + Qt 6/QML** for **Hyprland on Arch-based systems**. The reference workstation is CachyOS; the installer is not limited to that one machine.
>
> **Non-negotiable:** Do not damage, overwrite, disable, or silently reconfigure the user's working **Noctalia** installation or existing **Lua-based Hyprland** setup.

## 0. READ THIS BEFORE WRITING CODE

SwiftShell is **not** another Material Design desktop, a Waybar skin, a widget dashboard, a Hyprland distribution, or a rewrite of the window compositor.

Build an original, integrated desktop shell offering the convenience of Noctalia with a radically quieter visual language:

- **Zero permanent chrome beyond a genuinely transparent top bar.**
- **No opaque or colored strip** behind that bar. A *subtle top-edge readability gradient* is an optional, independent layer, not a bar-shaped background.
- **Monochrome, restrained, flat UI** with adaptive readability.
- **Floating, blurred contextual panels** opening from bar actions. Popovers should feel like translucent optical surfaces, not colored cards.
- **Compact spacing, crisp typography, carefully weighted icons, minimal outlines.**
- **No excessive pill shapes, rainbow accents, glowing outlines, giant toggles, decorative cards, or Material You styling.**
- **Excellent interaction**, not just a screenshot-friendly theme: working launch/search, notifications, audio, network, display management, shortcut editing, and a trustworthy recovery path.

**Priority order:** (1) Preserve user's current system; (2) correct behavior; (3) interaction quality; (4) visual quality; (5) fancy effects.

**AI coding agents: never interpret a long spec as permission to implement all features in one pass.** Begin with a read-only environment audit, document verified capabilities, then build a small testable vertical slice. Make commits per milestone and report remaining unknowns.

---

## 1. Product vision and principles

The intended feel is somewhere between macOS's controlled visual density, a refined minimalist Linux rice, and an iOS-style separation of sharp foreground content from soft wallpaper/background layers. **It is not an attempt to clone macOS or iOS pixel for pixel.** “Liquid glass” describes the desired cleanliness and material restraint, *not* a hard requirement for physically accurate refraction.

Principles:

1. **Invisible until needed:** Bars and indicators disclose essential status; controls appear on demand.
2. **Function over decoration:** If a border, gradient, shadow, or blur does not improve hierarchy or readability, remove it.
3. **Low cognitive load:** No idle animations, flashy hover changes, unrelated visual motion, or gratuitous focus dimming.
4. **Keyboard-first, mouse-capable:** Preserve fast keyboard workflows. All major controls must also be reachable using a mouse.
5. **Tight, consistent geometry:** A coherent spacing, type, radius, and motion system. Avoid enormous padded widgets.
6. **Adaptive but predictable:** Wallpaper-driven tint is subtle and must preserve readable contrast. Provide neutral and manual overrides.
7. **Integration without replacement:** SwiftShell is a layer on the existing Hyprland session. Hyprland manages windows; SwiftShell implements shell surfaces and settings interfaces.
8. **Real functionality:** UI must not display dummy controls pretending to work. Label incomplete capabilities and gate them appropriately.
9. **Recoverability:** Every potentially disruptive setting has validation, backup, preview, and rollback.
10. **Performance:** The shell should remain responsive during high-refresh gaming and other GPU-heavy workloads.

### Explicit anti-goals

- Creating a new Wayland compositor, replacing Hyprland, replacing CachyOS.
- Rebuilding application widgets for services the system already provides.
- Copying Noctalia's source or UI wholesale.
- Shoving a standalone Waybar+Rofi collection together and calling it a complete shell.
- Requiring an always-on online AI service for ordinary search, launch, and settings actions.
- Hardcoding the user's personal desktop paths, monitor geometry, or shortcuts into reusable components.
- Forcing unsupported global application titlebar/menu behavior.
- Deploying unverified Hyprland plugins merely to achieve screenshots.
- Auto-installing random packages, modifying system services, or changing login/autostart without explicit approval.

---

## 2. Known target workstation and assumptions

The following details come from earlier configuration work. **Treat them as reference context, not proof of current runtime state.** Inspect locally and record actual versions, connector names, APIs, and monitor properties before integration.

| Item | Known context |
|---|---|
| Distribution | CachyOS, Arch-based |
| Session | Wayland / Hyprland, Lua-based configuration |
| Existing shell | Noctalia, started as the `noctalia` executable. It is Quickshell-based and is not a `qs` process to kill |
| GPU | NVIDIA RTX 4070 |
| Primary | DP-1, 2560×1440, approx. 164.83 Hz, historically scale 1.0 |
| Secondary | HDMI-A-1, 1920×1080, 60 Hz, historically scale 1.5 |
| Workspace mapping | DP-1: 1–3; HDMI-A-1: 4–6 |
| Monitor placement | Primary on left; secondary on right, as previously configured |
| Existing main binds | ~/.config/hypr/config/binds.lua |
| Existing decorations | ~/.config/hypr/config/decorations.lua |
| Existing monitor settings | ~/.config/hypr/config/monitors.lua (verify file exists) |
| Existing gap values | gaps_in = 3, gaps_out = 8, previously observed |
| Keyboard | Compact 60% keyboard: do not require arrow keys for core flows |
| Preferred browser | Helium |
| Preferred terminal | Kitty |
| Past focus choice | follow_mouse=0; user later described mouse-hover focus, so **do not assume desired policy** |

**Do not** blindly copy commands from standard Hyprland tutorials: this setup uses a Lua configuration/dispatch wrapper, and standard `hyprctl dispatch ...` syntax previously produced Lua parsing errors. Determine the available command API on this machine; preserve working configuration.

### Existing shortcut behavior to preserve

The user designed a specific 60% keyboard-first scheme. **Read the actual binds.lua and treat that file as authoritative**. Historical desired actions:

| Shortcut | Intent |
|---|---|
| Super+Q | Close window |
| Alt+Space | Toggle floating |
| Super+F | Fullscreen |
| Super+D | Maximize within layout, if still configured |
| Super+Space | Launcher, currently assigned in working session; SwiftShell should use this only after an explicit, reversible bind handoff |
| Super+Return | Kitty |
| Super+W | Browser |
| Super+1 through 6 | Switch workspaces |
| Super+Shift+1 through 6 | Move window to workspaces |
| Super+Tab | Window switcher |
| Super+L | Lock |
| Super+Z | Settings |
| Super+X | Control center |
| H/J/K/L combinations | Focus/navigation; inspect actual mappings |

The existing setup may differ in details. No agent is authorized to overwrite this mapping during initial milestones.

---

## 3. Functional specifications

The requirements are split into **MUST** (initial product direction), **SHOULD** (normal roadmap), and **RESEARCH** (may require Hyprland changes or limitations). They are *not* all required for the first prototype.

### 3.1 Top bar — MUST

**Visual:** Transparent, no visible background rectangle, no outlines or border, no permanent floating pill, no excessive rounding, no fake glass strip. Optionally add a full-width, subtle vertical shadow/gradient from top edge of display that fades into wallpaper and exists independently of the bar.

Suggested starting values (configurable, not hardcoded): 26–30 logical pixels tall; 8–12 px horizontal edge margin; restrained icon dimensions; minimal spacing. Important: logical pixels on 1.5x scale display are not physical pixels.

**Content:** Workspace indicators, focused app title when useful, system tray, time/date, network, volume/device, Bluetooth, battery/power when applicable, media/now playing, notification indicator, and optional hardware/resource indicators. Modules are user-toggleable and reorderable; don't force every module to show.

**Interaction:** Click opens contextual panel or performs the documented action. Hover only produces modest feedback, not giant animations. Support tooltip, keyboard navigation, Escape to close, outside click to dismiss. Panels should follow the clicked module and remain inside monitor bounds. Workspaces accurately reflect the associated monitor. Long titles and hidden modules must not cause overflow.

**Tests:** No bar-colored band; correct placement at both scales; no forced permanent focus; no accidental reservations or overlapping maximized windows; tray actions work; unplugging/reconnecting the secondary monitor does not crash the shell.

### 3.2 Popovers / material system — MUST

- Soft background blur that resembles Gaussian defocus; do not claim physical refraction if not implemented.
- Flat, crisp button surfaces, mostly monochrome foreground.
- Optional restrained tint derived from wallpaper, with manual neutral tint and fixed-color alternatives.
- Strong text contrast on bright and dark wallpaper; translucent panels need a fallback scrim.
- No gratuitous strokes, double shadows, nested pill buttons, huge tile cards, or redundant headings.
- Small, consistent corner radii (initial suggestion 6–12 logical px depending on surface).
- Subtle, short entrance and dismissal transitions; respect reduced-motion mode.
- Blur, opacity, tint, contrast, corner radius, shadow, and animation controls should be configuration-backed.
- **Technical caveat:** QML alpha transparency is not equivalent to compositor background blur. Validate the compositor protocol/effect support and a fallback when the desired blur is unavailable.

### 3.3 Spotlight-style launcher — MUST (early milestone)

Triggered by Super+Space **after safe, explicit keybind handoff**.

- Centered compact floating blurred panel, with prominent input and immediate search results.
- Empty query state: useful pinned/recent applications and macOS-like compact app grid; settings and power entry points.
- Search prioritizes applications, then files, commands, settings, and contextual actions.
- Intelligent intent routing **without depending on a cloud model**: exact/prefix/fuzzy application matches; path detection; arithmetic or units via safe built-in parser; settings keywords; file indexing from established local sources; web search as deliberate opt-in action.
- Keyboard flows must be excellent on a 60% layout: typing, Tab/Shift+Tab, Enter, Escape, and optionally HJKL-compatible list navigation without hijacking text entry.
- Show clear category labels and avoid surprising results ordering. Allow search scope filtering.
- Applications: prefer proper desktop-entry launching with correct Exec semantics; no shell string interpolation.
- Files: avoid indexing protected directories, secrets or private content without user choice. Use XDG user directories, conventional index APIs or scoped search with limits. Never automatically upload indexes externally.
- Commands: dangerous execution must never occur merely because a query resembles a command. Separate command mode; distinguish system actions; require appropriate confirmation.
- Power actions: explicit confirmations for disruptive operations unless user intentionally changes preferences.
- Performance: debounce costly search sources, cancel stale queries, keep typing responsive, cache icon/desktop entry metadata.
- Provide helpful empty/error states rather than blank panels.

### 3.4 Settings GUI — MUST (phased)

**General:** A real settings application/panel, not a static design mockup. Clear navigation (Appearance, Keybinds, Displays, Audio, Network, General; additional panels later). Show current persisted values and errors. Controls have tooltips and accurate capabilities.

**Appearance:** Transparency, defocus strength, tint source, text contrast override, radius, top gradient, spacing, fonts, icon scale, animation and reduced-motion preference; previews update safely; commit/revert semantics for high-impact changes.

**Keybinds:** A visual editor that **reads the actual Lua-based Hyprland configuration**. Display shortcuts, actions, conflicts, modifiers, and affected scopes. Capture shortcuts without hijacking reserved key events. Do not naïvely regex-replace arbitrary Lua files or overwrite hand-written mappings. Preferred approach: managed generated include/overlay with an explicit opt-in integration point, or a structural parser/API validated against installed configuration and then atomic write. Provide diff preview, backup, syntax validation, revert, conflict detection, and reload confirmation. **Never let the GUI silently destroy binds.lua.** For unmanageable custom Lua expressions, expose them read-only with honest limitations.

**Displays:** Use live Hyprland/display state, not assumed monitors. Show arrangement, resolution, refresh rate, scale, rotation, position, and available HDR-related controls only when actually supported. Apply changes with a revert countdown and guaranteed recovery path. Disconnect/reconnect must be tolerated. Do not invent modes or claim 10-bit/HDR support without verification. Account for DP-1 1440p high refresh, HDMI 1080p scaling, NVIDIA and mixed DPI.

**Audio:** PipeWire/WirePlumber-compatible readouts through supported interfaces; sink/source devices, default device, output/input levels, per-application streams, mute, microphone permissions where available, device descriptions, hotplug, and persistence. Avoid directly writing to random daemon config files.

**Network:** Prefer NetworkManager over improvised shell pipelines, with Wi-Fi status, discovered SSIDs, connection state, Ethernet, VPN if available, basic troubleshooting, and safe handling of credentials. Avoid logging network secrets. Bluetooth may be separate or integrated.

**General:** Version, diagnostics, shell restart, export/import settings, backup status, update preferences (do not build self-updater initially).

**Security rule:** All privileged or destructive operations require deliberate user action and appropriate system authorization. No background privilege escalation.

### 3.5 Notifications, system tray, and media — SHOULD

- Proper notification protocol ownership; avoid running two notification daemons in a live session.
- Queues, timeouts, urgency, actions, history/privacy options, Do Not Disturb.
- Compact notification presentation; no giant bright cards.
- Tray/menu support with reliable icons and click handling.
- Media player controls via MPRIS or supported APIs; idle state should not clutter bar.
- Time/date and calendar panel with configurable locale and 12/24-hour time.

### 3.6 Hyprland window appearance — SHOULD, separate integration milestone

User wants:

- **No visible Hyprland border outlines.**
- **Rounded corners on windows.**
- **No inactive-window fading/opacity reduction.**
- **Window gaps showing a blurred wallpaper treatment** rather than sharp portions of wallpaper.
- **No separate shell-drawn minimize/maximize/close controls.**

Implementation ownership:

- Hyprland controls window rounding, compositor decorations, focus and animations.
- SwiftShell can offer a GUI to manage supported settings after opt-in.
- **Application-owned titlebars and client-side decoration buttons are application-specific.** Do not claim the shell can remove every app's titlebar buttons.
- App-level menu actions (File/Edit/etc.) cannot be universally extracted from all GTK, Qt, Electron and Chromium applications. Global menu support is optional research with honest fallbacks.
- Wallpaper blur **between empty tiled windows** is not the same as blur behind a translucent window. Prototype a sharp wallpaper layer plus a pre-blurred wallpaper layer or another carefully validated background composition technique. Do not assume compositor blur applies to empty gaps; test wallpaper changes, differing displays, transitions, and performance.
- Ensure any wallpaper technique leaves expected desktop/background behavior intact.
- Clarify focus policy before changing it: previously hover-to-focus was deliberately disabled, despite a later description suggesting active-on-hover.

### 3.7 Window movement and workspace edge gestures — RESEARCH

**Desired UX:** With three tiled windows, holding Super and dragging one should rearrange its slot, with smooth elastic/wavy settling. Dragging Super+window to the monitor edge should move it to another workspace.

**Reality:** Native Hyprland can perform some mouse-driven tiling rearrangement. Physically spring-like window animation and screen-edge workspace handoffs may demand compositor support, carefully constrained plugins, or custom integration. **Quickshell does not own the geometry and animation physics of arbitrary application windows.**

Research native Hyprland semantics, supported dispatchers/IPC and available plugin APIs for the exact installed version. Prefer native capabilities. Explicitly mark unknown/unsupported behavior; do not modify compositor code during early milestones. Avoid rapid workspace flipping while dragging near a boundary; design dwell, dead-zone and cancellation behavior if feasible. Keep keyboard moves as the reliable alternative.

---

## 4. Architecture and boundaries

Proposed stack:

| Layer | Responsibility |
|---|---|
| CachyOS / systemd user session | OS, services, user startup |
| Wayland + Hyprland | Compositing, displays, window layout, focus, workspaces, animations |
| Quickshell / Qt 6 / QML | Bar, launcher, popovers, notifications, shell UI, settings surfaces |
| Native Quickshell integrations | Hyprland, tray, audio, media and other supported interfaces; verify actual available imports |
| OS service adapters | NetworkManager, PipeWire/WirePlumber, BlueZ, login/session services where required |
| SwiftShell application services | State, preferences, search/indexing, diagnostics, safe config edits |
| Optional narrowly scoped helper | Only when a well-defined missing API demands it; must have tests and documented security model |

**Avoid command-spawning for everything.** Prefer typed APIs/IPC and event-driven subscriptions. Shell commands are an audited fallback, not the main architecture. If subprocesses are needed, use structured arguments and timeouts, never concatenate untrusted input into a shell.

Suggested tree (proposal; evolve as needed and document changes):

```text
SwiftShell/
├── README.md
├── AGENTS.md
├── LICENSE                  # Add only after selecting a license
├── docs/
│   ├── architecture.md
│   ├── design-system.md
│   ├── requirements.md
│   ├── compatibility.md
│   ├── testing.md
│   ├── decisions/
│   └── screenshots/
├── shell/
│   ├── shell.qml             # Main Quickshell entry (verify runtime CLI/config conventions)
│   ├── components/           # Primitives: text, icons, panel, buttons, focus, etc.
│   ├── bar/                  # Top bar and modules
│   ├── launcher/             # Search, apps grid, result providers
│   ├── panels/               # Popover surfaces
│   ├── settings/             # GUI pages
│   ├── notifications/
│   ├── services/             # Typed adapters and state holders
│   ├── themes/               # Tokens and wallpaper-derived palettes
│   └── config/               # User preferences/schema/defaults
├── scripts/                  # Non-destructive development tooling
└── tests/                    # QML/unit/integration/smoke tests
```

### Required architectural practices

- Design tokens, not scattered hardcoded RGB values; centralize typography, spacing, opacity, radius, animations, shadows and contrast thresholds.
- Clearly separate UI from system adapters and persistent configuration.
- Treat output/monitor assignment as dynamic; use stable identities and monitor-change events.
- Use model/view separation for lists and search results. Avoid business logic inside component declarations.
- Never assume a network, microphone, Bluetooth device or battery is present.
- Handle no-screens, one-screen, scale changes, disconnects, stale IPC, missing icons, and unavailable services.
- Avoid duplicate ownership of tray/notification/global shortcut integrations when Noctalia is still running.
- Prefer bounded memory allocations, explicit cleanup of subscriptions, and event-driven updates over polling.
- Keep development mode separate from installed/switch-over mode. No automatic takeover.

---

## 5. Design tokens (initial targets, not final art)

This is a constraint system, **not** a fully approved visual design.

| Token | Initial direction |
|---|---|
| Bar height | 26–30 logical px, configurable |
| Top bar background | 100% transparent |
| Top-edge readability gradient | Optional, subtle, fades vertically; not a rectangular bar fill |
| Base palette | Monochrome neutral with wallpaper tint option |
| Accent | Minimal, functional only; no colorful default Material palette |
| Panel opacity | Adjustable, e.g. moderate translucent tint with robust contrast |
| Panel blur | Configurable / graceful fallback if unsupported |
| Panel radius | Approx. 8–12 logical px |
| Small control radius | Approx. 4–8 logical px |
| Borders | Default no decorative strokes; only if required for accessibility/focus |
| Shadows | Soft and subtle |
| Typography | Compact, accessible, consistent weights; no giant headings |
| Motion | Short restrained ease; disabled/reduced when requested |
| Iconography | Consistent stroke weight; don't mix unrelated icon packs |
| Density | Compact by default; allow comfortable mode |
| Accessibility | Contrast, focus indications, screen scale, keyboard navigation and reduced motion must survive aesthetic restraint |

**No permanent desktop dock is required.** Launcher handles apps. Do not introduce a dock merely to look like macOS.

### Visual review rubric

Reject designs that show: a colored backing strip behind the top bar; nested rounded tiles; loud wallpaper-color accents; thick visible borders; oversized system controls; cartoonish bounce; intrusive shadows; redundant sidebar navigation; or unnecessary information permanently pinned to the screen.

Accept designs that demonstrate: content hierarchy; readable text against challenging backgrounds; responsive scaling; unobtrusive chrome; crisp focus state; intentional alignment; usable click targets; and subtle animation.

---

## 6. Configuration design

Configuration **must not require editing QML to change common settings**.

Use versioned, documented, validated user preferences with default values and migration logic. Choose an appropriate existing Quickshell/Qt-backed format after verifying current APIs (JSON/TOML/other); avoid arbitrary eval and unsafe dynamic code generation.

Config layers:

1. Immutable built-in defaults.
2. User settings persisted in an XDG-appropriate location.
3. Optional per-output overrides.
4. Temporary preview state (must not corrupt persisted state).
5. Distinct Hyprland-managed integration settings, applied only via validated opt-in.

Changes to low-risk settings (bar size/appearance) can apply live; high-risk changes (display mode/keybinds/compositor rules) require preview/validation/rollback. Write settings atomically to prevent corruption.

Do not make SwiftShell dependent on copying or modifying Noctalia's private configuration.

---

## 7. Development, validation and safety workflow

### 7.1 Read-only environment audit (first local task)

Before installing packages or touching any config, capture and document:

- Actual Quickshell version and supported CLI syntax/imports.
- Actual Hyprland version and Lua dispatcher/config integration.
- Actual monitor descriptions, resolutions, scaling, workspace placement, HDR/color state.
- Existing Noctalia startup method, running process, notification owner, shell services and bar reservations.
- Available Qt/QML development tools, PipeWire, WirePlumber, NetworkManager, BlueZ, user session manager.
- Existing working shortcut maps and possible launcher conflicts.
- Available screenshot, logs and recovery options.

**Use read-only commands and show findings before proposing modifications.** The agent should not ask the user to repeat values already known unless current verification is essential.

### 7.2 Isolation-first development

- New project lives in its own Git checkout; do not replace `~/.config/quickshell/noctalia` or any existing profile.
- Run as a separate named Quickshell config, using **CLI syntax verified on installed version**.
- For Stage A, render components in an independent preview/test harness, ideally without becoming a notification daemon or reserving screen edges.
- For Stage B, target HDMI-A-1 only; avoid placing two competing bars on that display or intercepting Noctalia's core services. Coordinate a temporary preview mode or one-module-at-a-time testing.
- For Stage C, explicitly switch shell ownership, with one-command Noctalia recovery. Keep a terminal or fallback TTY option.
- Do not alter login/session autostart until approved after stable local testing.
- Preserve Snapper snapshot/recovery procedure where available; Git alone cannot undo live system configuration changes.

### 7.3 Tests required at each milestone

**Static checks:** QML parses/loads using available tools; imports resolve; lint/format validation; no accidental absolute user paths, private secrets, or destructive scripts.

**Unit tests:** Theme contrast decisions, config validation/migration, workspace-to-monitor mapping, shortcut conflict detection, search provider prioritization, and sanitization.

**Integration tests:** Hyprland workspace events, monitor detach/reattach, audio/network reconnect, tray icons/menus, notifications, search launch behavior, state persistence.

**Manual tests:** 2560×1440 @ ~165 Hz and 1920×1080 @ 1.5 scale; bright/low-contrast wallpaper; hover/click/keyboard dismiss; several tiled windows; fullscreen games; idle GPU usage; screen lock/unlock; suspend/resume; HDR-related cases only with confirmed support.

**Safety tests:** SwiftShell process exits without taking Hyprland down; Noctalia can restart; shell fails safely if adapter unavailable; roll back bad display mode; no stale compositor config modifications after interrupted write.

**Performance:** Capture baseline vs SwiftShell CPU/GPU usage, startup latency, bar interaction responsiveness, animations under GPU load, and unnecessary polling. Do not assert benchmark numbers until measured.

### 7.4 Definition of done (per feature)

A feature is done only when:
- Behavior described in requirements works, including failure states.
- Relevant automated checks pass; manual visual checks are recorded where appropriate.
- It behaves correctly at both monitor scales or has a documented limitation.
- Accessibility/keyboard operation is considered.
- No existing desktop config was changed unexpectedly.
- User-facing settings persist and can be reverted.
- Docs and changelog/decision notes reflect reality.
- Changes are committed in a small, reviewable commit.
- The agent explicitly distinguishes **implemented**, **tested**, **not tested**, and **blocked**.

---

## 8. Milestones and scope control

### M0: Repository + audit + running prototype shell

Deliver: clean folder structure, AGENTS.md, docs, verified local launch/stop instructions, minimal shell entrypoint, development mode. No system config changes. Do not capture shortcuts or start a second notification daemon.

Acceptance: starts and exits reliably, logs errors, and Noctalia remains available.

### M1: Truly transparent bar

Deliver: bar on HDMI-A-1 only, workspace indicators 4–6, clock, basic focused-window indicator; responsive visual tokens, module structure, keyboard-safe interactions.

Acceptance: completely transparent background, no faux bar rectangle; correct scaling and workspace data; no visual conflicts; survives monitor hotplug gracefully.

### M2: Popover design system + control center

Deliver: blur-compatible panels and neutral fallback, flat controls, popover positioning/dismissal, audio/network status mock adapter then live read-only adapter, appearance preview.

Acceptance: legible on busy wallpaper; no false functional controls; panels close properly; no focus trapping.

### M3: Launcher

Deliver: Spotlight input, application discovery/launch, pinned/recent app grid, ranked result providers, keyboard flows, settings/power entry points. **Only after user approval**, swap Super+Space binding safely.

Acceptance: launcher fast, searchable, dismissible; current keybinds preserved; dangerous commands never auto-run.

### M4: System services

Deliver: audio/per-stream controls, network interfaces, Bluetooth if available, tray, media, notifications with ownership handoff plan, calendar/date, power.

Acceptance: service failures handled; no duplicate notification ownership; no leaked secrets.

### M5: Settings suite

Deliver: appearance, keybind management, displays with rollback, audio, network, diagnostics. Each subsystem includes its own safe adapter, tests, and failure states.

Acceptance: every visible setting truly works; Lua config preservation; no irreversible display or shortcut change.

### M6: Window aesthetics

Deliver: reversible Hyprland integration for borders/rounding/focus/opacity, prototype wallpaper-gap background solution and performance verification.

Acceptance: visual behavior matches requirements without breaking fullscreen/HDR/games.

### M7: Research features

Research only initially: wavy drag spring animation, edge workspace handoff, app-owned decoration suppression/global menus, advanced optical effects. Implement only when supported by verified APIs and user approval.

Acceptance: prototypes demonstrate behavior in local compositor, no risky permanent patches, fallback always available.

### M8: Polish + optional switch-over

Deliver: migration documentation, startup/recovery script, diagnostics, extensive local tests, performance review, accessibility polish.

Acceptance: user explicitly opts in; Noctalia remains readily restorable.

---

## 9. Git workflow for human and AI contributors

- Work in a feature branch for nontrivial changes. Make small commits.
- Start with a plan and an explicit statement of files being changed.
- Do not rewrite working features to “clean things up” without tests and approval.
- No force-push, destructive clean/reset, or overwrite of existing user config.
- Keep `AGENTS.md`, requirements, and decision records updated when scope changes.
- Commit generated lock/config files only when they belong in the project; do not commit logs, secrets, local paths or cached indexing data.
- If a design choice is ambiguous, implement the safer minimal default and document the decision.
- Prefer a complete small working slice over a large forest of placeholder files.
- Validate locally before reporting success; cloud-only checks cannot verify NVIDIA/Hyprland rendering.

---

## 10. Risks, limitations, and open decisions

| Topic | Current understanding / required action |
|---|---|
| Quickshell version/imports | Verify installed versions before writing version-specific QML |
| Hyprland Lua integration | Inspect actual config and supported dispatcher; do not assume stock config syntax |
| Background blur | May depend on Hyprland compositor configuration; have a neutral fallback |
| Empty gap wallpaper blur | Requires a background strategy, not simply window blur |
| Global app menus | No universal support for all client toolkits |
| App-owned titlebar buttons | Cannot universally suppress across all apps from a shell |
| Window spring physics | May require compositor-level work/plugin; treat as experimental |
| Edge-drag workspace handoff | Not automatically provided by Quickshell; research local compositor support |
| Hover focus | Conflicts with prior preference; maintain current behavior until user resolves |
| HDR / mixed monitors | Verify actual renderer capabilities; avoid speculative setting changes |
| Notification daemon | Only one owner; preview safely while Noctalia runs |
| Launcher global bind | Existing Super+Space remains in place until explicitly switched |
| Privacy | Search indexes/local logs and network credentials must be treated as sensitive |
| License | User has not selected a license yet; do not invent one |
| Branding | Name SwiftShell approved as repository name; icon/wordmark not specified |

---

## 11. What the coding agent should do first

**Initial agent prompt:**

> Read README.md and AGENTS.md completely. Do a read-only audit of the local Quickshell/Hyprland environment and the existing Noctalia configuration. Confirm that this is the intended SwiftShell Git checkout. Do not install packages, change any live desktop settings, modify autostart, or take ownership of notifications or global shortcuts. Propose the minimum modular structure needed for a transparent top bar prototype restricted to HDMI-A-1. Implement only M0 and M1 in small testable commits. Include exact launch and shutdown instructions based on the installed Quickshell version, plus a report separating verified facts from assumptions. Stop before any live desktop takeover.

**Expected first output:** A version/compatibility audit, the minimal project tree, an actual loadable prototype (not only diagrams), tests or reproducible manual checks, and a safe fallback plan.

---

## 12. Project status

- [x] GitHub repository created: **DGProjectAlpha/SwiftShell**
- [x] Initial README created
- [x] Detailed product/engineering specification established
- [x] M0/M1 prototype source, launch/stop scripts, and logic tests added
- [x] Install, activate, deactivate, and uninstall scripts added (not verified on Hyprland)
- [x] M2 theme tokens, popover host, calendar, and control-center foundation added
- [x] CachyOS launch observed: bar rendered with Noctalia stopped; calendar and control center opened
- [x] CachyOS workspace switching observed after the Lua dispatch fix
- [x] M3 launcher opened on CachyOS and failed to find Dolphin and Helium; discovery now follows `applicationsChanged` and has not been relaunched
- [ ] Bar reservation, theme icons, launcher focus return, and the refreshed catalog retested on CachyOS
- [ ] M3.2 centered Spotlight on the focused monitor retested on CachyOS
- [ ] Super+Space handoff applied by hand after that retest, using `docs/launcher-shortcut.md`
- [x] M4.0 settings window source: one `FloatingWindow`, Appearance controls that already persist, schema version 2 with a backup before migration
- [ ] M4.0 settings window shown, moved, and resized on a Hyprland session
- [x] M4.1 settings search and the remaining live appearance controls, in source
- [x] M4.2 bar height, derived metrics, and module order, in source
- [ ] M4.2 bar height and reserved strip measured on a Hyprland session
- [x] M4.3 backdrop blur reported unavailable; surfaces keep the scrim
- [ ] M4.3 checkerboard screenshot behind a panel
- [x] M4.4 per-output wallpaper surface, fit modes, and image page, in source
- [ ] M4.4 wallpaper shown on a Hyprland session, including crop and a missing file
- [x] M4.5 slideshow state machine, png top-edge contrast, and manual colors, in source
- [ ] M4.5 slideshow and contrast shown on a Hyprland session
- [x] M4.6 display arrangement preview, in source, with apply disabled
- [ ] M4.6 diagram compared with a real Hyprland layout
- [x] M4.7 preferred chords stored in settings, in source, with no bind installed
- [ ] M4.7 shortcut recording shown on a Hyprland session
- [x] M5.1 PipeWire source and streams, MPRIS controls, and tray items, in source
- [ ] M5.1 audio, media, and tray used on a Hyprland session
- [ ] M4.1 search, undo, and appearance changes shown on a Hyprland session
- [ ] Local Quickshell and Hyprland versions recorded from `qs -V` and `Hyprland --version`
- [ ] Visual rendering of the stabilization fixes verified
- [ ] Any live desktop integration beyond the separate `qs --path` launch approved

**Current claim:** The shell has run on the reference Hyprland session. The bar, calendar, and control center were visible with Noctalia stopped, and workspace switching works there. The launcher opened on that session and did not list Dolphin or Helium. The catalog now refreshes from Quickshell's `applicationsChanged` signal. That refresh, theme icons, and bar reservation have not been relaunched on the session. M3.2 centers Spotlight and chooses the focused monitor in source. That placement has not been launched on the session. M4.0 adds a settings `FloatingWindow`. The schema is version 3. M4.1 adds search, undo, and the appearance values the theme already uses. M4.3 reports backdrop blur as unavailable. M4.4 draws one background layer per output from the packaged crimson image or a chosen png, jpeg, or webp file. M4.5 adds a slideshow and samples png pixels along the top edge for text and the bar fade. Jpeg and webp are not sampled. M4.6 draws a display preview and does not send layout changes. M4.7 stores preferred chords for Spotlight, Settings, and the control center and does not install them. M5.1 adds the PipeWire source, application streams, MPRIS playback, and status-notifier tray items behind loaders. That window, that layer, that fade, that diagram, that recording page, and those services have not been shown on a session. Cloud checks do not launch applications, move a toplevel, or edit Super+Space.

## 13. Running the M0/M1 prototype

Full notes: `docs/architecture.md`, `docs/compatibility.md`, `docs/testing.md`.

On the CachyOS machine, install Quickshell from the distro packages, then from this checkout:

```sh
scripts/check.sh
scripts/launch.sh
scripts/stop.sh
```

`scripts/launch.sh` runs `qs --path` against `shell/` and does not edit Hyprland or Noctalia. `scripts/stop.sh` kills that path only. Noctalia is the `noctalia` executable. Do not stop it with a `qs` kill. A new settings file puts the bar on the focused monitor, or the first screen if focus cannot be read, and shows the workspaces Hyprland reports on that monitor. An existing `~/.config/swiftshell/settings.json` is not rewritten: a file that still names `HDMI-A-1` and workspaces 4–6 keeps that layout, and a file that still has `"reserveSpace": false` stays an overlay until that key is set to `true`. Leave `reserveSpace` `false` while Noctalia is also drawing on that output. The clock opens the calendar. The mark at the right opens the control center. Search opens Spotlight on the monitor focused at that moment. `scripts/request-launcher.sh` does the same through the existing request file and toggles it closed. None of those capture a global shortcut. Super+Space stays unchanged until `docs/launcher-shortcut.md` is applied by hand.

If this checkout already has a local `import "../components"` in `shell/bar/BarWindow.qml`, that line is on `main`. See `docs/testing.md` before pulling so the local edit is not lost or duplicated.

## 14. Install and remove

The distributable path is separate from the development launcher:

```sh
git clone https://github.com/DGProjectAlpha/SwiftShell.git
cd SwiftShell
./install.sh
swiftshell activate
swiftshell start
```

`./install.sh` copies SwiftShell into `$XDG_DATA_HOME/swiftshell` and adds a user launcher. It does not replace another Quickshell config. `swiftshell activate` registers a free config name and a desktop entry. `swiftshell deactivate` reverses that registration. `swiftshell uninstall` removes the installed files and keeps `~/.config/swiftshell` unless `--purge-settings` is passed.

None of these commands edit Hyprland startup, keyboard shortcuts, or system services. Details, the manual copy steps, and the draft AUR package are in `docs/install.md` and `packaging/README.md`. The installer has been exercised with stub commands in a temporary home directory. It has not been run on a Hyprland session.
