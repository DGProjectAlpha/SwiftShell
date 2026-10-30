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
    readonly property bool ready: sink !== null && sink.audio

    function percentText() {
        if (!ready)
            return ""
        return String(Audio.percent(sink.audio.volume))
    }

    function applyVolume(next) {
        if (!ready)
            return
        const command = Audio.volumeCommand(sink.audio.muted === true, next)
        if (!command)
            return
        try {
            sink.audio.volume = command.volume
            sink.audio.muted = command.muted
        } catch (error) {
            console.warn("SwiftShell: audio volume was not changed")
        }
    }

    function applyMute(muted) {
        if (!ready)
            return
        try {
            sink.audio.muted = muted === true
        } catch (error) {
            console.warn("SwiftShell: audio mute was not changed")
        }
    }

    PwObjectTracker {
        objects: [root.sink]
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
            width: parent.width
            enabled: root.ready
            value: root.ready ? root.sink.audio.volume : 0
            onMoved: function (next) { root.applyVolume(next) }
        }
    }
}
