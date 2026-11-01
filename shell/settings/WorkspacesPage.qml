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
        spacing: Theme.settingsSpacing

        Text {
            text: "Workspaces"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Choose which workspaces appear on each screen. Automatic follows your current workspace assignments."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }
        FlatButton {
            id: refreshButton
            label: "Refresh"
            onActivated: HyprlandModel.requestSnapshot()
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: text !== ""
            text: HyprlandModel.workspaceError
            color: Theme.settingsText
            font.pixelSize: Theme.settingsFontSizeSmall
        }
        Text {
            visible: HyprlandModel.monitorChoices.length === 0
            text: "No screens are connected."
            color: Theme.settingsMuted
            font.pixelSize: Theme.settingsFontSizeSmall
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: SettingsStore.workspaceIds.length > 0
            text: "Your previous workspace choices are preserved. Choose Automatic to show all assigned workspaces."
            color: Theme.settingsMuted
            font.pixelSize: Theme.settingsFontSizeSmall
        }
        Repeater {
            model: page.shows("workspaceOutputs") ? HyprlandModel.monitorChoices : []
            delegate: Column {
                id: output
                required property var modelData
                width: column.width
                spacing: Theme.settingsSpacing
                readonly property var overrides: Workspaces.parseOverrides(SettingsStore.workspaceOutputsJson) || ({})
                readonly property bool automatic: !Object.prototype.hasOwnProperty.call(overrides, modelData.name) || overrides[modelData.name] === null
                readonly property var items: Workspaces.perMonitorItems(SettingsStore.workspaceOutputsJson, SettingsStore.workspaceIds, SettingsStore.targetMonitor, HyprlandModel.liveWorkspaces, modelData.name)
                property string editError: ""
                function currentKeys() { return items.map(function (w) { return w.key }) }
                function saveKeys(keys) {
                    editError = SettingsStore.setWorkspaceOutput(modelData.name, keys) ? "" : "Choose up to 32 unique workspace names or numbers."
                }
                function toggle(key) {
                    const keys=currentKeys();const i=keys.indexOf(key)
                    if(i<0) keys.push(key);else keys.splice(i,1)
                    saveKeys(keys)
                }
                function move(key,delta) {
                    const keys=currentKeys(),i=keys.indexOf(key),next=i+delta
                    if(i<0 || next<0 || next>=keys.length) return
                    keys.splice(i,1);keys.splice(next,0,key);saveKeys(keys)
                }
                function discovered() {
                    return HyprlandModel.liveWorkspaces.filter(function(w){return w.monitorName===modelData.name})
                }
                Text {
                    width: parent.width
                    text: output.modelData.label + " · " + output.modelData.scale + "×"
                    wrapMode: Text.WordWrap
                    color: Theme.settingsText
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSize
                    font.weight: Font.Medium
                }
                Flow {
                    width: parent.width
                    spacing: Theme.settingsSpacing
                    FlatButton {
                        label: "Automatic"
                        emphasized: output.automatic
                        onActivated: {
                            SettingsStore.setWorkspaceOutput(output.modelData.name, null)
                        }
                    }
                    FlatButton {
                        label: "Custom"
                        emphasized: !output.automatic
                        onActivated: SettingsStore.setWorkspaceOutput(output.modelData.name, output.currentKeys())
                    }
                }
                Text {
                    width: parent.width
                    text: output.items.length ? output.items.map(function (w) { return w.name + (w.active ? " · active" : "") + (w.elsewhere ? " · on another screen" : w.windows === 0 ? " · empty" : "") }).join("   /   ") : "No indicators selected"
                    wrapMode: Text.WordWrap
                    color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                }
                Flow {
                    width:parent.width;spacing:6;visible:!output.automatic
                    Repeater {
                        model:output.discovered()
                        delegate:FlatButton {
                            required property var modelData
                            label:modelData.name
                            emphasized:output.currentKeys().indexOf(modelData.key)>=0
                            onActivated:output.toggle(modelData.key)
                            Accessible.name:"Toggle workspace " + modelData.name
                        }
                    }
                }
                Column {
                    width:parent.width;spacing:4;visible:!output.automatic
                    Repeater {
                        model:output.items
                        delegate:Row {
                            required property var modelData
                            required property int index
                            width:parent.width;spacing:6
                            Text {width:150;height:28;verticalAlignment:Text.AlignVCenter;text:modelData.name;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;elide:Text.ElideRight}
                            FlatButton {label:"↑";enabled:index>0;Accessible.name:"Move " + modelData.name + " earlier";onActivated:output.move(modelData.key,-1)}
                            FlatButton {label:"↓";enabled:index<output.items.length-1;Accessible.name:"Move " + modelData.name + " later";onActivated:output.move(modelData.key,1)}
                            FlatButton {label:"×";Accessible.name:"Remove " + modelData.name;onActivated:output.toggle(modelData.key)}
                        }
                    }
                }
                Row {
                    width:parent.width;spacing:8;visible:!output.automatic
                    Rectangle {
                        width:Math.min(230,parent.width-140);height:32;radius:5;color:Theme.settingsHover
                        Text {anchors.fill:parent;anchors.leftMargin:10;verticalAlignment:Text.AlignVCenter;visible:editor.text === "";text:"Workspace name or number";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                        TextInput {
                            id:editor
                            anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10
                            verticalAlignment:TextInput.AlignVCenter
                            color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                            selectByMouse:true;activeFocusOnTab:true;clip:true
                            Accessible.name:"New workspace for " + output.modelData.name
                            function add() {const key=Workspaces.workspaceKey(text);if(!key) return;output.saveKeys(output.currentKeys().concat([key]));if(output.editError === "")text=""}
                            onAccepted:add()
                        }
                    }
                    FlatButton {label:"Add workspace";enabled:editor.text.trim()!=="";onActivated:editor.add()}
                }
                Text {
                    visible: output.editError !== ""
                    width: parent.width
                    text: output.editError
                    wrapMode: Text.WordWrap
                    color: Theme.settingsText
                    font.pixelSize: Theme.settingsFontSizeSmall
                }
            }
        }
    }
}
