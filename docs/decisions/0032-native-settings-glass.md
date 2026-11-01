# Native Settings window and restrained glass

Date: 2026-11-01. Supersedes the preview limitations in decisions 0009–0012.

Settings uses a real Quickshell FloatingWindow, default 1000×700 logical pixels,
with native startSystemMove/startSystemResize and a shared compact monochrome
control system across all eleven pages. Navigation and search share one category
model. Existing settings and per-output workspace selections are preserved.

## Native integration

`WindowService.qml` serializes calls to `helpers/windowctl.py`. The helper selects
only the client matching the owning Quickshell PID, exact Settings title and
class. An owner-guarded temporary Lua window rule makes that client float with
no compositor border/shadow; it never writes user configuration. Closing Settings
removes the owned rule. After a crash the rule can survive until the next open or
compositor configuration reload, but matches only SwiftShell Settings.

Hyprland reports Qt's maximized hint even for floating clients. Controls use the
actual IPC fullscreen mode instead. Before native resize, the Qt hint is cleared.
Maximize/restore dispatches the compositor's maximized mode. Minimize moves only
Settings to a private special workspace; opening Settings restores its previous
workspace and activates it. This is necessary because native minimize requests
are ignored on this compositor. Normal size and position are atomically saved in
SwiftShell's own state directory and clamped to connected outputs on restore.

## Real effects and fallback

The verified stack is Quickshell 0.3.2, Qt 6.12.0 and Hyprland 0.57.0. Runtime
protocol discovery checks ext-background-effect-v1 and compositor blur enablement.
`BlurAdapter.qml` assigns a rounded Region to the window's BackgroundEffect attached
object. The JavaScript attached-property access works on this tested version.
Blur off additionally sets the exact client's `no_blur` property; removing the
region alone does not stop Hyprland's automatic blur. No global blur setting is
changed. Unsupported systems use a readable near-opaque surface and disable the
blur control. QtQuick.Effects RectangularShadow (Qt 6.9+) implements radius,
shadow opacity and softness; a failed effect loader disables its controls.

## Validation and recovery

See the dated native evidence in docs/testing.md. Pointer tests exercise all edges,
corners and window buttons. Controlled checkerboard captures distinguish actual
backdrop smoothing from transparency without capturing private application pixels.

Close Settings normally to remove its runtime rule. `scripts/stop.sh` selects only
this checkout. Restart with `qs -p /home/daniel/SwiftShell/shell --no-duplicate`.
No Noctalia, autostart, system service, shortcut or user-authored Lua changes are
part of this work. Displays rollback remains independently owned by displayctl's
watchdog, as documented in decision 0031.
