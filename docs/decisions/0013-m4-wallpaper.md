# M4.4 Wallpaper renderer

## Status

Accepted for the source tree. The background layer has not been shown on a Hyprland session.

## Decision

- One `PanelWindow` per screen, layer background, namespace `swiftshell-wallpaper`, no keyboard focus, no exclusive zone. The shell does not stop `hyprpaper` or `swww`. `wallpaper.enabled` false removes the layers.
- An empty path uses the packaged crimson PNG. A rejected path or a decode error uses that same image and keeps the previous choice out of the file. Cover crops. Contain letterboxes on black. Decode width is capped at 3840.
- Per-output paths are a JSON object keyed by the screen name Quickshell reports. The settings page can open `FileDialog` when `QtQuick.Dialogs` is installed. This Qt build does not have that module, so the path field is the fallback.
- Install copies the PNG into the app tree as a regular file. The checkout path is a symlink to `assets/wallpapers/swiftshell-default-crimson.png`.

## Consequences

Slideshow, folder choice, and wallpaper-sampled contrast are not in this change. A real output at scale 1.5, a portrait crop, a missing file, and an 8K image have not been watched on the session.
