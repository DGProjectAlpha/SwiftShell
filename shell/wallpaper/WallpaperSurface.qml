import QtQuick
import Quickshell
import Quickshell.Wayland
import "../logic/wallpaper.js" as Wallpaper
import "../services"

PanelWindow {
    id: surface

    required property var modelData

    readonly property string outputName: modelData && modelData.name ? modelData.name : ""
    readonly property var choice: Wallpaper.sourceForOutput(outputName, SettingsStore.wallpaperPath, SettingsStore.wallpaperOutputsJson)
    readonly property string shownPath: choice && choice.path ? choice.path : ""
    property bool failed: false
    readonly property url packagedSource: Qt.resolvedUrl("../assets/wallpapers/swiftshell-default-crimson.png")
    readonly property int limitEdge: Wallpaper.MAX_EDGE

    screen: modelData
    color: "black"
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    // Background sits behind windows. This does not stop hyprpaper or swww.
    WlrLayershell.namespace: "swiftshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onShownPathChanged: failed = false

    Image {
        anchors.fill: parent
        asynchronous: true
        fillMode: SettingsStore.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        // One edge is capped. The other follows the picture so the crop is not stretched.
        sourceSize.width: surface.limitEdge
        source: surface.failed || surface.choice.source !== "file" ? surface.packagedSource : Wallpaper.fileUrl(surface.choice.path)
        onStatusChanged: {
            if (status === Image.Error && !surface.failed)
                surface.failed = true
        }
    }
}
