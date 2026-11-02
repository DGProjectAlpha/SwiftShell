# Native power modes and a dedicated Power panel

Date: 2026-11-02. The Power page remains because this machine exposes genuine
Power Saver, Balanced and Performance modes through power-profiles-daemon 0.30.

A typed D-Bus adapter discovers profiles, active mode, inhibition/degradation and
holds. Changes use the daemon's ActiveProfile property with readback and an Undo
control. Missing or blocked profiles are disabled rather than simulated. A fixed
PropertiesChanged monitor runs while the page/panel is present; no sysfs writes,
package installation, service changes or polling are needed. Battery information
appears only when hardware provides it.

Settings and the new Power bar panel share compact profile controls. The panel
also provides the existing confirmed session actions. Spotlight uses supported
systemctl suspend/reboot/poweroff commands and loginctl lock-session; no shutdown,
restart, suspend or lock was executed during development.

Eight helper tests and five QML tests passed. A real-pointer Settings test changed
Performance to Balanced, verified D-Bus readback, then restored Performance and
verified it again. The daemon owns profile persistence; SwiftShell does not write
a separate pretend profile preference. Opening/closing the page and panel is
covered by native Settings/panel input tests. Recovery is the previous-profile
Undo or choosing the original mode; no operating-system files are modified.
