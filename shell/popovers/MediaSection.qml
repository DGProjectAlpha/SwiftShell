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

    SectionHeader {
        width: parent.width
        text: "Media"
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
                width: Theme.barIcon
                height: Theme.barIcon
                fillMode: Image.PreserveAspectCrop
            }

            Text {
                width: parent.width - (root.controls.art !== "" ? Theme.barIcon + Theme.panelSpacing : 0)
                text: Media.mediaLine(root.player)
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: "Previous"
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
                label: root.controls.playing ? "Pause" : "Play"
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
                label: "Next"
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
