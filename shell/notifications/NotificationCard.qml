import QtQuick
import Quickshell
import "../components"
import "../services"
import "../themes"

Item {
    id:card
    required property var entry
    property bool compact:false
    property int snoozeMinutes:5
    readonly property bool hovered:hover.containsMouse
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
            Text {
                width:parent.width-dismiss.width-6
                text:card.entry.appName+(card.entry.urgency==="critical" ? " · Important" : "")
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
            width:parent.width;text:card.entry.summary;wrapMode:Text.WordWrap
            maximumLineCount:3;elide:Text.ElideRight;textFormat:Text.PlainText
            color:Theme.settingsText;font.family:Theme.settingsFontFamily
            font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium
        }
        Text {
            visible:card.entry.body!=="";width:parent.width;text:card.entry.body
            wrapMode:Text.WordWrap;maximumLineCount:card.compact ? 3 : 5;elide:Text.ElideRight
            textFormat:Text.PlainText;color:Theme.settingsMuted
            font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Flow {
            width:parent.width;spacing:4
            Repeater {
                model:card.entry.actions || []
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
        }
        ChoiceBox {
            visible:!card.entry.preview && !card.entry.transient && card.entry.snoozedUntil<=0
            width:110
            choices:[{label:"5 minutes",value:5},{label:"15 minutes",value:15},{label:"1 hour",value:60}]
            selectedValue:card.snoozeMinutes
            onChosen:function(value){card.snoozeMinutes=value}
            Accessible.name:"Snooze duration"
        }
        Text {
            visible:card.entry.snoozedUntil>0;width:parent.width
            text:"Returns at "+new Date(card.entry.snoozedUntil).toLocaleTimeString(Qt.locale(),"hh:mm")
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
    }
}
