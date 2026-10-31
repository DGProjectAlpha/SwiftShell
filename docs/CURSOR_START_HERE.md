# Cursor — SwiftShell Implementation Kickoff

**You are implementing SwiftShell, not generating mockups.** The binding master specification is `docs/MASTER_IMPLEMENTATION_SPEC.md`. Read it in full, along with `README.md`, `AGENTS.md`, current tests, compatibility notes and architecture, before writing code.

## Immediate sequence

1. Inspect `origin/main` and open PRs. Confirm whether M3.2 Spotlight / hardware-independent monitors is merged and whether its acceptance criteria are met. Do not overwrite in-flight work.
2. Audit current code, version-dependent Quickshell/Qt APIs, settings schema, QML root loading and real hardware constraints.
3. Start **M4.0: Settings architecture and a real floating/movable/resizable window**. Don't build wallpaper, display editor and notifications into the same PR.
4. If the target Wayland runtime isn't available in your environment, do repository-only implementation, write precise tests and mark hardware-dependent claims **NOT VERIFIED**. Do not improvise a fake native window or pretend a translucent panel is Gaussian blur.
5. No changes to user's live Noctalia, Hyprland Lua configuration, displays, shortcut ownership, autostart or notification daemon without explicit authorization.
6. For every PR, follow Sections 0, 10, 11, 12 and 13 of the master spec: narrow vertical slice, test evidence, manual acceptance and rollback. Add a regression test for each discovered defect.
7. Update `AGENTS.md` to require reading `docs/MASTER_IMPLEMENTATION_SPEC.md` at the start of every future coding task. Retain the existing safety restrictions; do not replace them.

## Non-negotiable design

True transparent top bar with optional subtle contrast gradient. Individually rounded frosted floaters, monochrome accents, readable dynamic contrast, no outlines, no giant Material cards, no bouncy animations. One GUI for user configuration; no requirement to hand-edit JSON or Lua. Hardware-agnostic from first run.

## Completion format

Describe what **really works**, tests executed and their results, APIs/versions verified, **hardware tests not run**, known limitations, exact steps for the owner to validate, and rollback. A green headless test is not a real desktop pass.
