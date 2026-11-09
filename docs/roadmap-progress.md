# Remaining work and development status

The prototype and native desktop increments are merged on `main`. Current
implementation/evidence is summarized in [capability status](capability-matrix.md);
[decisions](decisions/) and [native validation](reports/native-validation.md)
retain dated rationale and observations. The master spec describes the long-term
product, not an instruction to rebuild completed milestones.

The 2026-11-08 maintenance pass removes obsolete runtime scaffolding and stale
entry-point guidance. It does not redesign the UI, migrate preferences or change
services. See the [cleanup audit](reports/repository-cleanup-2026-11-08.md).

## Technical debt and acceptance still open

- Physical hotplug, lock/unlock, suspend/resume, reboot, sustained GPU/resource
  profiling and single-monitor/laptop/different-scale acceptance.
- Real device authentication/pairing and broader service/device failure testing.
- Clean-user live install and an actual Arch package build. License, release tag
  and package checksum remain unresolved; do not publish the draft as ready.
- Optional persistent notification history needs a privacy/storage design.
  Richer Clock utilities remain future work; hardware brightness has no backend.
- Some native fixtures duplicate temporary-tree/input setup. Consolidation needs
  separate coverage of their different focus, authorization and cleanup semantics.
- Large SettingsStore, static-check and native-validation files remain. Splitting
  them needs a scoped change with compatibility/lifecycle coverage, not a cleanup
  rewrite. Dated records may contain historical limitations; current guides win.
- Settings aliases (`control`, `bluetooth`) and fallback decoders/dialog paths are
  intentional compatibility, not dead code. Review migrations before removing.

Take one user-authorized increment at a time. Backend/monitor experiments remain
outside this repository maintenance pass.
