import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

MouseArea {
    id: root

    readonly property int updatePrecision:clock.precision
    readonly property string labelText:(SettingsStore.clockDate ? Qt.formatDate(clock.date,Clock.datePattern(SettingsStore.clockDateFormat))+" · " : "")+Clock.formatTime(clock.date,SettingsStore.use24Hour,SettingsStore.clockSeconds)
    signal activated()
    signal calendarActivated()
    function clickTargets() {
        const date=dateHit.mapToItem(null,0,0),time=label.mapToItem(null,0,0)
        return {date:{x:date.x,y:date.y,width:dateHit.width,height:dateHit.height,visible:dateHit.visible},time:{x:time.x,y:time.y,width:label.width,height:label.height}}
    }
    property color textPrimary: Theme.textPrimary
    property color textHover: Theme.textHover

    implicitWidth: contents.implicitWidth
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: "Clock " + label.text
    Accessible.description: "Open Clock, Calendar, Timer and Stopwatch"

    Controls.ToolTip.visible:containsMouse
    Controls.ToolTip.text:Qt.formatDate(clock.date,"dddd, d MMMM yyyy")
    Controls.ToolTip.delay:600
    onClicked: activated()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    SystemClock {
        id: clock
        precision: SettingsStore.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Row {
        id:contents
        anchors.centerIn:parent
        MouseArea {
            id:dateHit
            objectName:"barDateButton"
            visible:SettingsStore.clockDate
            width:visible ? dateLabel.implicitWidth : 0
            height:Theme.barHeight
            cursorShape:Qt.PointingHandCursor
            activeFocusOnTab:true
            hoverEnabled:true
            Accessible.role:Accessible.Button
            Accessible.name:"Calendar " + dateLabel.text
            onClicked:root.calendarActivated()
            Keys.onPressed:function(event) {
                if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space) {
                    root.calendarActivated();event.accepted=true
                }
            }
            BarLabel {
                id:dateLabel
                anchors.verticalCenter:parent.verticalCenter
                text:Qt.formatDate(clock.date,Clock.datePattern(SettingsStore.clockDateFormat))
                font.family:"Noto Sans Mono"
                color:dateHit.containsMouse || dateHit.activeFocus ? root.textHover : root.textPrimary
            }
        }
        BarLabel {
            visible:SettingsStore.clockDate
            text:" · "
            font.family:"Noto Sans Mono"
            color:root.textPrimary
            anchors.verticalCenter:parent.verticalCenter
        }
        BarLabel {
            id:label
            objectName:"barTimeLabel"
            text:Clock.formatTime(clock.date,SettingsStore.use24Hour,SettingsStore.clockSeconds)
            font.family:"Noto Sans Mono"
            anchors.verticalCenter:parent.verticalCenter
            color:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary
        }
    }
}
