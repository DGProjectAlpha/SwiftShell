import QtQuick
import "../components"
import "../logic/notifications.js" as Notifications
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
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
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Notifications"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "SwiftShell does not own notifications unless you confirm a request. The default is off, so another program keeps the bus. Quickshell 0.2 does not expose the D-Bus name result: SwiftShell reports ownership as observed only after notification traffic arrives. A current owner is not stopped or replaced."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        ServiceStatus {
            name: "Owner"
            detail: page.ownershipDetail()
        }

        FlatButton {
            visible: page.shows("notificationOwner")
            label: SettingsStore.notificationOwnership === "on" ? "Release notifications" : (page.arm === "own" ? "Confirm ownership" : "Own notifications")
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
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
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
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "This is a preview. It was not sent by another application, and showing it does not take the bus."
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
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
            text: "The preview card is labeled Preview. It is not a notification from another application, and showing it does not take the bus."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Notification sounds are not played. This shell has no sound trigger for them."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            text: "Per application"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        TextInput {
            id: policyId
            width: parent.width
            height: Theme.controlHeight
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            selectByMouse: true
            clip: true
            Accessible.name: "Desktop id"
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: "Show"
                onActivated: SettingsStore.setNotificationPolicy(policyId.text, "show")
            }

            FlatButton {
                label: "Quiet"
                onActivated: SettingsStore.setNotificationPolicy(policyId.text, "quiet")
            }

            FlatButton {
                label: "Hide"
                onActivated: SettingsStore.setNotificationPolicy(policyId.text, "hide")
            }

            FlatButton {
                label: "Clear rule"
                onActivated: SettingsStore.setNotificationPolicy(policyId.text, "")
            }
        }

        Repeater {
            model: Notifications.policyRows(SettingsStore.notificationPoliciesJson)

            delegate: Text {
                required property var modelData
                width: column.width
                text: modelData.id + " " + modelData.value
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
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
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Repeater {
                    model: modelData.items

                    delegate: Text {
                        required property var modelData
                        width: column.width
                        text: modelData.summary
                        color: Theme.panelMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
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
