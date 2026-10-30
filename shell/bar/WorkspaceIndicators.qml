import QtQuick
import "../components"
import "../services"
import "../themes"

Row {
    id: root

    required property var workspaces
    spacing: Theme.workspaceGap

    Repeater {
        model: root.workspaces

        delegate: MouseArea {
            id: button

            required property var modelData
            width: Math.max(label.implicitWidth + 8, Theme.barHeight)
            height: Theme.barHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + modelData.id
            Accessible.description: modelData.active ? "Active on this monitor" : "Switch to this workspace"

            onClicked: HyprlandModel.activateWorkspace(modelData.id, SettingsStore.workspaceDispatch)

            BarLabel {
                id: label
                anchors.centerIn: parent
                text: modelData.id
                font.weight: modelData.active ? Font.Medium : Font.Normal
                color: {
                    if (modelData.active || modelData.urgent)
                        return Theme.textPrimary;
                    if (button.containsMouse)
                        return Theme.textHover;
                    return Theme.textMuted;
                }
            }

            Rectangle {
                visible: modelData.active
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: label.implicitWidth
                height: 1
                color: Theme.textPrimary
            }
        }
    }
}
