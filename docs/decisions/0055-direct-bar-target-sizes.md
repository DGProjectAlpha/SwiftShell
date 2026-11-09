# Draw bar contents at their final per-output size

Date: 2026-11-08

The previous renderer sized modules against global Theme metrics and magnified
the module container to match each display’s saved bar height. A 32px bar with
a 28px base therefore used a 32/28 scene transform. Canvas icons were enlarged
after painting, and native hinted text could not safely be selected for that
transformed output. This is the limitation recorded in decision 0053.

BarWindow now resolves saved height and legacy scale into final logical metrics
before creating its contents. Fonts, glyph dimensions, gaps, hit targets, media
controls, tray images and vertical rails use those metrics directly. Integer
font/icon sizes are rounded once at the target size. The module container has
no scale transform or inverse-size workaround. Existing preferences, base font
family/weight, monitor settings and placement policy are unchanged; pixel
rounding can make small differences to glyph widths and spacing.

Theme.barMetricsFor walks the visual ancestry to find the owning bar’s metrics,
including through ModuleStrip loaders. Standalone controls and popovers retain
global defaults. Labelled tray rows keep their existing settings/panel sizing.
Only bar rows use the output’s icon and hit-area dimensions.

Qt handles the owning window’s device pixel ratio once. Canvas image backing
already uses effectiveDevicePixelRatio in Qt 6.12, and Qt scales Image.sourceSize
for scalable providers. Request final logical image dimensions; do not multiply
them by DPR again. There are no connector-name, fixed-resolution or physical-DPI
thresholds. At DPR 1 the untransformed bar can use vertically hinted native text
at any selected bar size; fractional/high-DPI outputs retain scalable Qt text.

## Evidence

- `scripts/check.sh`: exit 0; 128 QML files; 31 QML suites, 260 passed,
  0 failed, 0 skipped; JavaScript, Python and installer checks passed.
- The QML regression changes a real ModuleStrip/BarLabel, Canvas widget and tray
  control between 28, 32 and 42px without changing a parent scale. Changing its
  simulated DPR changes the text policy, not logical font/icon dimensions.
- `python scripts/test-bar-text-native.py --target-sizes --output-dir
  /tmp/swiftshell-target-size-final`: exit 0. Controlled, input-transparent
  captures passed at 28/32/42px on both physical outputs. DP-1 DPR 1 produced
  900x80 images; HDMI-A-1 DPR 1.25 produced 1125x100 images. The 32px images were
  inspected. The test uses actual BarWindow metrics with controlled labels/icons,
  temporary preferences and no capture of other applications.
- `python scripts/test-bar-settings-native.py`: exit 0 after the main source
  change; hidden native geometry, untransformed 42px/28px output metrics, atomic
  save and fresh-process readback passed. A later rerun after adding stronger
  loaded-clock assertions was refused by the fullscreen safety guard before
  creating any window. Those extra native assertions remain pending.
- Final read-only live diagnostics: DP-1 height32/DPR1/transform1/native-hinted,
  font14/icon18; HDMI-A-1 height28/DPR1.25/transform1/distance-field,
  font12/icon16. No user preference was changed for these results.

Human acceptance on the physical screens, physical hotplug and other GPUs remain
manual checks. No live input/focus tests run while a fullscreen application is
active. Revert this source commit to restore the old drawing path; there is no
settings migration or compositor configuration to undo.
