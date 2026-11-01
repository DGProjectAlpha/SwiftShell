import QtQuick
import "../components"
import "../logic/notifications.js" as Notifications
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

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

    function focusHighlight() {}

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    function ownershipDetail() {
        if (SettingsStore.notificationOwnership !== "on")
            return "Not SwiftShell"
        if (NotificationsModel.serverState === "running")
            return "Active; ownership observed from notification traffic"
        if (NotificationsModel.serverState === "failed")
            return "Server component failed"
        return "Requested; ownership is not observable until traffic arrives"
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
            text: "Notification handling is off by default. Enable it only after switching from your current notification app."
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
            text: "Notification sounds are unavailable."
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
            choices:[{label:"Choose an application",value:""}].concat(LauncherModel.applications.map(function(app){return {label:app.name,value:app.id}}))
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
