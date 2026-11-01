import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../logic/workspaces.js" as Workspaces
import "../services"
import "../themes"

Item {
    id: page
    property string query: ""
    property string highlightId: "workspaceOutputs"
    signal revealRequested(real y, real itemHeight)
    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function moveHighlight(delta) { highlightId = "workspaceOutputs"; revealRequested(0, height) }
    function focusHighlight() { refreshButton.forceActiveFocus() }
    function shows(id) { return Nav.controlVisible(query, id) }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            text: "Workspaces"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Each screen has its own workspace row and active mark. Automatic includes empty persistent workspaces, monitor rules, and named workspaces. Overrides change the bar only; they do not rewrite compositor assignments."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
        FlatButton {
            id: refreshButton
            label: "Refresh discovery"
            onActivated: HyprlandModel.requestSnapshot()
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: text !== ""
            text: HyprlandModel.workspaceError
            color: Theme.panelText
            font.pixelSize: Theme.fontSizeSmall
        }
        Text {
            visible: HyprlandModel.monitorChoices.length === 0
            text: "No monitors discovered. Hyprland IPC must be available."
            color: Theme.panelMuted
            font.pixelSize: Theme.fontSizeSmall
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: SettingsStore.workspaceIds.length > 0
            text: "Legacy global IDs are preserved and matched to their observed monitors. Choose Automatic on each monitor to use full discovery, or save an independent override."
            color: Theme.panelMuted
            font.pixelSize: Theme.fontSizeSmall
        }
        Repeater {
            model: page.shows("workspaceOutputs") ? HyprlandModel.monitorChoices : []
            delegate: Column {
                id: output
                required property var modelData
                width: column.width
                spacing: Theme.panelSpacing
                readonly property var overrides: Workspaces.parseOverrides(SettingsStore.workspaceOutputsJson) || ({})
                readonly property bool automatic: !Object.prototype.hasOwnProperty.call(overrides, modelData.name) || overrides[modelData.name] === null
                readonly property var items: Workspaces.perMonitorItems(SettingsStore.workspaceOutputsJson, SettingsStore.workspaceIds, SettingsStore.targetMonitor, HyprlandModel.liveWorkspaces, modelData.name)
                property string editError: ""
                function currentKeys() { return items.map(function (w) { return w.key }) }
                function save() {
                    const keys = editor.text.trim() === "" ? [] : editor.text.split(",").map(function (s) { return s.trim() })
                    editError = SettingsStore.setWorkspaceOutput(modelData.name, keys) ? "" : "Use unique numbers or names, separated by commas (up to 32)."
                }
                Text {
                    width: parent.width
                    text: output.modelData.label + " · " + output.modelData.scale + "×"
                    wrapMode: Text.WordWrap
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                }
                Flow {
                    width: parent.width
                    spacing: Theme.panelSpacing
                    FlatButton {
                        label: "Automatic"
                        emphasized: output.automatic
                        onActivated: {
                            SettingsStore.setWorkspaceOutput(output.modelData.name, null)
                        }
                    }
                    FlatButton {
                        label: "Override"
                        emphasized: !output.automatic
                        onActivated: SettingsStore.setWorkspaceOutput(output.modelData.name, output.currentKeys())
                    }
                }
                Text {
                    width: parent.width
                    text: output.items.length ? output.items.map(function (w) { return w.name + (w.active ? " · active" : "") + (w.elsewhere ? " · on another screen" : w.windows === 0 ? " · empty" : "") }).join("   /   ") : "No indicators selected"
                    wrapMode: Text.WordWrap
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                TextInput {
                    id: editor
                    width: parent.width
                    height: Theme.controlHeight
                    visible: !output.automatic
                    Component.onCompleted: text = output.currentKeys().join(", ")
                    onVisibleChanged: if (visible) text = output.currentKeys().join(", ")
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    selectByMouse: true
                    activeFocusOnTab: true
                    clip: true
                    Accessible.name: "Workspace numbers or names for " + output.modelData.name
                    onAccepted: output.save()
                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        color: Theme.transparent
                        border.width: editor.activeFocus ? 1 : 0
                        border.color: Theme.panelMuted
                        radius: Theme.controlRadius
                    }
                }
                FlatButton {
                    visible: !output.automatic
                    label: "Save workspaces"
                    onActivated: output.save()
                }
                Text {
                    visible: output.editError !== ""
                    width: parent.width
                    text: output.editError
                    wrapMode: Text.WordWrap
                    color: Theme.panelText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
