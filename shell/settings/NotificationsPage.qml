import QtQuick
import "../components"
import "../logic/notifications.js" as Notifications
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"
import "../notifications"

Item {
    id: page

    property string query: ""
    property string policyApplication: ""
    property string highlightId: ""
    property string arm: ""
    property bool previewOpen: false
    readonly property var timeChoices: {
        const out=[];for(let value=0;value<1440;value+=15)out.push({label:Notifications.timeLabel(value),value:value});return out
    }
    function editPreference(key,value){const patch={};patch[key]=value;return SettingsStore.setNotificationPreferences(patch)}
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function focusHighlight() {if(highlightId==="notificationQuietHours")quietHoursToggle.forceActiveFocus();else if(highlightId==="notificationPrivacy")previewChoice.forceActiveFocus();else if(highlightId==="notificationSound")soundToggle.forceActiveFocus();else if(highlightId==="notificationDelivery")deliveryChoice.forceActiveFocus()}
    onHighlightIdChanged:{const item=highlightId==="notificationQuietHours" ? quietGroup : highlightId==="notificationPrivacy" ? privacyGroup : highlightId==="notificationSound" ? soundGroup : highlightId==="notificationDelivery" ? deliveryGroup : null;if(item)revealRequested(item.y,item.height)}

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    function ownershipDetail() {
        if (SettingsStore.notificationOwnership !== "on")
            return "Handled outside SwiftShell"
        if (NotificationsModel.serverState === "running")
            return "SwiftShell notifications are active"
        if (NotificationsModel.serverState === "failed")
            return "Could not start notifications"
        return "Waiting for the first notification"
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.settingsSpacing

        Text {
            width: parent.width
            text: "Notifications"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Choose how notifications appear, when to pause them and which apps may interrupt you."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        SettingsSection {
            sectionId:"notifications.owner"
            title:"Notification handling"
            description:""
            searchQuery:page.query
            controlIds:["notificationOwner", "notificationDnd"]
            width:parent.width
            ServiceStatus {
                name: "Owner"
                detail: page.ownershipDetail()
            }
            FlatButton {
                visible: page.shows("notificationOwner")
                label: SettingsStore.notificationOwnership === "on" ? "Disable notifications" : (page.arm === "own" ? "Confirm switch" : "Enable notifications")
                emphasized: page.arm === "own"
                onActivated: {
                    if (SettingsStore.notificationOwnership === "on") {
                        page.arm = ""
                        SettingsStore.setNotificationOwnership("off")
                        NotificationsModel.configure("off", SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
                        return
                    }
                    if (page.arm !== "own") {
                        page.arm = "own"
                        return
                    }
                    page.arm = ""
                    SettingsStore.setNotificationOwnership("on")
                    NotificationsModel.configure("on", SettingsStore.notificationDnd, SettingsStore.notificationPoliciesJson)
                }
            }
            SettingsToggle {
                visible: page.shows("notificationDnd")
                label: "Do not disturb"
                checked: SettingsStore.notificationDnd
                onToggled: function (next) {
                    SettingsStore.setNotificationDnd(next)
                    NotificationsModel.configure(SettingsStore.notificationOwnership, next, SettingsStore.notificationPoliciesJson)
                }
            }
        }

        SettingsSection {
            sectionId:"notifications.delivery";title:"Delivery";searchQuery:page.query;controlIds:["notificationDelivery"]

            id:deliveryGroup
            width:parent.width;spacing:Theme.settingsSpacing;visible:page.shows("notificationDelivery")
        Text {width:parent.width;text:"Banner duration";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
        ChoiceBox {
            width:Math.min(320,parent.width)
            id:deliveryChoice
            choices:[{label:"3 seconds",value:3},{label:"6 seconds",value:6},{label:"10 seconds",value:10},{label:"15 seconds",value:15},{label:"30 seconds",value:30}]
            selectedValue:SettingsStore.notificationDuration
            onChosen:function(value){SettingsStore.setNotificationPreferences({bannerDuration:value})}
            Accessible.name:"Notification banner duration"
        }
        Text {width:parent.width;text:"Show banners on";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
        ChoiceBox {
            width:Math.min(440,parent.width)
            choices:[{label:"Focused display",value:"focused"},{label:"First display",value:"primary"}].concat(HyprlandModel.monitorChoices.map(function(m){return {label:m.label,value:m.name}}))
            selectedValue:SettingsStore.notificationScreenTarget
            onChosen:function(value){SettingsStore.setNotificationPreferences({screenTarget:value})}
            Accessible.name:"Notification display"
        }
        Text {width:parent.width;text:"History limit";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
        ChoiceBox {
            width:Math.min(320,parent.width)
            choices:[{label:"20 notifications",value:20},{label:"60 notifications",value:60},{label:"100 notifications",value:100},{label:"200 notifications",value:200}]
            selectedValue:SettingsStore.notificationHistoryLimit
            onChosen:function(value){SettingsStore.setNotificationPreferences({historyLimit:value})}
            Accessible.name:"Notification history limit"
        }
        Text {
            width:parent.width;wrapMode:Text.WordWrap
            text:"History stays in memory for this session. Banner duration is used when an app does not request its own timeout. Snooze individual notifications for five minutes, fifteen minutes or an hour."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        }

        SettingsSection {
            sectionId:"notifications.quiet";title:"Quiet hours";searchQuery:page.query;controlIds:["notificationQuietHours"]

            id:quietGroup
            width:parent.width;spacing:Theme.settingsSpacing;visible:page.shows("notificationQuietHours")
            SettingsToggle {
                id:quietHoursToggle;objectName:"notificationQuietHours"
                label:"Schedule quiet hours";checked:SettingsStore.notificationQuietHoursEnabled
                onToggled:function(value){page.editPreference("quietHoursEnabled",value)}
            }
            SettingsRow {
                width:parent.width;label:"From"
                ChoiceBox {width:160;enabled:SettingsStore.notificationQuietHoursEnabled;choices:page.timeChoices;selectedValue:SettingsStore.notificationQuietStart;customLabel:Notifications.timeLabel(selectedValue);onChosen:function(value){page.editPreference("quietStart",value)}}
            }
            SettingsRow {
                width:parent.width;label:"Until"
                ChoiceBox {width:160;enabled:SettingsStore.notificationQuietHoursEnabled;choices:page.timeChoices;selectedValue:SettingsStore.notificationQuietEnd;customLabel:Notifications.timeLabel(selectedValue);onChosen:function(value){page.editPreference("quietEnd",value)}}
            }
            Flow {
                width:parent.width;spacing:4
                Repeater {
                    model:["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
                    delegate:FlatButton {
                        required property int index
                        required property string modelData
                        readonly property bool selected:(SettingsStore.notificationQuietDays & (1<<index))!==0
                        label:modelData;emphasized:selected
                        enabled:SettingsStore.notificationQuietHoursEnabled && (!selected || SettingsStore.notificationQuietDays!==(1<<index))
                        Accessible.role:Accessible.CheckBox;Accessible.checked:selected;Accessible.name:"Quiet hours on "+modelData
                        onActivated:page.editPreference("quietDays",SettingsStore.notificationQuietDays ^ (1<<index))
                    }
                }
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:NotificationsModel.scheduled ? "Quiet hours are active. Ordinary notifications wait in history; critical banners can still appear." : "Uses this computer’s local time. Overnight quiet hours finish the following day. Matching times mean all day on the selected days."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        SettingsSection {
            sectionId:"notifications.privacy";title:"Privacy";searchQuery:page.query;controlIds:["notificationPrivacy"]

            id:privacyGroup
            width:parent.width;spacing:Theme.settingsSpacing;visible:page.shows("notificationPrivacy")
            SettingsRow {
                width:parent.width;label:"Banner previews"
                ChoiceBox {
                    id:previewChoice;objectName:"notificationPreviewMode"
                    width:220;choices:[{label:"Message content",value:"full"},{label:"App name only",value:"app-only"}]
                    selectedValue:SettingsStore.notificationPreviewMode
                    onChosen:function(value){page.editPreference("previewMode",value)}
                }
            }
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"App name only hides message text, images and reply actions in banners. Open the notification drawer to read and respond.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }

        SettingsSection {
            sectionId:"notifications.sound";title:"Sound";searchQuery:page.query;controlIds:["notificationSound"]

            id:soundGroup
            width:parent.width;spacing:Theme.settingsSpacing;visible:page.shows("notificationSound")
            SettingsToggle {
                id:soundToggle;objectName:"notificationSound"
                label:"Play notification sounds";checked:SettingsStore.notificationSoundEnabled;enabled:NotificationsModel.soundAvailable || SettingsStore.notificationSoundEnabled
                onToggled:function(value){page.editPreference("soundEnabled",value)}
            }
            SettingsRow {
                width:parent.width;label:"Volume"
                Row {
                    spacing:Theme.settingsSpacing
                    Text {anchors.verticalCenter:parent.verticalCenter;text:Math.round(SettingsStore.notificationSoundVolume*100)+"%";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                    CompactSlider {enabled:SettingsStore.notificationSoundEnabled && NotificationsModel.soundAvailable;valueName:"Notification sound volume";value:SettingsStore.notificationSoundVolume;onMoved:function(value){page.editPreference("soundVolume",value)}}
                }
            }
            FlatButton {objectName:"notificationSoundPreview";label:"Preview sound";enabled:SettingsStore.notificationSoundEnabled && NotificationsModel.soundReady;onActivated:NotificationsModel.playSound()}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:NotificationsModel.soundReason || "Quiet hours, Do Not Disturb and an app’s silent hint keep sounds off. Rapid updates are kept quiet.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }

        SettingsSection {
            sectionId:"notifications.pause"
            title:"Pause & preview"
            description:""
            searchQuery:page.query
            controlIds:["notificationDnd", "notificationPreview"]
            width:parent.width
            Flow {
                width:parent.width;spacing:4
                FlatButton {label:"Pause 30 min";onActivated:NotificationsModel.pause(30)}
                FlatButton {label:"Pause 1 hour";onActivated:NotificationsModel.pause(60)}
                FlatButton {visible:SettingsStore.notificationQuietUntil>0;label:"Resume notifications";onActivated:NotificationsModel.pause(0)}
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: SettingsStore.notificationDnd ? "Critical banners still show. Other banners wait in history." : "Banners follow the notifications this shell has accepted."
                color: Theme.settingsMuted
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
            FlatButton {
                visible: page.shows("notificationPreview")
                label: SettingsStore.notificationOwnership === "on" ? "Preview banner" : "Show preview"
                onActivated: {if(SettingsStore.notificationOwnership === "on")NotificationsModel.preview();else page.previewOpen=true}
            }
            Rectangle {
                visible: page.previewOpen
                width: parent.width
                height: previewColumn.implicitHeight + Theme.panelPadding * 2
                radius: Theme.radius
                color: Theme.panelColor

                Column {
                    id: previewColumn
                    width: parent.width - Theme.panelPadding * 2
                    x: Theme.panelPadding
                    y: Theme.panelPadding
                    spacing: 4

                    Text {
                        width: parent.width
                        text: "Preview"
                        color: Theme.settingsMuted
                        font.family: Theme.settingsFontFamily
                        font.pixelSize: Theme.settingsFontSizeSmall
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "This is a preview of a SwiftShell notification."
                        color: Theme.settingsText
                        font.family: Theme.settingsFontFamily
                        font.pixelSize: Theme.settingsFontSize
                        textFormat: Text.PlainText
                    }

                    FlatButton {
                        label: "Dismiss preview"
                        onActivated: page.previewOpen = false
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Preview does not change your notification settings."
                color: Theme.settingsMuted
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "History and reply drafts stay in memory. They are never written to logs or saved to disk."
                color: Theme.settingsMuted
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
        }

        SettingsSection {
            sectionId:"notifications.applications"
            title:"Per application"
            description:""
            searchQuery:page.query
            controlIds:["notificationRules"]
            width:parent.width
            ChoiceBox {
                width:Math.min(360,parent.width)
                choices:[{label:"Choose an application",value:""},{label:"Clock timers & stopwatch",value:"swiftshell.clock"},{label:"SwiftShell",value:"swiftshell"}].concat(LauncherModel.applications.map(function(app){return {label:app.name,value:app.id}}))
                selectedValue:page.policyApplication
                onChosen:function(value){page.policyApplication=value}
                Accessible.name:"Notification application"
            }
            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "Show"
                    emphasized:page.policyApplication !== "" && Notifications.policyFor(Notifications.parsePolicies(SettingsStore.notificationPoliciesJson),page.policyApplication) === "show"
                    enabled:page.policyApplication !== ""
                    onActivated: SettingsStore.setNotificationPolicy(page.policyApplication, "show")
                }

                FlatButton {
                    label: "Quiet"
                    emphasized:page.policyApplication !== "" && Notifications.policyFor(Notifications.parsePolicies(SettingsStore.notificationPoliciesJson),page.policyApplication) === "quiet"
                    enabled:page.policyApplication !== ""
                    onActivated: SettingsStore.setNotificationPolicy(page.policyApplication, "quiet")
                }

                FlatButton {
                    label: "Hide"
                    emphasized:page.policyApplication !== "" && Notifications.policyFor(Notifications.parsePolicies(SettingsStore.notificationPoliciesJson),page.policyApplication) === "hide"
                    enabled:page.policyApplication !== ""
                    onActivated: SettingsStore.setNotificationPolicy(page.policyApplication, "hide")
                }

                FlatButton {
                    label: "Clear rule"
                    enabled:page.policyApplication !== ""
                    onActivated: SettingsStore.setNotificationPolicy(page.policyApplication, "")
                }
            }
            Repeater {
                model: Notifications.policyRows(SettingsStore.notificationPoliciesJson)

                delegate: Text {
                    required property var modelData
                    width: column.width
                    text: modelData.id + " " + modelData.value
                    color: Theme.settingsText
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                    elide: Text.ElideRight
                }
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:"Show sends banners and keeps history. Quiet keeps history without ordinary banners. Hide discards notifications from the selected app."
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        SettingsSection {
            sectionId:"notifications.history"
            title:"Recent notifications"
            description:""
            searchQuery:page.query
            controlIds:["notificationHistory"]
            width:parent.width
            Repeater {
                model: Notifications.groupHistory(NotificationsModel.center.history)

                delegate: Column {
                    required property var modelData
                    width: column.width
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.app
                        color: Theme.settingsText
                        font.family: Theme.settingsFontFamily
                        font.pixelSize: Theme.settingsFontSize
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: modelData.items

                        delegate: Text {
                            required property var modelData
                            width: column.width
                            text: modelData.summary
                            color: Theme.settingsMuted
                            font.family: Theme.settingsFontFamily
                            font.pixelSize: Theme.settingsFontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            FlatButton {
                visible: NotificationsModel.center.history.length > 0
                label: "Clear history"
                onActivated: NotificationsModel.clearHistory()
            }
        }
    }
}
