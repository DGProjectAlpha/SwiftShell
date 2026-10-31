import QtQuick
import Quickshell
import "../components"
import "../logic/launcher.js" as Launcher
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth
    property string confirmId: ""
    property string notice: ""

    SectionHeader {
        width: parent.width
        text: "Power"
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Lock, suspend, restart, and shut down ask once more before loginctl runs. The search field is not part of that command."
        color: Theme.panelMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Repeater {
        model: Launcher.POWER

        delegate: FlatButton {
            required property var modelData
            label: root.confirmId === modelData.id ? "Confirm " + modelData.label : modelData.label
            emphasized: root.confirmId === modelData.id
            onActivated: {
                var step = Launcher.powerInvocation(root.confirmId, modelData.id)
                root.confirmId = step.confirmId
                if (!step.run) {
                    if (step.error !== "")
                        root.notice = step.error
                    return
                }
                try {
                    Quickshell.execDetached({ command: step.argv })
                    root.notice = modelData.label + " was requested."
                    console.info("SwiftShell: power action", modelData.id)
                } catch (error) {
                    root.confirmId = ""
                    root.notice = "Could not run the power action"
                    console.warn("SwiftShell: power action failed", modelData.id)
                }
            }
        }
    }

    Text {
        visible: root.notice !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.notice
        color: Theme.panelText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
