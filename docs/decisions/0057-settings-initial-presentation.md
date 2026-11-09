# Draw Settings before the placement acknowledgement

Date: 2026-11-08

SettingsWindow mapped immediately but kept its complete content at opacity zero
until a 150ms placement timer and native helper completed. Hyprland could already
blur that transparent toplevel, producing a blurred blank stage before the UI.

The prepare rule already selects and centers the initial output. Draw content,
shadow and the rounded blur region immediately instead of hiding them behind the
later placement acknowledgement. The existing helper still verifies final
geometry and focus. No monitor settings, appearance values or timings changed.

An actual Settings opening on HDMI-A-1 reported contentOpacity=1, pageReady=true,
blurRequested=true while placementReady=false; final blur remained applied, and
the client was on HDMI-A-1. This samples initial UI state rather than claiming a
high-speed frame-by-frame recording. The live regression uses the real Settings
application, closes it and restores original focus; no fixture window is created.
Its reusable CLI retains the normal fullscreen guard. Output-targeted Settings
IPC and bounded presentation diagnostics make the startup regression observable.

The running shell had cached the old unloaded Settings component during early
tests. A scoped SwiftShell restart loaded the change before the passing HDMI
check. Offscreen tests load the real SettingsWindow and assert its content is
opaque and its page ready before any placement reply. Repository checks pass;
subjective startup smoothness on other hardware remains a manual check.

Recovery: revert this source commit and restart SwiftShell. No user preferences,
Hyprland configuration files or Noctalia state need restoring.
