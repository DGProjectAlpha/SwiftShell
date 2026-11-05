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
    property string selectedOutput: ""
    property var activeOrder: null
    function geometry() {return {output:currentOutput,rows:activeOrder && activeOrder.visible ? activeOrder.geometry() : []}}
    readonly property string currentOutput: HyprlandModel.monitorChoices.some(function(m){return m.name===selectedOutput}) ? selectedOutput : (HyprlandModel.monitorChoices.length ? HyprlandModel.monitorChoices[0].name : "")
    signal revealRequested(real y, real itemHeight)
    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function moveHighlight(delta) { highlightId = "workspaceOutputs"; revealRequested(0, height) }
    function focusHighlight() {if(highlightId==="workspaceOverview")overviewOpen.forceActiveFocus();else refreshButton.forceActiveFocus()}
    onHighlightIdChanged:if(highlightId==="workspaceOverview")revealRequested(overviewGroup.y,overviewGroup.height)
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

        SettingsSection {
            sectionId:"workspaces.overview";title:"Overview";searchQuery:page.query;controlIds:["workspaceOverview"]

            width:parent.width;spacing:Theme.settingsSpacing
            id:overviewGroup
            SettingsToggle {
                label:"Alt + Tab opens workspace overview"
                checked:OverviewService.shortcutEnabled
                enabled:OverviewService.shortcutEnabled || OverviewService.shortcutCanEnable
                onToggled:function(value){if(value)OverviewService.enableShortcut();else OverviewService.restoreShortcut()}
            }
            FlatButton {id:overviewOpen;label:"Open overview";onActivated:OverviewService.openOverview()}
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:OverviewService.shortcutError || (OverviewService.shortcutEnabled ? "Choose a miniature window or desktop to switch. Turn this off to restore window cycling." : OverviewService.shortcutCanEnable ? "Alt + Tab can open a live view of your workspaces and windows." : "Your existing Alt + Tab shortcut is preserved. Open the overview here instead.")
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        ChoiceBox {
            width:Math.min(parent.width,440)
            choices:HyprlandModel.monitorChoices.map(function(m){return {value:m.name,label:m.label}})
            selectedValue:page.currentOutput
            Accessible.name:"Workspace screen"
            onChosen:function(value){page.selectedOutput=value}
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
            model: page.shows("workspaceOutputs") ? HyprlandModel.monitorChoices.filter(function(m){return m.name===page.currentOutput}) : []
            delegate: SettingsSection {
                sectionId:"workspaces."+modelData.name.replace(/[^A-Za-z0-9_.-]/g,"_")
                title:"Workspace indicators"
                description:modelData.label
                searchQuery:page.query
                controlIds:["workspaceOutputs"]
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
                function moveTo(key,next) {
                    const keys=currentKeys(),i=keys.indexOf(key)
                    if(i<0 || next<0 || next>=keys.length || next===i) return
                    keys.splice(i,1);keys.splice(next,0,key);saveKeys(keys)
                }
                function addNext() {
                    const keys=currentKeys();let candidate=1
                    while(keys.indexOf(String(candidate))>=0) candidate++
                    saveKeys(keys.concat([String(candidate)]))
                }
                function discovered() {
                    return HyprlandModel.liveWorkspaces.filter(function(w){return w.monitorName===modelData.name})
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
                Text {
                    visible:!output.automatic
                    text:"Drag the handles to arrange indicators. Alt J / K also moves a focused row."
                    width:parent.width;wrapMode:Text.WordWrap
                    color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
                }
                WorkspaceOrderList {
                    id:orderList
                    Component.onCompleted:page.activeOrder=orderList
                    Component.onDestruction:if(page.activeOrder===orderList)page.activeOrder=null
                    width:parent.width;visible:!output.automatic
                    entries:output.items
                    onReordered:function(key,destination){output.moveTo(key,destination)}
                    onRemoved:function(key){output.toggle(key)}
                }
                FlatButton {
                    visible:!output.automatic
                    label:"Add numbered workspace"
                    onActivated:output.addNext()
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
