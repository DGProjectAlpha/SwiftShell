import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../services"
import "../themes"
import "../logic/notifications.js" as Notes

Item {
    id:card
    required property var entry
    objectName:"notificationCard-"+entry.id
    property bool compact:false
    property bool banner:false
    property bool grouped:false
    readonly property bool hiddenPreview:banner && SettingsStore.notificationPreviewMode==="app-only"
    property int draftId:0
    function focusReply() {if(entry.hasInlineReply && entry.nativeAlive && !banner){replyField.forceActiveFocus();return true}return false}
    function sendReply() {if(NotificationsModel.sendReply(entry.id,replyField.text)){replyField.text="";return true}return false}
    function iconSource() {
        const source=Notes.safeImageSource(entry.appIcon)
        if(source)return source
        return typeof entry.appIcon==="string" && /^[a-zA-Z0-9_.+-]+$/.test(entry.appIcon) ? Quickshell.iconPath(entry.appIcon,true) : ""
    }
    onEntryChanged:if(entry.id!==draftId || !entry.nativeAlive){draftId=entry.id;if(replyField)replyField.text=""}

    property int snoozeMinutes:5
    readonly property bool hovered:hover.containsMouse || replyField.activeFocus
    readonly property bool canOpen:entry.nativeAlive && entry.actions && entry.actions.some(function(action){return action.identifier==="default"})
    implicitHeight:content.implicitHeight
    height:implicitHeight
    MouseArea {
        id:hover;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.NoButton
    }
    MouseArea {
        objectName:"notificationOpen"
        anchors.fill:parent;z:-1;enabled:card.canOpen
        cursorShape:Qt.PointingHandCursor
        onClicked:NotificationsModel.invoke(card.entry.id,"default")
        Accessible.role:Accessible.Button
        Accessible.name:"Open notification from "+card.entry.appName
    }
    Column {
        id:content;width:card.width;spacing:6
        Row {
            width:parent.width;spacing:6
            Image {
                id:appIcon
                width:visible ? 18 : 0;height:18
                visible:source.toString()!=="" && status!==Image.Error
                source:card.iconSource();sourceSize:Qt.size(24,24)
                fillMode:Image.PreserveAspectFit;asynchronous:true
            }
            Text {
                width:parent.width-dismiss.width-6-(appIcon.visible ? 24 : 0)
                text:(card.grouped ? Qt.formatDateTime(new Date(card.entry.receivedAt),SettingsStore.use24Hour ? "ddd HH:mm" : "ddd h:mm AP") : card.entry.appName)+(card.entry.urgency==="critical" ? " · Important" : "")
                elide:Text.ElideRight;color:Theme.settingsMuted
                font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
                textFormat:Text.PlainText
            }
            FlatButton {
                id:dismiss;objectName:"notificationDismiss";label:"×";width:24;height:22
                Accessible.name:"Dismiss notification"
                onActivated:NotificationsModel.dismiss(card.entry.id)
            }
        }
        Text {
            width:parent.width;text:card.hiddenPreview ? "New notification" : card.entry.summary;wrapMode:Text.WordWrap
            maximumLineCount:3;elide:Text.ElideRight;textFormat:Text.PlainText
            color:Theme.settingsText;font.family:Theme.settingsFontFamily
            font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium
        }
        Text {
            visible:!card.hiddenPreview && card.entry.body!=="";width:parent.width;text:card.hiddenPreview ? "" : card.entry.body
            wrapMode:Text.WordWrap;maximumLineCount:card.compact ? 3 : 5;elide:Text.ElideRight
            textFormat:Text.PlainText;color:Theme.settingsMuted
            font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Image {
            objectName:"notificationImage"
            width:parent.width;height:visible ? Math.min(140,Math.max(48,implicitHeight)) : 0
            visible:!card.hiddenPreview && !!card.entry.image && card.entry.nativeAlive && status!==Image.Error
            source:card.hiddenPreview || !card.entry.nativeAlive ? "" : Notes.safeImageSource(card.entry.image)
            sourceSize:Qt.size(360,140);fillMode:Image.PreserveAspectFit;asynchronous:true
        }
        Flow {
            width:parent.width;spacing:4
            Repeater {
                model:card.hiddenPreview ? [] : card.entry.actions || []
                delegate:FlatButton {
                    required property var modelData
                    visible:modelData.identifier!=="default"
                    enabled:card.entry.nativeAlive
                    width:Math.min(140,implicitWidth)
                    label:modelData.text
                    onActivated:NotificationsModel.invoke(card.entry.id,modelData.identifier)
                }
            }
            FlatButton {
                visible:card.banner && !card.hiddenPreview && card.entry.hasInlineReply && card.entry.nativeAlive
                objectName:"notificationReplyOpen";label:"Reply…"
                onActivated:NotificationsModel.startReply(card.entry.id)
            }
            FlatButton {
                visible:card.canOpen;label:"Open"
                onActivated:NotificationsModel.invoke(card.entry.id,"default")
            }
            FlatButton {
                visible:!card.entry.preview && !card.entry.transient
                objectName:"notificationSnooze"
                label:card.entry.snoozedUntil>0 ? "Show now" : "Snooze"
                onActivated:{
                    if(card.entry.snoozedUntil>0) NotificationsModel.showNow(card.entry.id)
                    else NotificationsModel.snooze(card.entry.id,card.snoozeMinutes)
                }
            }
            ChoiceBox {
                visible:!card.entry.preview && !card.entry.transient && card.entry.snoozedUntil<=0
                width:100;height:Theme.controlHeight
                choices:[{label:"5 min",value:5},{label:"15 min",value:15},{label:"1 hour",value:60}]
                selectedValue:card.snoozeMinutes
                onChosen:function(value){card.snoozeMinutes=value}
                Accessible.name:"Snooze duration"
            }
        }
        Row {
            width:parent.width;spacing:6
            visible:!card.banner && card.entry.nativeAlive && card.entry.hasInlineReply
            Controls.TextField {
                id:replyField
                objectName:"notificationReplyField"
                width:parent.width-sendButton.width-parent.spacing;height:Theme.controlHeight
                maximumLength:4096;selectByMouse:true
                placeholderText:card.entry.replyPlaceholder || "Reply…"
                placeholderTextColor:Theme.settingsMuted
                color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                selectionColor:Theme.settingsSelected;selectedTextColor:Theme.settingsText
                background:Rectangle {radius:Theme.controlRadius;color:Theme.settingsHover;border.width:replyField.activeFocus ? 1 : 0;border.color:Theme.settingsMuted}
                onAccepted:card.sendReply()
                Accessible.name:"Reply to "+card.entry.appName
            }
            FlatButton {id:sendButton;objectName:"notificationReplySend";label:"Send";enabled:replyField.text.trim()!=="";onActivated:card.sendReply()}
        }
        Text {
            visible:card.entry.snoozedUntil>0;width:parent.width
            text:"Returns at "+new Date(card.entry.snoozedUntil).toLocaleTimeString(Qt.locale(),"hh:mm")
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
    }
}
