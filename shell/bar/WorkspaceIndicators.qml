import QtQuick
import "../components"
import "../services"
import "../themes"

Grid {
    id: root
    property bool vertical:false
    columns:vertical ? 3 : Math.max(1,stableItems.count)

    required property var workspaces
    property string monitorName: ""
    property color textPrimary: Theme.textPrimary
    property color textMuted: Theme.textMuted
    property color textHover: Theme.textHover
    spacing: Theme.workspaceGap

    KeyedModel { id: stableItems; entries: root.workspaces }

    Repeater {
        objectName: "workspaceRepeater"
        model: stableItems

        delegate: MouseArea {
            id: button

            required property var entry
            readonly property var modelData: entry
            width: Math.min(160, Math.max(label.implicitWidth + 8, Theme.barHeight))
            height: Theme.barHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + modelData.name
            Accessible.description: modelData.active ? "Active on this monitor" : "Switch to this workspace"

            onClicked: HyprlandModel.activateWorkspace(modelData.key || modelData.id, SettingsStore.workspaceDispatch, root.monitorName)

            BarLabel {
                id: label
                anchors.centerIn: parent
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                text: modelData.name
                font.weight: modelData.active ? Font.Medium : Font.Normal
                color: {
                    if (modelData.active || modelData.urgent)
                        return root.textPrimary;
                    if (button.containsMouse)
                        return root.textHover;
                    return root.textMuted;
                }
            }

            Rectangle {
                visible: modelData.active
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(label.width, label.implicitWidth)
                height: 1
                color: root.textPrimary
            }
        }
    }
}
