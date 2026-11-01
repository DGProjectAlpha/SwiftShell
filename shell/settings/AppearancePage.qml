import QtQuick
import "../components"
import "../logic/material.js" as Material
import "../logic/settings.js" as Settings
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    signal edited(var patch)
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
        focusItem(itemFor(page.highlightId))
    }

    function itemFor(id) {
        for (var index = 0; index < column.children.length; index++) {
            var child = column.children[index]
            if (child.controlId === id)
                return child
        }
        return null
    }

    function focusItem(node) {
        if (!node)
            return false
        if (node.activeFocusOnTab) {
            node.forceActiveFocus()
            return true
        }
        var kids = node.children
        if (!kids)
            return false
        for (var index = 0; index < kids.length; index++) {
            if (focusItem(kids[index]))
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
        spacing: Theme.settingsSpacing

        Text {
            width: parent.width
            text: "Appearance"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Make SwiftShell feel at home. Changes are saved automatically."
            color: Theme.settingsMuted
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            width: parent.width
            visible: page.query.trim() !== "" && Nav.filterControls(page.query).length === 0
            wrapMode: Text.WordWrap
            text: "No matching settings"
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSize
        }

        Item {
            property string controlId: "preview"
            visible: page.shows("preview")
            width: parent.width
            height: 44

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.panelColor

                Text {
                    anchors.centerIn: parent
                    text: "Preview"
                    color: Theme.settingsText
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSize
                    font.weight: page.marked("preview") ? Font.Medium : Font.Normal
                }
            }
        }

        SectionHeader { text:"Interface"; visible:page.query === "" }

        SettingsRow {
            controlId: "mode"
            visible: page.shows("mode")
            marked: page.marked("mode")
            width: parent.width
            label: "Theme"

            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "Dark"
                    emphasized: SettingsStore.appearanceMode !== "light"
                    onActivated: page.edited({ mode: "dark" })
                }

                FlatButton {
                    label: "Light"
                    emphasized: SettingsStore.appearanceMode === "light"
                    onActivated: page.edited({ mode: "light" })
                }
            }
        }

        SettingsRow {
            controlId: "fontSize"
            visible: page.shows("fontSize")
            marked: page.marked("fontSize")
            width: parent.width
            label: "Text size"

            Row {
                spacing: Theme.settingsSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.fontSize + " px"
                    color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                }

                CompactSlider {
                    valueName: "Text size"
                    value: Nav.unitFromFontSize(SettingsStore.fontSize)
                    onMoved: function (next) { page.edited({ fontSize: Nav.fontSizeFromUnit(next) }) }
                }
            }
        }

        SettingsRow {
            controlId: "fontWeight"
            visible: page.shows("fontWeight")
            marked: page.marked("fontWeight")
            width: parent.width
            label: "Text weight"

            Row {
                spacing: Theme.settingsSpacing

                FlatButton {
                    label: "Regular"
                    emphasized: SettingsStore.fontWeight !== "medium"
                    onActivated: page.edited({ fontWeight: "regular" })
                }

                FlatButton {
                    label: "Medium"
                    emphasized: SettingsStore.fontWeight === "medium"
                    onActivated: page.edited({ fontWeight: "medium" })
                }
            }
        }

        SettingsRow {
            controlId: "density"
            visible: page.shows("density")
            marked: page.marked("density")
            width: parent.width
            label: "Density"

            Row {
                spacing: Theme.settingsSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.panelPadding < 11 ? "Compact" : (SettingsStore.panelPadding < 17 ? "Comfortable" : "Spacious")
                    color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                }

                CompactSlider {
                    valueName: "Density"
                    value: Nav.unitFromDensity(SettingsStore.panelPadding)
                    onMoved: function (next) {
                        var density = Nav.densityFromUnit(next)
                        page.edited(density)
                    }
                }
            }
        }

        SectionHeader { text:"Surfaces"; visible:page.query === "" }

        SettingsRow {
            controlId: "panelOpacity"
            visible: page.shows("panelOpacity")
            marked: page.marked("panelOpacity")
            width: parent.width
            label: "Surface opacity"

            CompactSlider {
                valueName: "Panel opacity"
                value: Settings.unitFromOpacity(SettingsStore.panelOpacity)
                onMoved: function (next) { page.edited({ panelOpacity: Settings.opacityFromUnit(next) }) }
            }
        }

        SettingsRow {
            controlId: "radius"
            visible: page.shows("radius")
            marked: page.marked("radius")
            width: parent.width
            label: "Corner radius"

            CompactSlider {
                valueName: "Corner radius"
                value: Settings.unitFromRadius(SettingsStore.radius)
                onMoved: function (next) { page.edited({ radius: Settings.radiusFromUnit(next) }) }
            }
        }

        SettingsRow {
            controlId: "shadowOpacity"
            enabled: SettingsModel.shadowAvailable
            visible: page.shows("shadowOpacity")
            marked: page.marked("shadowOpacity")
            width: parent.width
            label: "Shadow opacity"

            CompactSlider {
                valueName: "Shadow opacity"
                value: Nav.unitFromShadowOpacity(SettingsStore.shadowOpacity)
                onMoved: function (next) { page.edited({ shadowOpacity: Nav.shadowOpacityFromUnit(next) }) }
            }
        }

        SettingsRow {
            controlId: "shadowSoftness"
            enabled: SettingsModel.shadowAvailable
            visible: page.shows("shadowSoftness")
            marked: page.marked("shadowSoftness")
            width: parent.width
            label: "Shadow softness"

            CompactSlider {
                valueName: "Shadow softness"
                value: Nav.unitFromShadowSoftness(SettingsStore.shadowSoftness)
                onMoved: function (next) { page.edited({ shadowSoftness: Nav.shadowSoftnessFromUnit(next) }) }
            }
        }

        Text {
            width:parent.width;wrapMode:Text.WordWrap
            visible:page.query === ""
            text:SettingsModel.shadowAvailable ? "Radius and shadows apply to Settings and popovers. Bar backgrounds are set in Top bar." : "Window shadows are unavailable on this system."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }

        SectionHeader { text:"Motion & readability"; visible:page.query === "" }

        SettingsRow {
            controlId: "iconScale"
            visible: page.shows("iconScale")
            marked: page.marked("iconScale")
            width: parent.width
            label: "Icon scale"

            CompactSlider {
                valueName: "Icon scale"
                value: Nav.unitFromIconScale(SettingsStore.iconScale)
                onMoved: function (next) { page.edited({ iconScale: Nav.iconScaleFromUnit(next) }) }
            }
        }

        SettingsRow {
            controlId: "motionScale"
            visible: page.shows("motionScale")
            marked: page.marked("motionScale")
            width: parent.width
            label: "Animation speed"

            Column {
                spacing: 2

                CompactSlider {
                    valueName: "Motion scale"
                    value: SettingsStore.motionScale
                    onMoved: function (next) { page.edited({ motionScale: next }) }
                }

                Text {
                    width: 160
                    wrapMode: Text.WordWrap
                    visible: SettingsStore.reducedMotion
                    text: "Paused while reduced motion is on."
                    color: Theme.settingsMuted
                    font.family: Theme.settingsFontFamily
                    font.pixelSize: Theme.settingsFontSizeSmall
                }
            }
        }

        SettingsToggle {
            controlId: "textContrast"
            visible: page.shows("textContrast")
            marked: page.marked("textContrast")
            label: "High contrast"
            checked: SettingsStore.textContrast === "high"
            onToggled: function (next) { page.edited({ contrast: next ? "high" : "standard" }) }
        }

        SettingsToggle {
            controlId: "reducedMotion"
            visible: page.shows("reducedMotion")
            marked: page.marked("reducedMotion")
            label: "Reduced motion"
            checked: SettingsStore.reducedMotion
            onToggled: function (next) { page.edited({ reducedMotion: next }) }
        }

        SettingsToggle {
            controlId: "topGradient"
            visible: page.shows("topGradient")
            marked: page.marked("topGradient")
            label: "Top edge gradient"
            checked: SettingsStore.topGradient
            onToggled: function (next) { page.edited({ topGradient: next }) }
        }

        SettingsToggle {
            controlId: "backdropBlur"
            visible: page.shows("backdropBlur")
            label: "Backdrop blur"
            enabled: WindowService.blurAvailable
            checked: WindowService.blurAvailable && SettingsStore.panelBlur > 0
            onToggled: function(next) { page.edited({panelBlur:next ? 1 : 0}) }
        }
        Text {
            width: parent.width
            visible: page.shows("backdropBlur")
            text: WindowService.blurAvailable ? "Blurs the desktop behind this window." : WindowService.blurReason
            color: Theme.settingsMuted
            wrapMode: Text.WordWrap
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }
    }
}
