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
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function focusHighlight() {if(highlightId==="notificationDelivery")deliveryChoice.forceActiveFocus()}
    onHighlightIdChanged:if(highlightId==="notificationDelivery")revealRequested(deliveryGroup.y,deliveryGroup.height)

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

        Column {
            id:deliveryGroup
            width:parent.width;spacing:Theme.settingsSpacing;visible:page.shows("notificationDelivery")
        SectionHeader { text:"Delivery" }
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
            label: "Show preview"
            onActivated: page.previewOpen = true
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
            text: "Notification sounds are unavailable. History content is never written to logs or saved to disk."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            text: "Per application"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize
        }

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
