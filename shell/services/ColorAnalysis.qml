pragma Singleton

import QtQuick
import Quickshell
import "../logic/contrast.js" as Contrast
import "../logic/inflate.js" as Inflate
import "../logic/png.js" as Png
import "../logic/wallpaper.js" as Wallpaper

Singleton {
    id: root

    property int nextToken: 0
    property var outputs: ({})
    property var samplesByOutput: ({})
    property var sample: ({
        available: false,
        reason: "Automatic contrast is off.",
        scrim: false,
        foreground: "",
        accent: ({ r: 128, g: 128, b: 128 })
    })

    function blank(reason) {
        return {
            available: false,
            reason: reason,
            scrim: false,
            foreground: "",
            accent: { r: 128, g: 128, b: 128 }
        }
    }

    function sampleForOutput(name) {
        return root.samplesByOutput[String(name || "")] || root.sample
    }

    function setSample(name, nextSample) {
        var next = Object.assign({}, root.samplesByOutput)
        next[name] = nextSample
        root.samplesByOutput = next
        var keys = Object.keys(root.outputs)
        root.sample = keys.length > 0 && next[keys[0]] ? next[keys[0]] : nextSample
    }

    function registerOutput(name, width, height, path) {
        var key = String(name || "")
        if (key === "")
            return
        var record = {
            width: Math.round(Number(width) || 0),
            height: Math.round(Number(height) || 0),
            path: String(path || ""),
            token: 0
        }
        var previous = root.outputs[key]
        if (previous && previous.width === record.width && previous.height === record.height
                && previous.path === record.path)
            return
        var next = Object.assign({}, root.outputs)
        next[key] = record
        root.outputs = next
        root.refreshOutput(key)
    }

    function unregisterOutput(name) {
        var key = String(name || "")
        if (!root.outputs[key])
            return
        var nextOutputs = Object.assign({}, root.outputs)
        var nextSamples = Object.assign({}, root.samplesByOutput)
        delete nextOutputs[key]
        delete nextSamples[key]
        root.outputs = nextOutputs
        root.samplesByOutput = nextSamples
        var keys = Object.keys(nextOutputs)
        root.sample = keys.length > 0 && nextSamples[keys[0]]
            ? nextSamples[keys[0]] : root.blank("No wallpaper output is available.")
    }

    function refresh() {
        var keys = Object.keys(root.outputs)
        for (var index = 0; index < keys.length; index++)
            root.refreshOutput(keys[index])
    }

    function refreshOutput(name) {
        var config = root.outputs[name]
        if (!config)
            return
        if (!SettingsStore.automaticText && !SettingsStore.automaticGradient) {
            root.setSample(name, root.blank("Automatic contrast is off."))
            return
        }
        if (config.width <= 0 || config.height <= 0) {
            root.setSample(name, root.blank("The output geometry is unavailable."))
            return
        }
        var choice = Wallpaper.resolveSource(config.path)
        root.nextToken += 1
        var nextOutputs = Object.assign({}, root.outputs)
        config = Object.assign({}, config, { token: root.nextToken })
        nextOutputs[name] = config
        root.outputs = nextOutputs
        if (choice.source !== "file") {
            root.readUrl(name, config, Qt.resolvedUrl("../assets/wallpapers/swiftshell-default-crimson.png"))
            return
        }
        var lower = choice.path.toLowerCase()
        if (lower.length < 4 || lower.lastIndexOf(".png") !== lower.length - 4) {
            root.setSample(name, root.blank("Jpeg and webp are displayed, but only png pixels can be sampled in this build."))
            return
        }
        root.readUrl(name, config, Wallpaper.fileUrl(choice.path))
    }

    function readUrl(name, config, url) {
        var token = config.token
        Png.bindInflate(Inflate.inflateZlib)
        var request = new XMLHttpRequest()
        request.open("GET", url)
        request.responseType = "arraybuffer"
        request.onreadystatechange = function () {
            if (!root.outputs[name] || token !== root.outputs[name].token)
                return
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (!request.response) {
                root.setSample(name, root.blank("The png could not be read."))
                return
            }
            var decoded = Png.decodePng(request.response)
            var bands = Png.visibleBands(decoded, config.width, config.height,
                                         SettingsStore.wallpaperFit, SettingsStore.barHeight,
                                         Wallpaper.cropRect)
            root.setSample(name, Contrast.analyzeBands(bands, root.sampleForOutput(name)))
        }
        request.send()
    }

    Connections {
        target: SettingsStore
        function onAutomaticTextChanged() { root.refresh() }
        function onAutomaticGradientChanged() { root.refresh() }
        function onWallpaperFitChanged() { root.refresh() }
        function onBarHeightChanged() { root.refresh() }
    }
}
