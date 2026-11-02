import QtQuick
import Quickshell
import "../components"
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

// The bar clock opens a small clock application, not just a month grid.
// The host owns its rounded frost, shadow, screen placement and dismissal.
Item {
    id: root
    implicitWidth: 360
    implicitHeight: column.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property string activeTab: "clock"
    readonly property string clockStyle: ClockService.state.style
    function showTab(tab) {
        if (["clock", "calendar", "timer", "stopwatch"].indexOf(tab) < 0) return;
        activeTab = tab;
        ClockService.setTab(tab);
    }
    function geometry() {
        const result = [];
        const names = ["clockToday", "clockDigital", "clockAnalogue", "timerPrimary", "timerReset",
            "stopwatchPrimary", "stopwatchLapReset", "previousMonth", "nextMonth", "openCalendarApplication"];
        function visit(item) {
            if (!item || !item.visible) return;
            const name = item.objectName || "";
            if (name.indexOf("clockTab-") === 0 || names.indexOf(name) >= 0) {
                const point = item.mapToItem(null, 0, 0);
                result.push({ id: name, x: point.x, y: point.y, width: item.width, height: item.height, enabled: item.enabled });
            }
            const children = item.children || [];
            for (let index = 0; index < children.length; index++) visit(children[index]);
        }
        visit(root);
        return result;
    }
    function diagnostics() {
        return { tab: activeTab, style: clockStyle, timerStatus: ClockService.timerStatus,
            timerRemaining: ClockService.remaining, stopwatchStatus: ClockService.state.stopwatch.status,
            stopwatchElapsed: ClockService.elapsed, laps: ClockService.state.stopwatch.laps.length,
            stateReady: ClockService.loaded, persistenceMessage: ClockService.persistenceMessage };
    }
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Column {
        id: column
        width: root.width
        spacing: 14
        Row {
            width: parent.width
            Text {
                width: parent.width - todayButton.width; height: 30
                text: "Clock"
                color: Theme.settingsText; font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSize + 5; font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
            FlatButton {
                id: todayButton
                objectName: "clockToday"
                label: Qt.formatDate(clock.date, "ddd d MMM")
                onActivated: root.showTab("calendar")
                Accessible.name: "Open calendar"
            }
        }
        Row {
            width: parent.width
            spacing: 4
            Repeater {
                model: [{ id: "clock", label: "Clock" }, { id: "calendar", label: "Calendar" },
                    { id: "timer", label: "Timer" }, { id: "stopwatch", label: "Stopwatch" }]
                delegate: FlatButton {
                    required property var modelData
                    objectName: "clockTab-" + modelData.id
                    width: (root.width - 12) / 4
                    height: 32
                    label: modelData.label
                    emphasized: root.activeTab === modelData.id
                    onActivated: root.showTab(modelData.id)
                }
            }
        }
        Loader {
            id: page
            objectName: "clockPage"
            width: parent.width
            sourceComponent: root.activeTab === "calendar" ? calendarView
                : root.activeTab === "timer" ? timerView : root.activeTab === "stopwatch" ? stopwatchView : clockView
        }
        Text {
            visible: ClockService.persistenceMessage !== ""
            width: parent.width
            text: ClockService.persistenceMessage
            wrapMode: Text.WordWrap; color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
    Component {
        id: clockView
        Item {
            implicitWidth: root.width
            implicitHeight: clockColumn.implicitHeight
            Column {
                id: clockColumn
                width: parent.width
                spacing: 14
                Item { width: 1; height: 4 }
                ClockFace {
                    visible: root.clockStyle === "analogue"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 184; height: visible ? 184 : 0
                    date: clock.date
                    showSeconds: SettingsStore.clockSeconds
                }
                Text {
                    objectName: "clockReadout"
                    width: parent.width
                    height: root.clockStyle === "digital" ? 88 : 40
                    text: Clock.formatTime(clock.date, SettingsStore.use24Hour, SettingsStore.clockSeconds)
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    color: Theme.settingsText; font.family: "Noto Sans Mono"
                    font.pixelSize: root.clockStyle === "digital" ? (SettingsStore.clockSeconds ? 42 : 54) : 24
                    font.weight: Font.Light
                }
                Text {
                    width: parent.width
                    text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.settingsMuted; font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSize
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    FlatButton { objectName: "clockDigital"; label: "Digital"; width: 110; emphasized: root.clockStyle === "digital"; onActivated: ClockService.setStyle("digital") }
                    FlatButton { objectName: "clockAnalogue"; label: "Analogue"; width: 110; emphasized: root.clockStyle === "analogue"; onActivated: ClockService.setStyle("analogue") }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    FlatButton {
                        label: SettingsStore.use24Hour ? "24-hour" : "12-hour"
                        emphasized: SettingsStore.use24Hour
                        Accessible.name: "Toggle 12 or 24 hour time"
                        onActivated: SettingsStore.setUse24Hour(!SettingsStore.use24Hour)
                    }
                    FlatButton {
                        label: "Seconds"; emphasized: SettingsStore.clockSeconds
                        onActivated: SettingsStore.setClockOptions(!SettingsStore.clockSeconds, SettingsStore.clockDate, SettingsStore.clockDateFormat)
                    }
                }
                FlatButton {
                    visible: ClockService.finished
                    width: parent.width
                    label: "Timer finished · View timer"
                    emphasized: true
                    onActivated: root.showTab("timer")
                }
            }
        }
    }
    Component { id: calendarView; ClockCalendar { width: root.width; today: clock.date } }
    Component { id: timerView; ClockTimer { width: root.width } }
    Component { id: stopwatchView; ClockStopwatch { width: root.width } }
}
