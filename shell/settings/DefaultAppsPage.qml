import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../services"
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"defaultApps"
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function focusHighlight() {refreshButton.forceActiveFocus()}
    function moveHighlight(delta) {revealRequested(0,height)}
    Component {
        id:roleDelegate
Column {
                    id:roleRow
                    required property var modelData
                    width:column.width
                    spacing:4
                    readonly property var selected: modelData.choices.find(function(app){return app.id===roleRow.modelData.current})
                    SettingsRow {
                        width:parent.width
                        label:roleRow.modelData.label
                        Row {
                            spacing:6
                            Image {width:24;height:24;anchors.verticalCenter:parent.verticalCenter;source:roleRow.selected && roleRow.selected.icon ? (roleRow.selected.icon.charAt(0)==="/" ? roleRow.selected.icon : Quickshell.iconPath(roleRow.selected.icon,true)) : "";fillMode:Image.PreserveAspectFit}
                            ChoiceBox {
                                objectName:"defaultApp-"+roleRow.modelData.id
                                width:Math.min(270,Math.max(150,page.width*.43))
                                choices:roleRow.modelData.choices.map(function(app){return {label:app.name,value:app.id}})
                                selectedValue:roleRow.modelData.current || ""
                                customLabel:roleRow.modelData.currentName
                                enabled:!DefaultAppsService.busy && choices.length>0
                                onChosen:function(value){DefaultAppsService.choose(roleRow.modelData.id,value)}
                            }
                            FlatButton {label:"Open";enabled:!DefaultAppsService.busy && roleRow.modelData.current!=="";onActivated:DefaultAppsService.launch(roleRow.modelData.id)}
                            FlatButton {label:"Undo";enabled:!DefaultAppsService.busy && roleRow.modelData.canReset;onActivated:DefaultAppsService.reset(roleRow.modelData.id)}
                        }
                    }
                    Text {
                        width:parent.width
                        text:roleRow.modelData.choices.length===0 ? "No installed application advertises this role." : roleRow.modelData.shellOnly ? "Used by SwiftShell. This role has no standard desktop-wide association." : "Desktop default · "+roleRow.modelData.currentName
                        color:Theme.settingsMuted
                        font.family:Theme.settingsFontFamily
                        font.pixelSize:Theme.settingsFontSizeSmall
                        wrapMode:Text.WordWrap
                    }
                    Item {width:1;height:8}
                }
    }
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {text:"Default applications";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}

        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Choose the apps that open links, files and desktop tools.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}

        Row {
            spacing:8
            FlatButton {id:refreshButton;label:DefaultAppsService.busy ? "Refreshing…" : "Refresh";enabled:!DefaultAppsService.busy;onActivated:DefaultAppsService.refresh()}
            Text {anchors.verticalCenter:parent.verticalCenter;text:DefaultAppsService.roles.length+" application roles";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }

        Text {width:parent.width;visible:text!=="";text:DefaultAppsService.error;wrapMode:Text.WordWrap;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}

        SettingsSection {
            sectionId:"defaultApps.internet"
            searchKeywords:"default applications browser web email"
            title:"Internet"
            description:""
            searchQuery:page.query
            controlIds:[]
            width:parent.width
            Repeater {
                model:DefaultAppsService.roles.filter(function(role){return ["browser", "email"].indexOf(role.id)>=0})
                delegate:roleDelegate
            }
        }

        SettingsSection {
            sectionId:"defaultApps.desktop"
            searchKeywords:"default applications terminal calendar file manager"
            title:"Desktop tools"
            description:""
            searchQuery:page.query
            controlIds:[]
            width:parent.width
            Repeater {
                model:DefaultAppsService.roles.filter(function(role){return ["calendar", "terminal", "files"].indexOf(role.id)>=0})
                delegate:roleDelegate
            }
        }

        SettingsSection {
            sectionId:"defaultApps.files"
            searchKeywords:"default applications images media video music pdf viewer"
            title:"Files & media"
            description:""
            searchQuery:page.query
            controlIds:[]
            width:parent.width
            Repeater {
                model:DefaultAppsService.roles.filter(function(role){return ["images", "media", "pdf"].indexOf(role.id)>=0})
                delegate:roleDelegate
            }
        }
    }
}
