# Per-monitor workspaces on Hyprland 0.57

The local 2026-10-31 audit used Quickshell 0.3.2, Qt 6.12.0 and Hyprland
0.57.0 on CachyOS. Read-only IPC returned seven workspaces: DP-1 owns 1–3
and `gaming`; HDMI-A-1 owns 4–6. All six numeric workspaces were persistent,
including the empty ones. Both monitors had active workspaces simultaneously.
The named workspace had `address: "gaming"` and **no numeric id**. The old
numeric-only Quickshell projection lost data and monitor/focus identity.

HyprlandModel now obtains monitors, workspaces and workspace rules through
three fixed `hyprctl -j` argv arrays. It coalesces relevant native raw events
with a one-shot 80 ms timer; there is no periodic polling or shell expansion.
It publishes a completed snapshot, retains the last successful data on error,
and exposes a truthful error message. No window titles are logged. Native
Quickshell IPC still supplies events and dispatch. This compatibility adapter
is intentionally narrow; remove it only after testing native workspace and
monitor models against this address-based protocol. Installed qmltypes and the
[Quickshell workspace API](https://quickshell.org/docs/v0.3.0/types/Quickshell.Hyprland/HyprlandWorkspace/)
were inspected; legacy `activate()` cannot simply substitute for Lua dispatch.

Workspace addresses are canonical strings. Positive numeric ids, named
workspaces, literal monitor rules and persistent empty workspaces contribute
to automatic discovery. Arbitrary range/filter rules and special workspaces
are excluded. A workspace's actual current monitor takes precedence over its
configured rule. Nonpersistent empty workspaces with no assignment cannot be
rediscovered after Hyprland destroys them; use an override to keep those marks.
Each bar derives its active mark from its own monitor's `activeWorkspace`.

`bar.workspaceOutputsJson` is an additive schema-3 preference keyed by connector:

```json
{"DP-1":["1","2","3","gaming"],"HDMI-A-1":null}
```

An array selects ordered indicators (empty hides all); null explicitly chooses
Automatic. An absent connector inherits legacy `workspaceIds` where applicable,
otherwise discovery. Existing global ids are partitioned by observed ownership;
foreign-only ids do not suppress a monitor's discovered workspaces. An absent id
is retained only on the explicitly targeted legacy output. Named workspaces
remain visible with legacy numeric preferences. Existing keys and extension data
are preserved, older-version backup/migration remains in place, and no live
settings rewrite is required just to introduce the new optional field. Selecting
Automatic takes precedence over legacy ids on that output. Disconnected-output
preferences remain stored. Connector identities are not portable across GPU
port changes; EDID identity migration is not implemented.

Top bar monitor controls use model names and connectors. Focused/Primary/All
clear a previous explicit monitor selection. Focus comes from the same raw
snapshot as workspace ownership. Primary retains the existing meaning: the
first Qt screen, since Wayland supplies no universal primary-output preference.
Clicking an indicator focuses its bar's monitor before activating the workspace;
it does not move an existing workspace between monitors. Named Lua selectors
use a quoted `name:` prefix, as does the owner's gaming configuration. Constructor
validation against installed Lua succeeded without dispatching any actions.

The Workspaces page has per-output Automatic/Override controls, ordered comma-
separated names/ids, validation and Save, current active/empty status, and Refresh.
It changes SwiftShell preferences only, never compositor workspace rules.
Stable monitor-choice arrays preserve editor focus during workspace events.
The Settings controls retain keyboard navigation without changing bar keyboard focus.

Native testing exposed JsonAdapter's serialized cache updating after its
`adapterUpdated` signal. Writing synchronously saved the previous preference
and could leave `writing` stuck. Deferring/coalescing `writeLatest` with
`Qt.callLater` fixes the observed failure. The native regression writes several
preferences synchronously, reads the actual JSON, and starts another isolated
Quickshell instance to verify readback. It instantiates the real SettingsWindow
with visibility false. Every XDG write goes into a temporary directory.

Validation and visual acceptance are recorded in `docs/testing.md`. No Hyprland,
monitor mode, Noctalia, bind, autostart or system service file was changed.
