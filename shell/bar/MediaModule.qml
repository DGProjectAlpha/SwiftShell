import QtQuick
import "../services"
import "../logic/media.js" as Media
import "../themes"

Item {
    id: root
    readonly property var barSizing:Theme.barMetricsFor(root)
    function sized(value) {return Math.round(value*barSizing.sizeScale)}

    readonly property var player: MediaService.player
    readonly property var controls: Media.mediaControls(player)
    readonly property string line: Media.mediaLine(player)
    property color textPrimary: Theme.textPrimary
    property color textMuted: Theme.textMuted

    implicitWidth: player === null ? 0 : Math.min(root.sized(160), label.implicitWidth + root.sized(controls.toggle ? 36 : 8))
    implicitHeight: root.barSizing.height
    visible: player !== null

    Text {
        renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(root.sized(120), implicitWidth)
        text: root.line
        textFormat:Text.PlainText
        color: root.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: root.barSizing.bodyFont
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.controls.toggle ? root.sized(28) : 0
        height: root.barSizing.height
        enabled: root.controls.toggle
        visible: root.controls.toggle
        Accessible.role: Accessible.Button
        Accessible.name: root.controls.playing ? "Pause" : "Play"
        onClicked: MediaService.act("toggle")

        Text {
            renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting
            anchors.centerIn: parent
            text: root.controls.playing ? "Pause" : "Play"
            color: root.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: root.barSizing.smallFont
        }
    }
}
