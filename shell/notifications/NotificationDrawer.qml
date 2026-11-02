import QtQuick
import "../components"
import "../services"
import "../themes"
import "../logic/notifications.js" as Notifications

Item {
    id:drawer
    signal settingsRequested()
    property string filter:"all"
    readonly property var filtered:NotificationsModel.entries.filter(function(item){return drawer.filter==="snoozed" ? item.snoozedUntil>0 : item.snoozedUntil<=0})
    implicitWidth:360
    implicitHeight:column.implicitHeight
    width:implicitWidth;height:implicitHeight
    Component.onCompleted:NotificationsModel.markAllRead()
    Connections {
        target:NotificationsModel
        function onUnreadCountChanged(){if(drawer.visible && NotificationsModel.unreadCount>0) Qt.callLater(function(){if(drawer.visible && NotificationsModel.unreadCount>0) NotificationsModel.markAllRead()})}
    }
    function diagnostics(){return {count:NotificationsModel.entries.length,unread:NotificationsModel.unreadCount,snoozed:NotificationsModel.snoozedCount,filter:filter}}
    Column {
        id:column;width:drawer.width;spacing:Theme.settingsSpacing
        Row {
            width:parent.width
            Text {
                width:parent.width-clear.width;text:"Notifications"
                color:Theme.settingsText;font.family:Theme.settingsFontFamily
                font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium
            }
            FlatButton {
                id:clear;label:"Clear history";enabled:NotificationsModel.center.history.length>0
                onActivated:NotificationsModel.clearHistory()
            }
        }
        Text {
            visible:SettingsStore.notificationOwnership!=="on" || NotificationsModel.serverState!=="running"
            width:parent.width;wrapMode:Text.WordWrap
            text:SettingsStore.notificationOwnership!=="on" ? "Enable SwiftShell notifications in Settings to see notifications here." : "Waiting for notifications. Your apps can send them here."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        SettingsToggle {
            width:parent.width;label:"Do not disturb";checked:SettingsStore.notificationDnd
            onToggled:function(value){SettingsStore.setNotificationDnd(value);NotificationsModel.refreshConfiguration()}
        }
        Flow {
            width:parent.width;spacing:4
            FlatButton {label:"Pause 30 min";onActivated:NotificationsModel.pause(30)}
            FlatButton {label:"Pause 1 hour";onActivated:NotificationsModel.pause(60)}
            FlatButton {visible:SettingsStore.notificationQuietUntil>Date.now();label:"Resume";onActivated:NotificationsModel.pause(0)}
        }
        Text {
            visible:SettingsStore.notificationQuietUntil>0;width:parent.width;wrapMode:Text.WordWrap
            text:"Paused until "+new Date(SettingsStore.notificationQuietUntil).toLocaleTimeString(Qt.locale(),"hh:mm")+". Important notifications still appear."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Row {
            spacing:4
            FlatButton {label:"All";emphasized:drawer.filter==="all";onActivated:drawer.filter="all"}
            FlatButton {label:"Snoozed ("+NotificationsModel.snoozedCount+")";emphasized:drawer.filter==="snoozed";onActivated:drawer.filter="snoozed"}
        }
        Text {
            visible:drawer.filtered.length===0;width:parent.width
            text:drawer.filter==="snoozed" ? "No snoozed notifications" : "You're all caught up"
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
            topPadding:20;bottomPadding:20
        }
        Repeater {
            model:Notifications.groupHistory(drawer.filtered)
            delegate:Column {
                id:group
                required property var modelData
                property bool collapsed:false
                width:column.width;spacing:Theme.settingsSpacing
                FlatButton {
                    width:parent.width;label:(group.collapsed ? "▸ " : "▾ ")+group.modelData.app+" · "+group.modelData.items.length
                    onActivated:group.collapsed=!group.collapsed
                }
                Repeater {
                    model:group.collapsed ? [] : group.modelData.items
                    delegate:NotificationCard {required property var modelData;width:group.width;entry:modelData;compact:true}
                }
            }
        }
        FlatButton {width:parent.width;label:"Notification settings…";onActivated:drawer.settingsRequested()}
    }
}
