pragma Singleton

import QtQuick
import Quickshell
import "../logic/slideshow.js" as Slideshow
import "../logic/wallpaper.js" as Wallpaper

Singleton {
    id: root

    property var session: Slideshow.emptySession()
    property string slideState: "disabled"
    property string shownPath: ""
    property string incomingPath: ""
    property string slideError: ""
    property int slideCount: 0
    property int unreadable: 0
    readonly property bool clockRunning: slideState === "waiting" || slideState === "ready"
    readonly property int intervalMs: Slideshow.intervalMs(SettingsStore.intervalMinutes)

    function apply(next) {
        root.session = next
        root.slideState = next.state
        root.shownPath = next.shown || ""
        root.incomingPath = next.incoming || ""
        root.slideError = next.error || ""
        root.slideCount = next.count || 0
        root.unreadable = next.unreadable || 0
    }

    function sync() {
        var scanning = Slideshow.reduceSlideshow(root.session, { type: "scan" })
        root.apply(Slideshow.reduceSlideshow(scanning, {
            type: "scanned",
            enabled: SettingsStore.slideshow && SettingsStore.wallpaperEnabled,
            paths: Slideshow.parseList(SettingsStore.slidesJson),
            mode: SettingsStore.slideshowOrder,
            transitionMs: SettingsStore.reducedMotion ? 0 : SettingsStore.transitionMs,
            intervalMinutes: SettingsStore.intervalMinutes
        }, { resolveSource: Wallpaper.resolveSource }))
    }

    function tick() {
        root.apply(Slideshow.reduceSlideshow(root.session, { type: "tick" }))
    }

    function noteLoaded() {
        root.apply(Slideshow.reduceSlideshow(root.session, { type: "loaded" }))
    }

    function noteFinish() {
        root.apply(Slideshow.reduceSlideshow(root.session, { type: "finish" }))
    }

    function noteFailed() {
        root.apply(Slideshow.reduceSlideshow(root.session, { type: "failed" }))
    }

    Component.onCompleted: sync()

    Connections {
        target: SettingsStore
        function onSlideshowChanged() { root.sync() }
        function onSlidesJsonChanged() { root.sync() }
        function onSlideshowOrderChanged() { root.sync() }
        function onTransitionMsChanged() { root.sync() }
        function onIntervalMinutesChanged() { root.sync() }
        function onWallpaperEnabledChanged() { root.sync() }
        function onReducedMotionChanged() { root.sync() }
    }
}
