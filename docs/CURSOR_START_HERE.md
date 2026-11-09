# Start a SwiftShell task

Read `MASTER_IMPLEMENTATION_SPEC.md`, the root README and `AGENTS.md` first.
The master spec is the product contract, not an instruction to rebuild the
prototype or restart M4.0. Follow the owner's current request.

1. Inspect branch, worktree, `origin/main` and in-flight changes. Preserve work
   belonging to other sessions. Use a small branch and reviewable commits.
2. Read `architecture.md`, `compatibility.md`, `testing.md`, `install.md` and the
   decisions relevant to the touched subsystem. `capability-matrix.md` records
   current limits; reports contain dated evidence rather than marching orders.
3. Trace the actual runtime entry, dynamic loaders, settings compatibility and
   packaging before editing. Verify version-dependent APIs before using them.
4. State the smallest deliverable, desktop risks and validation plan. Implement
   the requested slice, with regressions for defects. Avoid speculative rewrites.
5. Run `scripts/check.sh` and relevant focused checks. Native tests are opt-in;
   interactive tests must pass `tests/live/fullscreen_guard.py` first. Never
   bypass an active fullscreen game to create windows, move focus or send input.
6. Commit verified work. Merge or activate only when authorized. Do not change
   Noctalia, live Hyprland configuration, displays, binds, autostart or service
   ownership without the owner's explicit authorization and a recovery plan.

Keep the shared restrained visual language, real backends, truthful capability
states and hardware-independent logical geometry. This applies to maintenance
as well as feature work.

Report the actual changes, files, exact checks/results, hardware checks not run,
remaining limits and rollback. Follow the master spec's completion fields for
substantial feature PRs. A green offscreen suite is not a compositor pass.
