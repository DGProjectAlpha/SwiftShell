# Display transactions and independent recovery

Hyprland 0.57.0, Quickshell 0.3.2 and Qt 6.12.0 are the locally verified backend.
The exact compositor source was inspected: `hl.monitor` clones an existing
exact-output rule before changing supplied fields. SwiftShell sends only changed
geometry fields, preserving the workstation's color/HDR settings and user files.
Unsupported compositor versions refuse Apply. Advertised modes, scale geometry,
unique connected outputs, overlap, coordinates and the last enabled output are
validated before mutation. Future wider version support needs native verification.

A stdlib Python helper is shipped inside `shell/helpers` so source and installed
layouts resolve identically. Its short-lived QML bridge talks to a per-session,
UID-restricted Unix socket. A detached watchdog saves an atomic, fsynced recovery
journal, owns a monotonic 15-second deadline, checks the originating shell's
PID/start time, verifies actual compositor state, and rolls back independently.
SIGTERM also attempts rollback. A watchdog crash leaves a durable pending journal
that the next watchdog recovers before any new operation. This is not a system
service and does not alter startup. Runtime Lua changes end when the user reloads
Hyprland configuration; accepted layouts are separately saved and restored only
on explicit request. User configuration remains authoritative.

The diagram uses effective logical dimensions after rotation/scale. Drag press
freezes both projection origin and scale until release, so movement cannot resize
monitor rectangles. Native modes and friendly names come from raw compositor IPC.
A custom-styled Qt Quick Basic ComboBox supplies usable dropdown behavior without
Material styling. An explicit Settings IPC action also enables native inspection.

Live two-monitor tests and limitations are recorded in `docs/testing.md`.
