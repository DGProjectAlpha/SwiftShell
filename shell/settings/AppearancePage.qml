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
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Appearance"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Changes apply immediately and are saved. Search finds these controls only."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            visible: page.query.trim() !== "" && Nav.filterControls(page.query).length === 0
            wrapMode: Text.WordWrap
            text: "No matching settings"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
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
                    color: Theme.panelText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: page.marked("preview") ? Font.Medium : Font.Normal
                }
            }
        }

        SettingsRow {
            controlId: "mode"
            visible: page.shows("mode")
            marked: page.marked("mode")
            width: parent.width
            label: "Theme"

            Row {
                spacing: Theme.panelSpacing

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
                spacing: Theme.panelSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.fontSize + " px"
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
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
                spacing: Theme.panelSpacing

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
                spacing: Theme.panelSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsStore.panelPadding + " / " + SettingsStore.panelSpacing
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
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

        SettingsRow {
            controlId: "panelOpacity"
            visible: page.shows("panelOpacity")
            marked: page.marked("panelOpacity")
            width: parent.width
            label: "Panel opacity"

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
            label: "Motion scale"

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
                    color: Theme.panelMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
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

        SettingsRow {
            controlId: "wallpaperTint"
            visible: page.shows("wallpaperTint")
            marked: page.marked("wallpaperTint")
            width: parent.width
            label: "Wallpaper tint"

            Text {
                text: "Not sampled yet"
                color: Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Item {
            property string controlId: "backdropBlur"
            visible: page.shows("backdropBlur")
            width: parent.width
            implicitHeight: blurText.implicitHeight
            height: implicitHeight

            Text {
                id: blurText
                width: parent.width
                wrapMode: Text.WordWrap
                text: Material.materialReport().backdropBlur.reason + " " + Material.CLIP_REASON
                color: page.marked("backdropBlur") ? Theme.panelText : Theme.panelMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: page.marked("backdropBlur") ? Font.Medium : Font.Normal
            }
        }
    }
}
