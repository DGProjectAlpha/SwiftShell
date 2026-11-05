# Integrated Audio media player

Date: 2026-11-02

The Audio panel now presents media playback above the existing output/input/device
and application-volume controls. MediaService is shared by the panel, Audio Settings
and the media bar element. Automatic selection prioritizes a currently playing
MPRIS player, then an available paused/stopped player. The source selector permits
an explicit session-only choice when multiple players are available; a removed
source falls back to Automatic. PipeWire remains the authority for actual audio
routing/volume; MPRIS is the authority for media metadata and transport controls.
Applications without MPRIS still retain their PipeWire volume controls.

Title, artist/album and player identity render as plain text. Artwork is only the
player-supplied MPRIS art URL, with bounded requested decode size and asynchronous
loading. Missing artwork uses a neutral music glyph. A browser-provided YouTube
thumbnail can therefore appear, but SwiftShell does not scrape pages, read browser
cookies, capture browser pixels, fetch its own thumbnails or invent unavailable
metadata. No player means a concise invitation to play media, rather than fake
controls. Previous, play/pause, next and seeking follow the native capability flags.
The restrained playing indicator stops for reduced motion and while hidden.

Installed Quickshell 0.3.2 type metadata and its official MprisPlayer documentation
agree: position and length are seconds; position writes require canSeek and
positionSupported. A known positive supported length is additionally required for
an absolute seek bar. While visible and playing, a 500ms timer asks the native
position interpolator to notify bindings. It does not poll D-Bus or start helpers.
Hidden/paused media does not run this timer. The slider previews locally during
a pointer drag and commits exactly once on release. Escape/cancellation does not
seek. The player object and unique track identity are captured at gesture start,
so changing track or source during a drag cannot seek the replacement media.
Arrow keys provide small seeks; Home/End select the track boundaries.

Official API: https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Mpris/MprisPlayer/

Verification:

- `node tests/media.test.js`: automatic/manual/removed-source selection, seconds-
  based seek bounds, unsupported/invalid lengths and positions, duration labels,
  track identity and supplied-art URL filtering passed.
- `tst_media.qml`: eight checks passed, exercising actual QML source selection,
  pointer playback buttons, literal metadata, single-release seeking, track/source
  changes during a drag, Escape, keyboard seeking, unsupported controls, owned
  artwork loading and missing-art fallback.
- `python3 tests/live/media-player.py --live`: actual Quickshell MPRIS discovery
  against two silent synthetic players on a private bus passed on DP-1 scale 1 and
  HDMI-A-1 scale 1.25. Native Pause/Play/previous/next calls reached the fixture.
  A real pointer drag committed exactly one SetPosition with 180,000,000 microseconds
  for the UI's 180 seconds. Track-change rejection, unsupported seek, explicit
  source choice, artwork and dark/light fallback states passed.
- Native visual inspection used `grabToImage` on a named owned QML item with an
  opaque checkerboard inside the same window. Only synthetic fixture text/art and
  that item tree enter the images. No compositor/browser/user pixels are captured.
  Backdrop blur attachment readback passed separately; these owned-item snapshots
  do not measure compositor blur strength.

The live desktop had no published MPRIS player during the read-only audit. No real
app was started or played/paused/seeked; no system volume, output or routing was
changed. Browser/app-specific metadata support remains an owner acceptance check.
Tests produce no audio and never access real track metadata. Exact native evidence
is Qt 6.12 / Quickshell 0.3.2 / Hyprland 0.57, not a claim about all players or
older Qt CI. Source backups are under `/tmp/swiftshell-media-rework-backup`.
Revert the feature commit for source rollback; no external configuration or state
migration is needed because the selected source is session-only.
