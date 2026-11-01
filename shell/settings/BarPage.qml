import QtQuick
import "../components"
import "../logic/bar.js" as Bar
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string surfaceOutput: ""
    readonly property var surfaceOverrides: JSON.parse(SettingsStore.barSurfaceOutputsJson)
    readonly property bool hasSurfaceOverride: Object.prototype.hasOwnProperty.call(surfaceOverrides,surfaceOutput)
    readonly property var selectedSurface: hasSurfaceOverride ? surfaceOverrides[surfaceOutput] : ({mode:SettingsStore.barSurfaceMode,color:SettingsStore.barSurfaceColor,opacity:SettingsStore.barSurfaceOpacity})
    function editSurface(mode,color,opacity) { SettingsStore.setBarSurface(surfaceOutput,mode,color,opacity) }
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

    Loader {
        id: colorPicker
        source: "ColorPicker.qml"
        Connections {
            target: colorPicker.item
            function onColorChosen(field,value) { page.editSurface(page.selectedSurface.mode,value,page.selectedSurface.opacity) }
        }
    }
    Column {
        id: column
        width: page.width
        spacing: Theme.settingsSpacing

        Text {
            width: parent.width
            text: "Top bar"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Choose the screens, size and content of your top bar."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            visible: page.query.trim() !== "" && !page.shows("barSurface") && !page.shows("barHeight") && !page.shows("reserveSpace") && !page.shows("targetMonitor") && !page.shows("showTitle") && !page.shows("clock24") && !page.shows("moduleOrder")
            text: "No matching settings"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize
        }

        Column {
            property string controlId: "barSurface"
            visible: page.shows("barSurface")
            width: parent.width
            spacing: Theme.settingsSpacing
            SectionHeader { text: "Background" }
            SettingsRow {
                width:parent.width
                label:"Apply to"
                ChoiceBox {
                    choices:[{label:"All screens",value:""}].concat(HyprlandModel.monitorChoices.map(function(m){return {label:m.label,value:m.name}}))
                    selectedValue:page.surfaceOutput
                    onChosen:function(value){page.surfaceOutput=value}
                }
            }
            SettingsToggle {
                visible:page.surfaceOutput !== ""
                label:"Use all-screen background"
                checked:!page.hasSurfaceOverride
                onToggled:function(next) {
                    if(next) SettingsStore.clearBarSurface(page.surfaceOutput)
                    else page.editSurface(SettingsStore.barSurfaceMode,SettingsStore.barSurfaceColor,SettingsStore.barSurfaceOpacity)
                }
            }
            SettingsRow {
                width:parent.width
                label:"Style"
                ChoiceBox {
                    enabled:page.surfaceOutput === "" || page.hasSurfaceOverride
                    choices:[{label:"Transparent",value:"transparent"},{label:"Solid",value:"solid"},{label:"Frosted",value:"frosted"}]
                    selectedValue:page.selectedSurface.mode
                    onChosen:function(value){page.editSurface(value,page.selectedSurface.color,page.selectedSurface.opacity)}
                }
            }
            SettingsRow {
                width:parent.width
                label:"Surface color"
                Row {
                    spacing:Theme.settingsSpacing
                    Rectangle { width:24;height:24;radius:4;color:page.selectedSurface.color;anchors.verticalCenter:parent.verticalCenter }
                    FlatButton {
                        enabled:(page.surfaceOutput === "" || page.hasSurfaceOverride) && page.selectedSurface.mode !== "transparent" && colorPicker.status === Loader.Ready
                        label:"Choose color…"
                        onActivated:{colorPicker.item.selectedColor=page.selectedSurface.color;colorPicker.item.open()}
                    }
                }
            }
            SettingsRow {
                width:parent.width
                label:"Surface opacity"
                Row {
                    spacing:Theme.settingsSpacing
                    Text { anchors.verticalCenter:parent.verticalCenter;text:Math.round(page.selectedSurface.opacity*100)+"%";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall }
                    CompactSlider {
                        enabled:(page.surfaceOutput === "" || page.hasSurfaceOverride) && page.selectedSurface.mode !== "transparent"
                        valueName:"Bar surface opacity"
                        value:page.selectedSurface.opacity
                        onMoved:function(value){page.editSurface(page.selectedSurface.mode,page.selectedSurface.color,value)}
                    }
                }
            }
            Text {
                width:parent.width
                wrapMode:Text.WordWrap
                text:page.selectedSurface.mode === "frosted" ? (SurfaceService.blurAvailable ? "Frosted uses your desktop’s backdrop blur. Opacity changes the surface tint." : SurfaceService.reason+" A solid, readable background is used instead.") : "Transparent keeps the bar clear. The optional readability gradient is set in Appearance."
                color:Theme.settingsMuted
                font.pixelSize:Theme.settingsFontSizeSmall
            }
            Text {
                visible:colorPicker.status === Loader.Error
                width:parent.width
                wrapMode:Text.WordWrap
                text:"Color selection is unavailable on this system."
                color:Theme.settingsMuted
                font.pixelSize:Theme.settingsFontSizeSmall
            }
            FlatButton {
                visible:page.surfaceOutput === ""
                label:"Reset background"
                onActivated:page.editSurface("transparent","#161616",.75)
            }
        }

        SettingsRow {
            controlId: "barHeight"
            visible: page.shows("barHeight")
            marked: page.marked("barHeight")
            width: parent.width
            label: "Bar height"

            Row {
                spacing: Theme.settingsSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.barHeight + " px"
                    color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
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
            controlId: "barPlacement"
            visible: page.shows("barPlacement")
            marked: page.marked("barPlacement")
            width: parent.width
            label: "Screens"

            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "Focused"
                    emphasized: SettingsStore.barPlacement === "focused"
                    onActivated: SettingsStore.setBarPlacement("focused")
                }

                FlatButton {
                    label: "Primary"
                    emphasized: SettingsStore.barPlacement === "primary"
                    onActivated: SettingsStore.setBarPlacement("primary")
                }

                FlatButton {
                    label: "All"
                    emphasized: SettingsStore.barPlacement === "all"
                    onActivated: SettingsStore.setBarPlacement("all")
                }
            }
        }

        Column {
            property string controlId: "targetMonitor"
            visible: page.shows("targetMonitor")
            width: parent.width
            spacing: Theme.settingsSpacing
            Text {
                text: "Use one monitor"
                color: Theme.settingsMuted
                font.pixelSize: Theme.settingsFontSizeSmall
            }
            Repeater {
                model: HyprlandModel.monitorChoices
                delegate: FlatButton {
                    required property var modelData
                    width: Math.min(implicitWidth, page.width)
                    label: modelData.label
                    emphasized: SettingsStore.targetMonitor === modelData.name
                    onActivated: SettingsStore.setTargetMonitor(modelData.name)
                }
            }
            Text {
                visible: SettingsStore.targetMonitor !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Selected: " + SettingsStore.targetMonitor + ". Disconnected outputs fall back to the focused screen. Focused, Primary, or All clears this selection."
                color: Theme.settingsMuted
                font.pixelSize: Theme.settingsFontSizeSmall
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
            spacing: Theme.settingsSpacing

            Text {
                width: parent.width
                text: page.marked("moduleOrder") ? "Module order" : "Module order"
                color: Theme.settingsText
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSize
                font.weight: page.marked("moduleOrder") ? Font.Medium : Font.Normal
            }

            Repeater {
                model: SettingsStore.moduleOrder

                delegate: Row {
                    required property int index
                    required property string modelData
                    width: modules.width
                    spacing: Theme.settingsSpacing

                    Text {
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.moduleName(modelData)
                        color: Theme.settingsText
                        font.family: Theme.settingsFontFamily
                        font.pixelSize: Theme.settingsFontSize
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
