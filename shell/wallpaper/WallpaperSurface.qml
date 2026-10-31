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
    property int frontSlot: 0
    property string slotAPath: ""
    property string slotBPath: ""
    property url slotASource: ""
    property url slotBSource: ""
    property string pendingPath: ""
    property int pendingGeneration: 0
    property var fadeTarget: null

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

    function imageForSlot(slot) {
        return slot === 0 ? slotA : slotB
    }

    function pathForSlot(slot) {
        return slot === 0 ? surface.slotAPath : surface.slotBPath
    }

    function setSlot(slot, path, source) {
        if (slot === 0) {
            surface.slotAPath = path
            surface.slotASource = source
        } else {
            surface.slotBPath = path
            surface.slotBSource = source
        }
    }

    function resetFront(path, source) {
        fade.stop()
        surface.frontSlot = 0
        surface.pendingPath = ""
        surface.setSlot(0, path, source)
        surface.setSlot(1, "", "")
        slotA.opacity = 1
        slotA.z = 0
        slotB.opacity = 0
        slotB.z = 1
    }

    function prepareIncoming() {
        if (surface.ownImage || WallpaperModel.slideState !== "preloading"
                || WallpaperModel.incomingPath === "")
            return
        var back = surface.frontSlot === 0 ? 1 : 0
        surface.pendingPath = WallpaperModel.incomingPath
        surface.pendingGeneration = WallpaperModel.transitionGeneration
        surface.setSlot(back, surface.pendingPath, Wallpaper.fileUrl(surface.pendingPath))
        var image = surface.imageForSlot(back)
        image.opacity = 0
        image.z = 1
        surface.imageForSlot(surface.frontSlot).z = 0
    }

    function startFade() {
        if (surface.ownImage || surface.pendingPath === ""
                || surface.pendingPath !== WallpaperModel.incomingPath)
            return
        surface.fadeTarget = surface.imageForSlot(surface.frontSlot === 0 ? 1 : 0)
        fade.stop()
        fade.start()
    }

    function promoteIncoming() {
        var back = surface.frontSlot === 0 ? 1 : 0
        if (surface.pendingPath === "" || surface.pathForSlot(back) !== surface.displayPath)
            return false
        fade.stop()
        var old = surface.frontSlot
        surface.frontSlot = back
        surface.imageForSlot(back).opacity = 1
        surface.imageForSlot(back).z = 0
        surface.imageForSlot(old).opacity = 0
        surface.imageForSlot(old).z = 1
        surface.setSlot(old, "", "")
        surface.pendingPath = ""
        return true
    }

    function syncShown() {
        if (surface.promoteIncoming())
            return
        surface.resetFront(surface.displayPath, surface.displaySource)
    }

    function discardIncoming() {
        if (surface.pendingPath === "")
            return
        fade.stop()
        var back = surface.frontSlot === 0 ? 1 : 0
        surface.imageForSlot(back).opacity = 0
        surface.setSlot(back, "", "")
        surface.pendingPath = ""
    }

    function handleStatus(slot, status) {
        var path = surface.pathForSlot(slot)
        if (status === Image.Ready && slot !== surface.frontSlot
                && path !== "" && path === WallpaperModel.incomingPath) {
            WallpaperModel.noteLoaded(surface.outputName, path, surface.pendingGeneration)
            return
        }
        if (status !== Image.Error)
            return
        if (slot !== surface.frontSlot && path === WallpaperModel.incomingPath) {
            WallpaperModel.noteFailed(path, surface.pendingGeneration)
            return
        }
        if (!surface.ownImage && SettingsStore.slideshow && path === WallpaperModel.shownPath) {
            WallpaperModel.noteShownFailed(path)
            return
        }
        if (slot === surface.frontSlot && path !== "" && !surface.failed)
            surface.failed = true
    }

    function syncAnalysis() {
        ColorAnalysis.registerOutput(surface.outputName, surface.width, surface.height,
                                     surface.displayPath)
    }

    Component.onCompleted: {
        syncShown()
        syncAnalysis()
    }
    Component.onDestruction: ColorAnalysis.unregisterOutput(surface.outputName)
    onWidthChanged: syncAnalysis()
    onHeightChanged: syncAnalysis()
    onDisplayPathChanged: {
        syncShown()
        syncAnalysis()
    }
    onShownPathChanged: failed = false

    Image {
        id: slotA
        anchors.fill: parent
        asynchronous: true
        fillMode: SettingsStore.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        sourceSize.width: surface.limitEdge
        sourceSize.height: surface.limitEdge
        source: surface.slotASource
        onStatusChanged: surface.handleStatus(0, status)
    }

    Image {
        id: slotB
        anchors.fill: parent
        asynchronous: true
        opacity: 0
        z: 1
        fillMode: slotA.fillMode
        sourceSize.width: surface.limitEdge
        sourceSize.height: surface.limitEdge
        source: surface.slotBSource
        onStatusChanged: surface.handleStatus(1, status)
    }

    NumberAnimation {
        id: fade
        target: surface.fadeTarget
        property: "opacity"
        from: 0
        to: 1
        duration: SettingsStore.reducedMotion ? 0 : SettingsStore.transitionMs
        onFinished: WallpaperModel.noteFinish(surface.outputName, surface.pendingPath,
                                               surface.pendingGeneration)
    }

    Connections {
        target: WallpaperModel
        function onSlideStateChanged() {
            if (surface.ownImage)
                return
            if (WallpaperModel.slideState === "preloading")
                surface.prepareIncoming()
            else if (WallpaperModel.slideState === "transitioning")
                surface.startFade()
            else if (WallpaperModel.incomingPath === "")
                surface.discardIncoming()
        }
        function onIncomingPathChanged() {
            if (WallpaperModel.slideState === "preloading")
                surface.prepareIncoming()
            else if (WallpaperModel.incomingPath === "")
                surface.discardIncoming()
        }
    }
}
