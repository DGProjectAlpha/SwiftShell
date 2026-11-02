import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../logic/clocktools.js" as Tools
import "../services"
import "../themes"

MouseArea {
    id: root

    readonly property int updatePrecision:clock.precision
    readonly property string labelText:(SettingsStore.clockDate ? Qt.formatDate(clock.date,Clock.datePattern(SettingsStore.clockDateFormat))+" · " : "")+Clock.formatTime(clock.date,SettingsStore.use24Hour,SettingsStore.clockSeconds)
    property bool vertical:false
    readonly property bool timerVisible:ClockService.state.timer.status === "running" || ClockService.state.timer.status === "paused" || ClockService.finished
    readonly property bool stopwatchVisible:ClockService.state.stopwatch.status === "running" || ClockService.state.stopwatch.status === "paused"
    readonly property string activityText:(timerVisible ? (ClockService.finished ? "Timer finished" : "Timer " + (ClockService.state.timer.status === "paused" ? "Ⅱ " : "") + Tools.durationText(ClockService.remaining,false)) : "") + (timerVisible && stopwatchVisible ? " · " : "") + (stopwatchVisible ? "Stopwatch " + (ClockService.state.stopwatch.status === "paused" ? "Ⅱ " : "") + Tools.durationText(Math.floor(ClockService.elapsed/1000)*1000,false) : "")
    signal activityActivated(string tab)
    signal activated()
    signal calendarActivated()
    function clickTargets() {
        const date=dateHit.mapToItem(null,0,0),time=label.mapToItem(null,0,0)
        return {activity:{text:root.activityText,visible:activity.visible},date:{x:date.x,y:date.y,width:dateHit.width,height:dateHit.height,visible:dateHit.visible},time:{x:time.x,y:time.y,width:label.width,height:label.height}}
    }
    property color textPrimary: Theme.textPrimary
    property color textHover: Theme.textHover

    implicitWidth: contents.implicitWidth
    implicitHeight: root.vertical ? contents.implicitHeight : Theme.barHeight
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

    Grid {
        id:contents
        columns:root.vertical ? 1 : 5
        rowSpacing:root.vertical ? 3 : 0
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
                height:Theme.barHeight
                verticalAlignment:Text.AlignVCenter
                text:Qt.formatDate(clock.date,Clock.datePattern(SettingsStore.clockDateFormat))
                font.family:"Noto Sans Mono"
                color:dateHit.containsMouse || dateHit.activeFocus ? root.textHover : root.textPrimary
            }
        }
        BarLabel {
            visible:SettingsStore.clockDate && !root.vertical
            text:" · "
            font.family:"Noto Sans Mono"
            color:root.textPrimary
            height:Theme.barHeight
                verticalAlignment:Text.AlignVCenter
        }
        BarLabel {
            id:label
            objectName:"barTimeLabel"
            text:Clock.formatTime(clock.date,SettingsStore.use24Hour,SettingsStore.clockSeconds)
            font.family:"Noto Sans Mono"
            height:Theme.barHeight
                verticalAlignment:Text.AlignVCenter
            color:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary
        }
        MouseArea {
            id:activity
            objectName:"barClockActivity"
            visible:root.timerVisible || root.stopwatchVisible
            width:visible ? activityLabel.implicitWidth + (root.vertical ? 0 : 14) : 0
            height:Theme.barHeight
            cursorShape:Qt.PointingHandCursor
            hoverEnabled:true;activeFocusOnTab:true
            Accessible.role:Accessible.Button
            Accessible.name:root.activityText + ". Open clock tools"
            onClicked:root.activityActivated(root.timerVisible ? "timer" : "stopwatch")
            Keys.onPressed:function(event) {if(event.key===Qt.Key_Return || event.key===Qt.Key_Space){root.activityActivated(root.timerVisible ? "timer" : "stopwatch");event.accepted=true}}
            Rectangle {anchors.fill:parent;anchors.margins:2;radius:4;color:root.textPrimary;opacity:activity.containsMouse || activity.activeFocus ? .12 : .05}
            BarLabel {
                id:activityLabel
                anchors.centerIn:parent
                text:root.vertical ? root.activityText.replace(" · ","\n") : root.activityText
                font.family:"Noto Sans Mono"
                color:root.textPrimary
            }
        }
    }
}
