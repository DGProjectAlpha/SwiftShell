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
    property int transitionGeneration: 0
    property var allOutputs: []
    property var expectedOutputs: []
    property var loadedOutputs: ({})
    property var finishedOutputs: ({})
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

    function settingsAction(type) {
        return {
            type: type,
            enabled: SettingsStore.slideshow && SettingsStore.wallpaperEnabled,
            paths: Slideshow.parseList(SettingsStore.slidesJson),
            mode: SettingsStore.slideshowOrder,
            transitionMs: SettingsStore.reducedMotion ? 0 : SettingsStore.transitionMs,
            intervalMinutes: SettingsStore.intervalMinutes
        }
    }

    function sync() {
        root.apply(Slideshow.reduceSlideshow(root.session, root.settingsAction("configure"),
                                             { resolveSource: Wallpaper.resolveSource }))
        root.refreshExpectedOutputs()
        root.resetBarrier()
    }

    function updatePaths() {
        root.apply(Slideshow.reduceSlideshow(root.session, root.settingsAction("updatePaths"),
                                             { resolveSource: Wallpaper.resolveSource }))
        root.resetBarrier()
    }

    function updateMode() {
        root.apply(Slideshow.reduceSlideshow(root.session, root.settingsAction("updateMode"),
                                             { resolveSource: Wallpaper.resolveSource }))
        root.resetBarrier()
    }

    function updateTiming() {
        root.apply(Slideshow.reduceSlideshow(root.session, root.settingsAction("updateTiming")))
    }

    function setOutputs(names) {
        var next = []
        var source = names || []
        for (var index = 0; index < source.length; index++) {
            var name = String(source[index] || "")
            if (name !== "" && next.indexOf(name) === -1)
                next.push(name)
        }
        root.allOutputs = next
        root.refreshExpectedOutputs()
        root.completeBarrierIfReady()
    }

    function refreshExpectedOutputs() {
        var next = []
        for (var index = 0; index < root.allOutputs.length; index++) {
            var name = root.allOutputs[index]
            var choice = Wallpaper.sourceForOutput(name, SettingsStore.wallpaperPath,
                                                   SettingsStore.wallpaperOutputsJson)
            if (!choice.override)
                next.push(name)
        }
        if (root.slideState === "preloading" || root.slideState === "transitioning") {
            var retained = []
            for (var expectedIndex = 0; expectedIndex < root.expectedOutputs.length; expectedIndex++) {
                if (next.indexOf(root.expectedOutputs[expectedIndex]) !== -1)
                    retained.push(root.expectedOutputs[expectedIndex])
            }
            root.expectedOutputs = retained
            return
        }
        root.expectedOutputs = next
    }

    function resetBarrier() {
        root.loadedOutputs = ({})
        root.finishedOutputs = ({})
    }

    function allReported(reports) {
        return Slideshow.barrierComplete(root.expectedOutputs, reports,
                                         root.transitionGeneration)
    }

    function report(reports, outputName) {
        if (root.expectedOutputs.length > 0 && root.expectedOutputs.indexOf(outputName) === -1)
            return reports
        var next = Object.assign({}, reports)
        next[outputName] = root.transitionGeneration
        return next
    }

    function completeBarrierIfReady() {
        if (root.slideState === "preloading" && root.allReported(root.loadedOutputs))
            root.apply(Slideshow.reduceSlideshow(root.session, { type: "loaded" }))
        if (root.slideState === "transitioning" && root.allReported(root.finishedOutputs)) {
            root.apply(Slideshow.reduceSlideshow(root.session, { type: "finish" }))
            root.refreshExpectedOutputs()
        }
    }

    function tick() {
        root.refreshExpectedOutputs()
        var next = Slideshow.reduceSlideshow(root.session, { type: "tick" })
        if (next.state === "preloading" && root.session.state !== "preloading") {
            root.transitionGeneration += 1
            root.resetBarrier()
        }
        root.apply(next)
        root.completeBarrierIfReady()
    }

    function noteLoaded(outputName, path, generation) {
        if (root.slideState !== "preloading" || path !== root.incomingPath
                || generation !== root.transitionGeneration)
            return
        root.loadedOutputs = root.report(root.loadedOutputs, outputName)
        root.completeBarrierIfReady()
    }

    function noteFinish(outputName, path, generation) {
        if (root.slideState !== "transitioning" || path !== root.incomingPath
                || generation !== root.transitionGeneration)
            return
        root.finishedOutputs = root.report(root.finishedOutputs, outputName)
        root.completeBarrierIfReady()
    }

    function noteFailed(path, generation) {
        if (path !== root.incomingPath || generation !== root.transitionGeneration)
            return
        root.apply(Slideshow.reduceSlideshow(root.session, { type: "failed" }))
        root.resetBarrier()
    }

    function noteShownFailed(path) {
        root.apply(Slideshow.reduceSlideshow(root.session, {
            type: "shownFailed",
            path: path
        }))
        root.resetBarrier()
    }

    Component.onCompleted: sync()

    Connections {
        target: SettingsStore
        function onSlideshowChanged() { root.updatePaths() }
        function onSlidesJsonChanged() { root.updatePaths() }
        function onSlideshowOrderChanged() { root.updateMode() }
        function onTransitionMsChanged() { root.updateTiming() }
        function onIntervalMinutesChanged() { root.updateTiming() }
        function onWallpaperEnabledChanged() { root.updatePaths() }
        function onReducedMotionChanged() { root.updateTiming() }
        function onWallpaperOutputsJsonChanged() {
            root.refreshExpectedOutputs()
            root.completeBarrierIfReady()
        }
    }
}
