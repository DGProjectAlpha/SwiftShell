import QtQuick
import "../services"
import "../logic/media.js" as Media
import "../themes"

Item {
    id: root

    readonly property var player: MediaService.player
    readonly property var controls: Media.mediaControls(player)
    readonly property string line: Media.mediaLine(player)
    property color textPrimary: Theme.textPrimary
    property color textMuted: Theme.textMuted

    implicitWidth: player === null ? 0 : Math.min(160, label.implicitWidth + (controls.toggle ? 36 : 8))
    implicitHeight: Theme.barHeight
    visible: player !== null

    Text {
        renderType:Theme.barTextRendering(root)
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(120, implicitWidth)
        text: root.line
        textFormat:Text.PlainText
        color: root.textPrimary
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
        onClicked: MediaService.act("toggle")

        Text {
            renderType:Theme.barTextRendering(root)
            anchors.centerIn: parent
            text: root.controls.playing ? "Pause" : "Play"
            color: root.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
