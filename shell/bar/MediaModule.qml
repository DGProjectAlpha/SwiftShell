import QtQuick
import Quickshell.Services.Mpris
import "../logic/media.js" as Media
import "../themes"

Item {
    id: root

    readonly property var player: Media.pickPlayer(Mpris.players)
    readonly property var controls: Media.mediaControls(player)
    readonly property string line: Media.mediaLine(player)

    implicitWidth: player === null ? 0 : Math.min(160, label.implicitWidth + (controls.toggle ? 36 : 8))
    implicitHeight: Theme.barHeight
    visible: player !== null

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(120, implicitWidth)
        text: root.line
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.controls.toggle ? 28 : 0
        height: Theme.barHeight
        enabled: root.controls.toggle
        visible: root.controls.toggle
        Accessible.role: Accessible.Button
        Accessible.name: root.controls.playing ? "Pause" : "Play"
        onClicked: {
            if (!root.player || root.player.canTogglePlaying !== true)
                return
            try {
                root.player.togglePlaying()
            } catch (error) {
                console.warn("SwiftShell: playback was not changed")
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.controls.playing ? "Pause" : "Play"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
