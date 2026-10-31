# M3 stabilization

The CachyOS session opened the launcher. Dolphin (`org.kde.dolphin.desktop`) and Helium (`helium.desktop`) were installed and were not searchable. Icons were letter monograms. Ordinary windows overlapped the bar while `reserveSpace` was false. An earlier startup failed with `BarWindow.qml: BarLabel is not a type` until `import "../components"` was added. Workspace clicks on that session succeeded after the Lua dispatch change. This change does not alter that dispatcher.

None of the corrections below were launched with `qs` in the environment that wrote them.

## Discovery

`DesktopEntries.applications` is an `ObjectModel`. Current Quickshell scans desktop files and delivers the result on the event loop: `DesktopEntryScanner::run` posts `onScanCompleted` with `Qt::QueuedConnection`, then emits `applicationsChanged`. The first read of `.values`, in the same turn the singleton is created, can be empty. The launcher copied that list once, when it opened, and dropped it on close. Search then ran on the empty copy.

The shell now reads the model at startup, on `applicationsChanged`, and again when the launcher opens. The first empty read stays pending. A later read replaces it. Search ranks the whole snapshot, including the desktop id, so `dolphin` matches `org.kde.dolphin` and `helium` matches `helium`. The empty view still shows at most 12 applications. That cap is not the search set. Hidden and NoDisplay entries are skipped. The first id wins when two entries share one. `DesktopEntry.execute()` is still the only launch path. A directory walk was not added, because the native model is the index once the scan signal is observed.

## Icons

`Quickshell.iconPath(name, true)` is the 0.2 theme lookup. It returns an `image://icon/` source, or `""` when the theme has no icon, instead of the missing-icon placeholder. Absolute paths are used as files. The row image keeps its aspect ratio, requests a 16px source size times the screen device ratio, and caches the decoded image. The script caches the URL by icon name. A missing path or a failed load is a monogram.

## Reservation

`PanelWindow` starts in `ExclusionMode.Auto`, which reserves space. Overlay mode assigns `ExclusionMode.Ignore`. Quickshell's Wayland binding then sends exclusive zone `-1`. Reservation assigns the logical bar height and `ExclusionMode.Normal`. Quickshell converts that height to native pixels when it commits the surface, so this code does not multiply by scale. Assigning `exclusiveZone` to a value it already holds does not call the setter, which is why turning reservation off and back on could leave the mode at `Ignore`. The window writes `Normal` even when the height is unchanged. The layer stays `WlrLayer.Top`. True fullscreen still covers the bar. Hyprland's fullscreen rules are not edited.

New settings files default `reserveSpace` to true. `scripts/launch.sh` does not replace an existing settings file, so a checkout that already has `false` stays an overlay until that key is edited. `false` is the mode to use while Noctalia is also drawing on the output.

## Imports and focus

The static check rejects a shell file that uses a project QML type its imports do not provide. A fixture of the original `BarLabel` use, without `import "../components"`, fails that check. The shell-load test compiles `BarWindow.qml` under Quickshell stubs and fails if the error text contains `BarLabel`. The stub compile is not a Quickshell startup. `WlrLayershell` is still a C++ attached type and is not stubbed.

The launcher requests exclusive keyboard focus only while its window is visible. Hiding the window clears the text field and the focus grab. If the screen disappears while it is open, the launcher closes instead of keeping a full-screen grab. Escape is handled on the field and on the window. Power actions still require a second confirmation, use a fixed `loginctl` argument list, and show a short notice if the call fails. The search string is not an argument. Those calls were not executed.
