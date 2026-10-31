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

    readonly property bool ownImage: choice.override === true
    property bool capHeight: false
    readonly property string displayPath: {
        if (surface.ownImage) {
            if (surface.failed || surface.choice.source !== "file")
                return ""
            return surface.choice.path
        }
        if (SettingsStore.slideshow && WallpaperModel.shownPath !== "")
            return WallpaperModel.shownPath
        if (surface.failed || surface.choice.source !== "file")
            return ""
        return surface.choice.path
    }
    readonly property url displaySource: displayPath === "" ? packagedSource : Wallpaper.fileUrl(displayPath)

    onShownPathChanged: failed = false

    Image {
        id: baseImage
        anchors.fill: parent
        asynchronous: true
        fillMode: SettingsStore.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        // Set one edge so Qt keeps the aspect ratio. A portrait result switches to the height cap.
        sourceSize.width: surface.capHeight ? 0 : surface.limitEdge
        sourceSize.height: surface.capHeight ? surface.limitEdge : 0
        source: surface.displaySource
        onStatusChanged: {
            if (status === Image.Ready && !surface.capHeight && implicitHeight > surface.limitEdge)
                surface.capHeight = true
            if (status === Image.Error && !surface.failed && (surface.ownImage || WallpaperModel.shownPath === ""))
                surface.failed = true
        }
    }

    Image {
        id: incomingImage
        anchors.fill: parent
        asynchronous: true
        opacity: 0
        fillMode: baseImage.fillMode
        sourceSize.width: surface.capHeight ? 0 : surface.limitEdge
        sourceSize.height: surface.capHeight ? surface.limitEdge : 0
        source: surface.ownImage || WallpaperModel.incomingPath === "" ? "" : Wallpaper.fileUrl(WallpaperModel.incomingPath)
        onStatusChanged: {
            if (surface.ownImage || WallpaperModel.slideState !== "preloading")
                return
            if (status === Image.Ready)
                WallpaperModel.noteLoaded()
            else if (status === Image.Error)
                WallpaperModel.noteFailed()
        }
    }

    NumberAnimation {
        id: fade
        target: incomingImage
        property: "opacity"
        from: 0
        to: 1
        duration: SettingsStore.reducedMotion ? 0 : SettingsStore.transitionMs
        onFinished: WallpaperModel.noteFinish()
    }

    Connections {
        target: WallpaperModel
        function onSlideStateChanged() {
            if (surface.ownImage)
                return
            if (WallpaperModel.slideState === "transitioning") {
                incomingImage.opacity = 0
                fade.start()
            } else if (WallpaperModel.slideState !== "preloading") {
                incomingImage.opacity = 0
            }
        }
    }
}
