# M4.5 Slideshow and contrast

## Status

Accepted for the source tree. The crossfade and the sampled text have not been shown on a Hyprland session.

## Decision

- Slideshow is a tested state machine: disabled, scanning, waiting, preloading, transitioning, paused, and error. The schedule is a `Timer` in `SlideshowClock.qml` with a floor of one minute. The fade is a `NumberAnimation` from 0 to 1000 ms. Reduced motion uses 0. One image does not advance. Shuffle will not show the current image again while another file remains. A failed next image keeps the current one.
- This Qt build cannot list a directory and has no folder dialog module. The page says that. Images are added by path. There is no pause control for battery, lock, or fullscreen, because those signals are not read here.
- Contrast reads png pixels from the top edge, left, center, and right. Light text is used on dark regions and dark text on light regions. A split or a contrast below 4.5 draws the bar fade instead of flipping the glyphs. Small changes keep the previous choice. The fade accent is pulled toward gray. Manual `#rrggbb` values are not overwritten when automatic is turned off.
- Jpeg and webp still display. They are not sampled. Other windows are not captured.

## Consequences

A real crossfade, a white image, a split image, and a jpeg on the session are still for the owner to watch. Memory of a long slideshow was not measured on hardware.
