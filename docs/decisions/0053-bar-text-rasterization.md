# Hinted bar text at actual one-to-one raster scale

Date: 2026-11-08

> Follow-up: decision 0055 removes the bar’s container transform. The current
> 32px DP-1 bar now renders directly with native hinted text; the transformed-bar
> limitation below describes the earlier implementation and has been resolved.

The initial live audit found DP-1 at Qt window DPR 1, content scale 1 and 28px
bar height selecting CurveRendering, while HDMI-A-1 at DPR 1.25/content scale 1
selected QtRendering. DP-1 module origins were already integer-aligned. There
was no bar-layer texture scaling on that original DP-1 path. Small curve-rendered
glyph outlines bypass platform hinting; this was a concrete difference from the
fractional output and from the installed native Noctalia 5.4.1 renderer.

Use Text.NativeRendering with explicit antialiasing and PreferVerticalHinting
only when both the actual window DPR and bar transform are exactly one. Vertical
hinting preserves horizontal font metrics; full hinting is deliberately avoided.
All scaled paths retain QtRendering. Screen connector, advertised resolution and
physical DPI never select a renderer: two panels with the same raster transform
need the same policy regardless of panel size/name. Diagnostics report logical
and raster dimensions and the effective raster scale. These are rendering
dimensions, not an EDID measurement of physical panel DPI.

Canvas widget/performance/weather glyphs did not explicitly enable antialiasing.
The explicit flags and smooth sampling are defensive: Qt 6 Canvas already
defaults to antialiasing, so missing flags were not established as the icon root
cause. The old parent transform enlarged their painted textures; decision 0055
removes that transform. Search's rotated rectangle also explicitly antialiases.
No font family, weight, bar preferences or display scale was changed here.

Native own-surface comparisons ran on both actual outputs after the fullscreen
guard. Four identical sample rows compare Curve, Qt distance fields, native
vertical hinting and native full hinting; glyph pairs compare aliased and AA
painting. Corrected captures are `/tmp/swiftshell-text-final/DP-1.png` (900x180)
and `HDMI-A-1.png` (1125x225), at actual DPR 1 and 1.25. Only the test surface is
captured; it is unfocused, input-transparent, temporary and auto-exits. The first
experimental capture supplied a DPR-multiplied target size, causing double scaling
on HDMI. It is invalid as evidence of native fractional-text degradation and is
not used here. The final runner asserts physical image dimensions.

The corrected DP-1 image shows a modest improvement from vertically hinted native
glyphs and smoother AA icons. Keeping the existing fractional Qt path avoids a
gratuitous change to an output the owner already considers sharp. Human physical
screen acceptance, other GPUs and broad font benchmarks remain unperformed.

Important current-state limit: during this task the owner's DP-1 bar became 32px.
Final live diagnostics report DPR 1/content scale 32/28 and distance-field text;
HDMI remains 28px/DPR 1.25/distance-field. The safe hinted-native fix applies to
the originally reported unscaled path, and is **not claimed active for the current
32px transformed bar**. Fixing typography at every arbitrary bar transform would
require a larger metric/layout redesign; no preference was changed to hide this.

Checks: `node tests/logic.test.js` passed; `tst_performance.qml` passed 13 cases,
including actual BarLabel inheritance, hinting/AA, fractional fallbacks, arbitrary
display metadata and Canvas AA. `python scripts/test-bar-text-native.py
--output-dir /tmp/swiftshell-text-final` passed both output captures. The root agent
ran the combined repository suite. Recovery is to revert this source commit;
there is no user setting or compositor configuration to restore.

Sources: [Qt Text rendering and hinting](https://doc.qt.io/qt-6/qml-qtquick-text.html),
[Qt font hinting](https://doc.qt.io/qt-6/qml-font.html),
[Noctalia rendering architecture](https://github.com/noctalia-dev/noctalia/blob/main/ARCHITECTURE.md).
Installed package metadata confirms Noctalia links Pango/Cairo/FreeType rather
than Qt; no Noctalia process or settings were changed for comparison.
