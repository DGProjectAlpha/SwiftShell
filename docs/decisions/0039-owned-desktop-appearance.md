# Validated preferences and reversible desktop appearance

Date: 2026-11-02. Shared service foundation for the native desktop applications.

Preferences are validated from a raw FileView before changing live properties.
JsonAdapter is a model only: it cannot apply unvalidated file contents or decide
whether a disk write is necessary. A fixed Python helper receives the current
validated document through stdin, checks existing-file protection, writes a
private temporary file, fsyncs and atomically replaces settings.json. Duplicate
changes coalesce; persistence remains saving until the latest document reaches
disk. Known persisted/in-flight fingerprints distinguish own watcher events from
real external edits. Malformed/future files remain unchanged and cannot alter
current live values. Migration still requires an intact original backup.

This replaces two observable FileView cache failure modes: identical writes can
omit saved, and an externally changed file can disagree with the writer cache.
The native regression covers external edits followed by no-op and actual saves,
protection, migration, duplicate writes and restart readback. Disk work is
coalesced away from render-time slider updates. Window blur requests retain the
latest on/off state rather than a stale intermediate value.

DesktopAppearance manages only explicitly changed runtime options through the
verified Hyprland 0.57 hl.config API. Radius reaches normal application windows;
blur strength changes the compositor profile used by opted-in shell surfaces;
window borders can be disabled or sized independently. User Lua remains intact.
A restricted journal records original and pending values before mutation. Restore
covers interrupted operations, preserves unowned options, and rebases originals
when the owner reloads their configuration. Invalid recovery files are protected.
Application-specific window rules can override global defaults.

Wallpaper analysis uses an asynchronous Qt image decoder for PNG/JPEG/WebP and
samples the displayed crop, including letterboxing. Only the chosen file is read;
no application or desktop capture is used. A bounded PNG fallback remains when
Python Qt is unavailable. Regional foregrounds account for the bar material;
mixed/unknown backgrounds use a stable neutral readability fade. Manual contrast
remains available. Native hidden-bar tests verify actual colors and unchanged
module/workspace delegate lifetimes.

Recovery: `python3 shell/helpers/appearancectl.py restore` restores owned desktop
options, and the Appearance page exposes the same action. Own state is under
$XDG_STATE_HOME/swiftshell/desktop-appearance.json. Backups of current preferences
and state are retained in backups/20261102T111525Z-desktop-activation. No display
mode, user Lua, Noctalia, autostart or unrelated service is modified.
