# Stable bar updates and a consistent color picker

Date: 2026-11-01. User-reported bar/color-picker flicker maintenance increment.

The old array-backed repeaters rebuilt live controls when workspace roles or
module visibility changed. An isolated native audit of the old implementation
created 23 module controls and 68 workspace controls during 15 appearance/urgency
updates and one module hide/show cycle. The keyed model creates 9 and 4: eight
initial modules, only the deliberately re-added module, and the original four
workspace buttons. Existing delegates update roles in place and survive reorder,
so pressed/hover state and live service components are retained.

The former QtQuick.Dialogs ColorDialog followed the system dialog theme and used
a separate native surface. Its replacement is a Qt Quick Controls item popup
inside Settings, with shared theme tokens, typography, buttons and focus states.
The saturation/value plane, hue control, neutral swatches and validated hex field
edit a local draft. Cancel/Escape discard it; Use color emits one opaque hex value.
Surface opacity stays independent. The popup does not create a Wayland client or
activate another window. Popup type is explicitly Item on Qt 6.8+ and uses the
same in-window default on older headless test Qt. Image/folder dialogs remain
native. Dropdowns share the same popup surface color.

Native pointer tests passed on DP-1 and HDMI-A-1 at scale 1.25: drag, cancel,
commit, unchanged Settings geometry and unchanged preferences while drafting.
A controlled checkerboard fully shielded the bounded visual capture. No external
application pixels were captured. Existing bar blur, workspace save/restart and
actual Super+Space/repeat/Escape regressions passed. Settings diagnostics now
include its real geometry-placement completion state so native tests wait for
startup restoration before sending pointer input.

Tests: mandatory QML color-picker suite (8 passed), keyed delegate suite (4),
existing static/JS/Python/QML/install checks; native bar-stability.py,
color-picker.py, bar-surfaces.py, test-workspaces-native.sh and launcher-shortcut.py.
The lifetime audit verifies native delegate retention with synthetic urgency
updates; it does not simulate GPU load or prove all NVIDIA flicker is impossible.
Human visual review under gaming/fullscreen and physical hotplug remain pending.

Backups: verified preferences and geometry in SwiftShell's own state directory,
backups/20261101T140941Z-flicker. Tests restore the user's current frosted bars and
persisted opacity, rather than forcing earlier transparent settings. No OS service,
monitor mode, autostart, Noctalia or user-authored Hyprland file changed. Reverting
this commit restores the old picker/model implementation; retained backups cover
preferences if needed. Next: roadmap B2 bar ergonomics and shared frosted popovers.
