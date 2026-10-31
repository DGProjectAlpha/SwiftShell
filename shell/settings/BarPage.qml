import QtQuick
import "../components"
import "../logic/bar.js" as Bar
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function marked(id) {
        return page.highlightId === id
    }

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    function focusHighlight() {
        var item = itemFor(page.highlightId)
        if (item && item.forceActiveFocus)
            item.forceActiveFocus()
    }

    function itemFor(id) {
        for (var index = 0; index < column.children.length; index++) {
            if (column.children[index].controlId === id)
                return column.children[index]
        }
        return null
    }

    function moduleName(id) {
        if (id === "workspaces")
            return "Workspaces"
        if (id === "title")
            return "Focused title"
        if (id === "search")
            return "Search"
        if (id === "clock")
            return "Clock"
        if (id === "control")
            return "Control center"
        if (id === "media")
            return "Media"
        if (id === "tray")
            return "Tray"
        if (id === "battery")
            return "Battery"
        return id
    }

    function hidden(id) {
        var list = SettingsStore.hiddenModules
        if (!list)
            return false
        for (var index = 0; index < list.length; index++) {
            if (list[index] === id)
                return true
        }
        return false
    }

    onQueryChanged: page.highlightId = Nav.firstControlId(page.query)
    onHighlightIdChanged: {
        var item = itemFor(page.highlightId)
        if (item)
            revealRequested(item.y, item.height)
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Top bar"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Height changes the bar text, icons, hit area, and reserved strip together. The default height is 28."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            visible: page.query.trim() !== "" && !page.shows("barHeight") && !page.shows("reserveSpace") && !page.shows("targetMonitor") && !page.shows("showTitle") && !page.shows("clock24") && !page.shows("moduleOrder")
            text: "No matching settings"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        SettingsRow {
            controlId: "barHeight"
            visible: page.shows("barHeight")
            marked: page.marked("barHeight")
            width: parent.width
            label: "Bar height"

            Row {
                spacing: Theme.panelSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.barHeight + " px"
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                CompactSlider {
                    valueName: "Bar height"
                    value: Bar.unitFromHeight(SettingsStore.barHeight)
                    onMoved: function (next) { SettingsStore.setBarHeight(Bar.heightFromUnit(next)) }
                }
            }
        }

        SettingsToggle {
            controlId: "reserveSpace"
            visible: page.shows("reserveSpace")
            marked: page.marked("reserveSpace")
            label: "Reserve space"
            checked: SettingsStore.reserveSpace
            onToggled: function (next) { SettingsStore.setReserveSpace(next) }
        }

        SettingsRow {
            controlId: "targetMonitor"
            visible: page.shows("targetMonitor")
            marked: page.marked("targetMonitor")
            width: parent.width
            label: "Monitor"

            TextInput {
                id: monitorField
                width: 160
                height: Theme.controlHeight
                text: SettingsStore.targetMonitor
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectByMouse: true
                activeFocusOnTab: true
                clip: true
                Accessible.name: "Bar monitor"
                onEditingFinished: SettingsStore.setTargetMonitor(text)
            }
        }

        SettingsToggle {
            controlId: "showTitle"
            visible: page.shows("showTitle")
            marked: page.marked("showTitle")
            label: "Focused title"
            checked: SettingsStore.showFocusedTitle
            onToggled: function (next) { SettingsStore.setShowFocusedTitle(next) }
        }

        SettingsToggle {
            controlId: "clock24"
            visible: page.shows("clock24")
            marked: page.marked("clock24")
            label: "24-hour clock"
            checked: SettingsStore.use24Hour
            onToggled: function (next) { SettingsStore.setUse24Hour(next) }
        }

        Column {
            id: modules
            property string controlId: "moduleOrder"
            visible: page.shows("moduleOrder")
            width: parent.width
            spacing: Theme.panelSpacing

            Text {
                width: parent.width
                text: page.marked("moduleOrder") ? "Module order" : "Module order"
                color: Theme.panelText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: page.marked("moduleOrder") ? Font.Medium : Font.Normal
            }

            Repeater {
                model: SettingsStore.moduleOrder

                delegate: Row {
                    required property int index
                    required property string modelData
                    width: modules.width
                    spacing: Theme.panelSpacing

                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.moduleName(modelData)
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    FlatButton {
                        label: page.hidden(modelData) ? "Show" : "Hide"
                        onActivated: SettingsStore.setHiddenModules(Bar.toggleHidden(SettingsStore.hiddenModules, modelData))
                    }

                    FlatButton {
                        label: "Earlier"
                        enabled: index > 0
                        onActivated: SettingsStore.setModuleOrder(Bar.moveModule(SettingsStore.moduleOrder, modelData, -1))
                    }

                    FlatButton {
                        label: "Later"
                        enabled: index < SettingsStore.moduleOrder.length - 1
                        onActivated: SettingsStore.setModuleOrder(Bar.moveModule(SettingsStore.moduleOrder, modelData, 1))
                    }
                }
            }
        }
    }
}
