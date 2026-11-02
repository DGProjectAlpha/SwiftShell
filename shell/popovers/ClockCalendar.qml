import QtQuick
import Quickshell
import "../components"
import "../logic/calendar.js" as Calendar
import "../services"
import "../themes"

Item {
    id: root
    property date today: new Date()
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDay: today.getDate()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int weekStart: Calendar.weekStartIndex(SettingsStore.weekStart, Qt.locale().firstDayOfWeek, Qt.Sunday)
    readonly property var monthModel: Calendar.buildMonth(year, month, weekStart, todayYear, todayMonth, todayDay)
    readonly property var calendarApplication: DefaultAppsService.roleInfo("calendar")
    readonly property bool calendarAvailable: !!(calendarApplication && calendarApplication.current)
    readonly property real dayWidth: (width - (SettingsStore.showWeekNumbers ? 28 : 0)) / 7
    objectName: "clockCalendar"
    implicitWidth: 360
    implicitHeight: column.implicitHeight
    function shift(delta) {
        const next = Calendar.shiftMonth(year, month, delta);
        year = next.year; month = next.month;
    }
    function showToday() {
        year = today.getFullYear(); month = today.getMonth();
        selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    }
    function selectDate(cell) {
        selectedDate = new Date(cell.year, cell.month, cell.day);
        year = cell.year; month = cell.month;
    }
    function weekdayLabel(index) {
        const jsDay = (weekStart + index) % 7;
        return Qt.locale().dayName(jsDay === 0 ? Qt.Sunday : jsDay, Locale.ShortFormat);
    }
    Column {
        id: column
        width: root.width
        spacing: 8
        Row {
            width: parent.width
            FlatButton { objectName: "previousMonth"; label: "‹"; width: 36; height: 36; Accessible.name: "Previous month"; onActivated: root.shift(-1) }
            Text {
                width: parent.width - 72; height: 36
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                color: Theme.settingsText; font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSize + 3; font.weight: Font.Medium
            }
            FlatButton { objectName: "nextMonth"; label: "›"; width: 36; height: 36; Accessible.name: "Next month"; onActivated: root.shift(1) }
        }
        Row {
            Item { width: SettingsStore.showWeekNumbers ? 28 : 0; height: 24 }
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: root.dayWidth; height: 24
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(index); color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
                }
            }
        }
        Column {
            width: parent.width
            Repeater {
                model: root.monthModel.weeks
                delegate: Row {
                    required property var modelData
                    Text {
                        width: SettingsStore.showWeekNumbers ? 28 : 0; height: 38
                        visible: SettingsStore.showWeekNumbers
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: modelData.weekNumber; color: Theme.settingsMuted
                        font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
                        Accessible.name: "Week " + text
                    }
                    Repeater {
                        model: modelData.days
                        delegate: MouseArea {
                            id: day
                            required property var modelData
                            readonly property bool selected: root.selectedDate.getFullYear() === modelData.year
                                && root.selectedDate.getMonth() === modelData.month && root.selectedDate.getDate() === modelData.day
                            objectName: "calendarDay-" + modelData.year + "-" + modelData.month + "-" + modelData.day
                            width: root.dayWidth; height: 38
                            hoverEnabled: true; activeFocusOnTab: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Qt.formatDate(new Date(modelData.year, modelData.month, modelData.day), "dddd d MMMM yyyy")
                            Accessible.description: selected ? "Selected date" : (modelData.isToday ? "Today" : "")
                            onClicked: root.selectDate(modelData)
                            Keys.onReturnPressed: root.selectDate(modelData)
                            Keys.onSpacePressed: root.selectDate(modelData)
                            Rectangle {
                                anchors.centerIn: parent; width: 34; height: 34; radius: Math.min(Theme.radius, 17)
                                color: day.selected ? Theme.settingsSelected : (day.containsMouse ? Theme.settingsHover : "transparent")
                                border.width: day.activeFocus ? 1 : 0; border.color: Theme.settingsMuted
                            }
                            Text {
                                anchors.centerIn: parent; text: day.modelData.day
                                color: day.modelData.inMonth ? Theme.settingsText : Theme.settingsMuted
                                opacity: day.modelData.inMonth ? 1 : .55
                                font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSize
                                font.weight: day.modelData.isToday ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                visible: day.modelData.isToday
                                width: 3; height: 3; radius: 1.5; color: Theme.settingsText
                                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 7
                            }
                        }
                    }
                }
            }
        }
        Text {
            objectName: "selectedCalendarDate"
            width: parent.width; height: 28
            text: Qt.formatDate(root.selectedDate, "dddd, d MMMM")
            color: Theme.settingsMuted; font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall; verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
        Flow {
            width: parent.width; spacing: 6
            FlatButton { label: "Today"; onActivated: root.showToday() }
            FlatButton { label: SettingsStore.showWeekNumbers ? "Hide weeks" : "Week numbers"; onActivated: SettingsStore.setShowWeekNumbers(!SettingsStore.showWeekNumbers) }
            FlatButton {
                objectName: "openCalendarApplication"
                label: "Open calendar"
                enabled: root.calendarAvailable && !DefaultAppsService.busy
                onActivated: DefaultAppsService.launch("calendar")
            }
        }
        Text {
            width: parent.width
            text: DefaultAppsService.error || (root.calendarAvailable ? "Opens your calendar app." : "Choose a calendar app in Settings → Default apps.")
            wrapMode: Text.WordWrap; color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily; font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
}
