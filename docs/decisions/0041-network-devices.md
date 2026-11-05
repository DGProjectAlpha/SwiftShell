# Network and Bluetooth device management

Date: 2026-11-01. Owner-requested combined Network & Devices manager and focused
network bar panel. This replaces the former Network unavailable placeholder;
Bluetooth is embedded in the same page rather than requiring separate navigation.

The Settings page presents actual wired and Wi-Fi adapters, connection status,
IPv4 addresses, saved connection profiles and nearby access points. NetworkManager
owns all connection and credential persistence. Explicit actions enable Wi-Fi,
rescan, connect an observed AP or saved profile, and connect/disconnect a device.
Disconnecting a device or turning Wi-Fi off requires a confirmation. The focused
bar panel provides status, a real confirmed Wi-Fi switch, Bluetooth controls and a
Settings handoff. It contains no audio or power actions.

`NetworkService` uses a small `networkctl.py` adapter to the installed NetworkManager
CLI. The verified target is NetworkManager 1.58.1. The helper validates actions
against freshly observed interface names, AP BSSIDs and profile UUIDs, then uses
fixed argument lists without a shell. Terse fields use nmcli's documented escaping;
connection names containing colons/backslashes are handled. The general status
contract was verified locally: `--get-values STATE,CONNECTIVITY` returns the two
fields on one colon-separated line, not two lines.

A `nmcli monitor` event stream runs only while a visible consumer owns a view.
Events coalesce refreshes; their text is not forwarded or stored. Ordinary
snapshots read cached access points using `--rescan no`; discovery happens only
when requested. Missing tools/service/hardware produce an explicit unavailable
state and disabled actions. The bar consumer can own a view for continuously live
status without periodic polling.

New open or personal-WPA connections are supported. A masked local input sends
its request to the helper over process stdin. The helper uses `nmcli --ask` stdin;
the passphrase never appears in process argv, SwiftShell preferences, shell history
or logs. Input and pending request references are cleared after handoff; this is
not a claim of cryptographically zeroing Qt/Python memory. NetworkManager may save
credentials according to its normal profile behavior. Existing enterprise profiles
can be activated, but creating enterprise/WEP/hidden-network configurations is
not offered. Raw command errors that could contain SSIDs or secrets are replaced
with concise generic errors. No web requests or connection telemetry are sent.

Bluetooth uses the installed public Quickshell 0.3.2 `BluetoothAdapter` and
`BluetoothDevice` APIs: adapter selection/power, `discovering`, connect/disconnect,
pair/cancel and forget. Devices sort by connected/paired state and show observed
battery/status. Discovery started by this component stops after 30 seconds or
when the component closes; cleanup does not claim ownership of a discovery that
was already running. Device changes remain pending until observed success or a
20-second timeout. Forget requires confirmation. Pairing that needs PIN or numeric
confirmation relies on the existing system pairing agent; SwiftShell does not
replace or register one. There is no invented pairing-success notification.

Verification:

- `python3 tests/test_networkctl.py`: 11 passed, covering escaped fields, observed
  target validation, password stdin, fixed argv, enterprise limitations, timeout
  and private error redaction, and actual general-status wire format.
- `tests/qml/tst_network_devices.qml`: 5 passed, covering disconnect confirmation,
  masked/cleared credentials and stdin handoff, and owned discovery cleanup.
- `python3 tests/live/network-devices.py --live`: passed real Quickshell stdin
  transport, actual NetworkManager snapshot and manager view ownership using
  isolated XDG directories with no visual surface or connectivity changes.
- Read-only target audit: two network devices, one saved profile, active Ethernet,
  Wi-Fi hardware present but radio disabled and no cached APs. Network names,
  profile names, credentials and local addresses were not printed in test reports.

Live Wi-Fi enable/scan/join/password, Ethernet disconnection, Bluetooth discovery,
pairing/confirmation, connection and forgetting have **not** been exercised on
physical devices during this implementation. Those require explicit user actions
in the manager; validation did not interrupt the working wired connection.

Recovery: no Hyprland, Noctalia, autostart, service or package configuration was
changed. Closing a manager releases its monitor/discovery ownership. NetworkManager
connection changes made later by the user can be reversed with the same manager
or their existing system tools. Source rollback is a normal Git revert; no external
SwiftShell connection database needs restoration because none is created.

API contracts: [nmcli manual](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nmcli.html),
[Quickshell BluetoothAdapter](https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothAdapter/),
[Quickshell BluetoothDevice](https://quickshell.org/docs/v0.3.2/types/Quickshell.Bluetooth/BluetoothDevice/).

## Wi-Fi interaction and radio recovery follow-up — 2026-11-02

The owner reported an error after enabling Wi-Fi, an apparently absent password
prompt, and a switch that appeared not to turn Wi-Fi off. Investigation found
three independent causes:

- An AP-list query could fail during radio/supplicant transitions, invalidating an
  otherwise successful radio write. Off could also query APs from a stale cached
  device state. AP reads now occur only while the observed radio is on; transient
  AP/address failures preserve the successful radio/device snapshot. Explicit
  radio changes wait for observed readback, including a useful hardware-blocked
  error, rather than treating command acceptance as completion.
- The password form was below the entire AP list, and the disconnect confirmation
  was at the top of the scrolling page. Both could open outside the visible
  viewport. They are now centered, focused Basic-style item popups inside the
  Settings window with the shared theme. Escape/outside dismissal clears the
  credential draft and returns focus; no additional native window is created.
- Background snapshot reads disabled or raced user actions. A deliberate action
  now queues behind a read-only refresh, while actual mutations remain serialized.
  Radio requests coalesce to the latest intent, are always confirmed even when a
  stale cached flag already matches, and discard queued Wi-Fi connection secrets
  when turning off. Queued Ethernet work is retained. Queued connection requests
  can be cancelled before submission. AP controls use keyed roles so a signal
  strength refresh retains the button under the pointer.

The Wi-Fi device row now says Find networks rather than attempting an unspecified
connection. Radio errors retain a secret-free retry context, and the compact
network panel follows the requested/observed radio transition consistently.

Validation: 23 Python helper tests and 19 QML interaction/state tests passed.
The native `tests/live/network-auth.py --live` audit used a synthetic 40-AP list
and fake helper only. Real pointer input opened a focused, visible password popup
from a scrolled list; Escape cleared it. A real pointer confirmation toggled only
the fixture's radio state. Native helpers guard the exact audit client, restore
focus/cursor afterward, and never capture actual SSIDs or credentials.

The new helper was also exercised against the actual hardware: Wi-Fi was initially
enabled but disconnected, and Ethernet was connected. OFF and ON both returned
verified radio state without losing Ethernet. The original ON state was restored
and checked. No real Wi-Fi connection/password, saved profile, pairing, Noctalia,
Hyprland Lua, system service or package was changed. Physical authentication to
an access point remains unperformed. Source backups were retained under
`/tmp/swiftshell-network-fix-backup-20261103T001528Z` before editing; a normal Git
revert of the follow-up commit restores the previous implementation.
