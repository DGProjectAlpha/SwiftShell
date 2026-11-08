# Settings motion, hierarchy and wheel scrolling

Date: 2026-11-08

Section disclosure previously changed visibility immediately, shared switches
and combo-box menus had no transition, section contents aligned with headings,
and Settings Flickables could steal a left-button drag from controls.

SettingsSection now clips and animates the body height with the existing Theme
open/close durations. Content stops accepting input as collapse starts and the
viewport disappears at zero height. Category headings use Bold and align to the
page’s left edge; setting bodies have one consistent 16px inset. Individual
setting fonts keep their existing theme weight. Responsive sections calculate
their columns within the inset instead of overflowing their parent.

SettingsToggle animates its thumb and track colors for every shared use,
including top-bar panels. ChoiceBox expands and retracts its clipped height, so
text is never stretched as a texture. Top-bar panels keep their established open
position but slide down into it and up on close; closing immediately releases
keyboard focus, the focus grab and the pointer mask before the visual exit.
Every transition uses existing Theme motion tokens, including zero duration for
reduced motion or disabled animations.

The Settings content/sidebar and choice lists disable Flickable drag interaction.
WheelHandler preserves mouse-wheel and touchpad scroll; Page Up/Down and focus
reveal still work. Settings scroll positions clamp when sections or the viewport
shrink. Active sliders and drag handles retain their wheel/input interaction.
Widget-order drag handles and their explicit edge auto-scroll stay functional.

Verified: actual-component offscreen SettingsInteraction tests cover intermediate
collapse/expand heights, immediate closing input disable, bold/indent hierarchy,
toggle motion in both directions, menu expansion/retraction, rapid reopen,
reduced motion, a non-scrolling content drag, a real wheel event, Page Down and
collapse scroll clamping. Responsive and widget pointer-drag suites pass. The
existing popup-model tests cover focus/input release during animated close.
These checks do not establish live visual smoothness on either monitor.

Recovery: revert this commit to restore previous motion and scroll behavior.
No settings schema, user preferences, compositor configuration or Noctalia files
are changed.

API references: [Qt WheelHandler](https://doc.qt.io/qt-6/qml-qtquick-wheelhandler.html)
and [Qt Popup transitions and clipping](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html).
WheelHandler avoids depending on Flickable.acceptedButtons, added in Qt 6.9.
