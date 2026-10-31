import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../components"
import "../logic/audio.js" as Audio
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio
    readonly property bool sourceReady: sourceNode !== null && sourceNode.audio
    readonly property bool pipeReady: Pipewire.ready === true
    property var gestureSink: null
    property string gestureSinkId: ""

    function listedNodes() {
        try {
            return Audio.objectValues(Pipewire.nodes)
        } catch (error) {
            return []
        }
    }

    function nodeById(id) {
        var list = listedNodes()
        for (var index = 0; index < list.length; index++) {
            if (Audio.sinkIdentity(list[index] ? list[index].id : null) === id)
                return list[index]
        }
        return null
    }

    function applyStream(id, next) {
        var node = nodeById(id)
        var command = Audio.volumeWrite({
            ready: node !== null && node.audio,
            gestureSinkId: id,
            currentSinkId: Audio.sinkIdentity(node ? node.id : null),
            muted: node !== null && node.audio && node.audio.muted === true,
            requested: next
        })
        if (!command)
            return
        try {
            node.audio.volume = command.volume
            node.audio.muted = command.muted
        } catch (error) {
            console.warn("SwiftShell: the application volume was not changed")
        }
    }

    function chooseDefault(node, role) {
        var command = Audio.selectDefault({
            ready: pipeReady,
            requestedId: node ? node.id : null,
            currentId: role === "source" ? (sourceNode ? sourceNode.id : null) : (sink ? sink.id : null),
            devices: role === "source" ? Audio.audioDevices(listedNodes(), "source") : Audio.audioDevices(listedNodes(), "sink"),
            role: role
        })
        if (!command)
            return
        try {
            if (role === "source")
                Pipewire.preferredDefaultAudioSource = node
            else
                Pipewire.preferredDefaultAudioSink = node
        } catch (error) {
            console.warn("SwiftShell: the audio device was not changed")
        }
    }

    function percentText() {
        if (volumeSlider && volumeSlider.adjusting)
            return String(Audio.percent(volumeSlider.value))
        if (!ready)
            return ""
        return String(Audio.percent(sink.audio.volume))
    }

    function applyVolume(next) {
        const target = gestureSink
        const currentId = Audio.sinkIdentity(target ? target.id : null)
        const command = Audio.volumeWrite({
            ready: target !== null && target.audio,
            gestureSinkId: gestureSinkId,
            currentSinkId: currentId,
            muted: target !== null && target.audio && target.audio.muted === true,
            requested: next,
        })
        if (!command)
            return
        try {
            target.audio.volume = command.volume
            target.audio.muted = command.muted
        } catch (error) {
            console.warn("SwiftShell: audio volume was not changed")
        }
    }

    function applyMute(muted) {
        const target = sink
        const id = Audio.sinkIdentity(target ? target.id : null)
        const command = Audio.muteWrite({
            ready: target !== null && target.audio,
            sinkId: id,
            muted: muted === true,
        })
        if (!command || sink !== target)
            return
        if (Audio.sinkIdentity(target.id) !== command.sinkId)
            return
        try {
            target.audio.muted = command.muted
        } catch (error) {
            console.warn("SwiftShell: audio mute was not changed")
        }
    }

    function trackedObjects() {
        var list = []
        if (root.sink)
            list.push(root.sink)
        if (root.sourceNode)
            list.push(root.sourceNode)
        var streams = Audio.audioStreams(root.listedNodes())
        for (var index = 0; index < streams.length; index++) {
            var node = root.nodeById(streams[index].id)
            if (node)
                list.push(node)
        }
        return list
    }

    PwObjectTracker {
        objects: root.trackedObjects()
    }

    SectionHeader {
        width: parent.width
        text: "Audio"
    }

    ServiceStatus {
        visible: !root.ready
        name: "Output"
        detail: "Unavailable"
    }

    Column {
        visible: root.ready
        width: parent.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: Audio.outputLabel(root.ready ? root.sink.description : "")
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: root.ready && root.sink.audio.muted === true ? "Unmute" : "Mute"
                enabled: root.ready
                onActivated: root.applyMute(!(root.ready && root.sink.audio.muted === true))
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.percentText()
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Accessible.role: Accessible.StaticText
                Accessible.name: "Volume " + text
            }
        }

        CompactSlider {
            id: volumeSlider
            width: parent.width
            enabled: root.ready

            Binding {
                target: volumeSlider
                property: "value"
                when: !volumeSlider.adjusting
                value: root.ready ? root.sink.audio.volume : 0
            }

            onAdjustingChanged: {
                if (adjusting) {
                    root.gestureSink = root.sink
                    root.gestureSinkId = Audio.sinkIdentity(root.sink ? root.sink.id : null)
                    return
                }
                root.gestureSink = null
                root.gestureSinkId = ""
            }
            onMoved: function (next) { root.applyVolume(next) }
        }
    }

    ServiceStatus {
        visible: !root.sourceReady
        name: "Input"
        detail: "Unavailable"
    }

    Column {
        visible: root.sourceReady
        width: parent.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: Audio.nodeName(root.sourceNode)
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }

        CompactSlider {
            id: sourceSlider
            width: parent.width
            enabled: root.sourceReady
            valueName: "Input"

            Binding {
                target: sourceSlider
                property: "value"
                when: !sourceSlider.adjusting
                value: root.sourceReady ? root.sourceNode.audio.volume : 0
            }

            onMoved: function (next) {
                var command = Audio.volumeWrite({
                    ready: root.sourceReady,
                    gestureSinkId: Audio.sinkIdentity(root.sourceNode.id),
                    currentSinkId: Audio.sinkIdentity(root.sourceNode.id),
                    muted: root.sourceNode.audio.muted === true,
                    requested: next
                })
                if (!command)
                    return
                try {
                    root.sourceNode.audio.volume = command.volume
                    root.sourceNode.audio.muted = command.muted
                } catch (error) {
                    console.warn("SwiftShell: input volume was not changed")
                }
            }
        }
    }

    Repeater {
        model: Audio.audioDevices(root.listedNodes(), "sink")

        delegate: FlatButton {
            required property var modelData
            visible: Audio.audioDevices(root.listedNodes(), "sink").length > 1
            label: modelData.label
            emphasized: Audio.sinkIdentity(root.sink ? root.sink.id : null) === modelData.id
            onActivated: root.chooseDefault(root.nodeById(modelData.id), "sink")
        }
    }

    Repeater {
        model: Audio.audioStreams(root.listedNodes())

        delegate: Row {
            required property var modelData
            width: parent.width
            spacing: Theme.panelSpacing

            Text {
                width: 120
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            CompactSlider {
                id: streamSlider
                width: Math.max(80, parent.width - 128)
                valueName: modelData.label

                Binding {
                    target: streamSlider
                    property: "value"
                    when: !streamSlider.adjusting
                    value: modelData.volume == null ? 0 : modelData.volume
                }

                onMoved: function (next) { root.applyStream(modelData.id, next) }
            }
        }
    }
}
