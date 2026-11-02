import QtQuick
import Quickshell.Services.Mpris
import "../components"
import "../logic/media.js" as Media
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth

    readonly property var player: Media.pickPlayer(Mpris.players)
    readonly property var controls: Media.mediaControls(player)

    Row {
        width:parent.width
        SectionHeader {width:parent.width-36;text:"Now playing"}
        Row {
            width:28;height:14;spacing:3
            visible:root.controls.playing
            Repeater {
                model:4
                delegate:Rectangle {
                    required property int index
                    width:3;height:5+index*2;radius:1.5
                    anchors.bottom:parent.bottom
                    color:Theme.settingsMuted
                    SequentialAnimation on height {
                        running:root.visible && root.controls.playing && !Theme.reducedMotion
                        loops:Animation.Infinite
                        NumberAnimation {to:13;duration:420+index*80;easing.type:Easing.InOutSine}
                        NumberAnimation {to:4;duration:360+index*90;easing.type:Easing.InOutSine}
                    }
                }
            }
        }
    }

    ServiceStatus {
        visible: root.player === null
        name: "Player"
        detail: "No player"
    }

    Column {
        visible: root.player !== null
        width: parent.width
        spacing: Theme.panelSpacing

        Row {
            spacing: Theme.panelSpacing
            width: parent.width

            Image {
                visible: root.controls.art !== ""
                source: root.controls.art
                width: 56
                height: 56
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                width: parent.width - (root.controls.art !== "" ? 56 + Theme.panelSpacing : 0)
                textFormat:Text.PlainText
                anchors.verticalCenter:parent.verticalCenter
                text: Media.mediaLine(root.player)
                color: Theme.settingsText
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: "⏮"
                width:52
                Accessible.name:"Previous track"
                enabled: root.controls.previous
                onActivated: {
                    if (!root.player || root.player.canGoPrevious !== true)
                        return
                    try {
                        root.player.previous()
                    } catch (error) {
                        console.warn("SwiftShell: the player did not go back")
                    }
                }
            }

            FlatButton {
                label: root.controls.playing ? "Ⅱ" : "▶"
                width:76
                Accessible.name:root.controls.playing ? "Pause playback" : "Play"
                enabled: root.controls.toggle
                onActivated: {
                    if (!root.player || root.player.canTogglePlaying !== true)
                        return
                    try {
                        root.player.togglePlaying()
                    } catch (error) {
                        console.warn("SwiftShell: playback was not changed")
                    }
                }
            }

            FlatButton {
                label: "⏭"
                width:52
                Accessible.name:"Next track"
                enabled: root.controls.next
                onActivated: {
                    if (!root.player || root.player.canGoNext !== true)
                        return
                    try {
                        root.player.next()
                    } catch (error) {
                        console.warn("SwiftShell: the player did not advance")
                    }
                }
            }
        }
    }
}
