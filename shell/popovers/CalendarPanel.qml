import QtQuick
import Quickshell
import "../components"
import "../logic/calendar.js" as Calendar
import "../logic/clock.js" as Clock
import "../services"
import "../themes"

Column {
    id: root

    spacing: Theme.panelSpacing
    implicitWidth: Math.max(Theme.calendarWidth, headerRow.implicitWidth)
    width: implicitWidth

    property int year: clock.date ? clock.date.getFullYear() : 1970
    property int month: clock.date ? clock.date.getMonth() : 0

    function resolvedWeekStart() {
        return Calendar.weekStartIndex(SettingsStore.weekStart, Qt.locale().firstDayOfWeek, Qt.Sunday)
    }

    readonly property var monthModel: Calendar.buildMonth(
        year,
        month,
        resolvedWeekStart(),
        clock.date ? clock.date.getFullYear() : year,
        clock.date ? clock.date.getMonth() : month,
        clock.date ? clock.date.getDate() : 1
    )

    function weekdayLabel(index) {
        const start = resolvedWeekStart()
        const jsDay = (start + index) % 7
        const qtDay = jsDay === 0 ? Qt.Sunday : jsDay
        const name = Qt.locale().dayName(qtDay, Locale.NarrowFormat)
        if (typeof name === "string" && name !== "")
            return name
        return ["S", "M", "T", "W", "T", "F", "S"][jsDay]
    }

    function shift(delta) {
        const next = Calendar.shiftMonth(year, month, delta)
        year = next.year
        month = next.month
    }

    function showToday() {
        if (!clock.date)
            return
        year = clock.date.getFullYear()
        month = clock.date.getMonth()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: headerRow
        spacing: Theme.panelSpacing

        FlatButton {
            label: "Previous"
            Accessible.name: "Previous month"
            onActivated: root.shift(-1)
        }

        Text {
            id: title
            width: Theme.calendarWidth * 0.46
            height: Theme.controlHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            elide: Text.ElideRight
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        FlatButton {
            label: "Next"
            Accessible.name: "Next month"
            onActivated: root.shift(1)
        }
    }

    Row {
        spacing: 0

        Item {
            visible: SettingsStore.showWeekNumbers
            width: visible ? Theme.weekNumberWidth : 0
            height: Theme.calendarCell
        }

        Repeater {
            model: 7

            delegate: Text {
                required property int index
                width: Theme.calendarCell
                height: Theme.calendarCell
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.weekdayLabel(index)
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Repeater {
        model: root.monthModel.weeks

        delegate: Row {
            required property var modelData
            spacing: 0

            Text {
                visible: SettingsStore.showWeekNumbers
                width: visible ? Theme.weekNumberWidth : 0
                height: Theme.calendarCell
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.weekNumber
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                Accessible.name: "Week " + text
            }

            Repeater {
                model: modelData.days

                delegate: Item {
                    required property var modelData
                    width: Theme.calendarCell
                    height: Theme.calendarCell

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.inMonth ? Theme.panelText : Theme.panelMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: modelData.isToday ? Font.Medium : Font.Normal
                    }

                    Rectangle {
                        visible: modelData.isToday && modelData.inMonth
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 10
                        height: 1
                        color: Theme.panelText
                    }
                }
            }
        }
    }

    Row {
        spacing: Theme.panelSpacing

        FlatButton {
            label: "Today"
            Accessible.name: "Show today"
            onActivated: root.showToday()
        }

        FlatButton {
            label: SettingsStore.showWeekNumbers ? "Hide weeks" : "Week numbers"
            onActivated: SettingsStore.setShowWeekNumbers(!SettingsStore.showWeekNumbers)
        }
    }

    Text {
        width: parent.width
        text: Qt.formatDate(clock.date, "dddd d MMMM") + "  " + Clock.formatTime(clock.date, SettingsStore.use24Hour)
        color: Theme.panelMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
