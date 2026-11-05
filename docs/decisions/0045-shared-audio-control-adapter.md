# Shared native audio control adapter

Date: 2026-11-04

AudioService owns the PipeWire graph and binds every audio node before controls
read channel volume or mute. Devices are selectable by ID; writes require an
existing ready node. The default output/input gesture additionally captures its
starting device ID, so changing defaults during a drag cannot change the old or
replacement device. Application rows are keyed and retain their slider through
volume updates. Both the bar Audio panel and Settings use this adapter.

Output and microphone now have real device selectors, mute actions and readable
volume/gain values. Active application sliders show every published audio stream,
without the former six-stream/eight-device truncation. Settings groups separately
expose Output, Microphone, Applications, Media playback and Tray applications.

Previous/play/next use larger vector controls with 48px targets and a wider primary
play/pause action. They retain the native MPRIS capability guards and release-only
seek behavior. Playing animation also stops when animation scale is zero.

A read-only isolated native audit found the previous AudioSection could bind the
real defaults successfully: Quickshell 0.3.2, ready output/input and native volume
1.0. Therefore a missing PipeWire API was not established as the user's original
failure. The new regression passes with the prior generic slider too; no claim
is made that Flickable stealing alone explains the report. Native write/readback
below verifies the final shared adapter rather than inventing an earlier cause.

Verification:

- `tst_audio.qml`: eight checks passed on Qt 6.12, including output/input/app
  writes, both mute controls, not-ready/removed-node rejection, default changes
  mid-gesture, device type validation, retained app-slider identity and a complete
  drag inside a scrolling view.
- `tst_media.qml`: eight checks passed with the larger vector controls; guarded
  pointer/keyboard seek and literal metadata remained intact.
- `node tests/media.test.js`: media selection/seek/metadata regressions passed.
- `python3 tests/live/audio-controls.py --live`: real Quickshell/PipeWire volume
  .43 and mute changes reached an owned silent low-priority sink, verified with
  independent `wpctl` readback. Exact original per-channel values/mute were restored,
  then the creator exited and its non-lingering node disappeared. The actual
  default devices and their volumes remained unchanged.

The native test is offscreen, uses only an owned silent node, and sends no desktop
pointer/keyboard events. It neither changes game audio nor steals monitor focus.
Real default-device switching and audible output/microphone acceptance were not
performed while the owner was gaming. No system service, Noctalia, user Lua,
monitor mode or autostart was changed. Backups are retained under
`/tmp/swiftshell-audio-repair-20261104`; revert this feature commit for source
recovery. The adapter introduces no persisted migration.

Installed API metadata and official contracts:
https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwObjectTracker/
https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwNode/
https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwNodeAudio/
