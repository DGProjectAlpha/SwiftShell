import QtQuick
import "../logic/settingsFocus.js" as Focus
import "../components"
import "../logic/settings.js" as Settings
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    signal edited(var patch)
    signal editStarted()
    signal editFinished()
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
        const item=itemFor(page.highlightId);Focus.revealAncestors(item);Qt.callLater(function(){Focus.focusFirst(item)})
    }

    function itemFor(id) {return Focus.findControl(column,id)}

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

    function pickColor(field,current) {
        colorPicker.field=field
        colorPicker.selectedColor=current || (field === "manualPanel" ? Theme.settingsSurface : Theme.settingsText)
        colorPicker.open()
    }
    ColorPicker {
        id:colorPicker
        onColorChosen:function(field,value){const patch={};patch[field]=value;page.edited(patch)}
    }

    onQueryChanged: page.highlightId = Nav.firstControlId(page.query)
    onHighlightIdChanged: {
        var item = itemFor(page.highlightId)
        if (item) {Focus.revealAncestors(item);Qt.callLater(function(){const point=item.mapToItem(page,0,0);page.revealRequested(point.y,item.height)})}
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

        SettingsPreview {
            property string controlId:"preview"
            visible:page.query.trim()==="" || page.shows("preview")
            width:parent.width
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.interface"
            title:"Interface"
            description:""
            searchQuery:page.query
            controlIds:["mode", "fontSize", "fontWeight", "density"]
            width:parent.width
            SettingsRow {
                controlId: "mode"
                visible: page.shows("mode")
                marked: page.marked("mode")
                width:parent.cellWidth
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
                width:parent.cellWidth
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

                        onInteractionStarted:page.editStarted()

                        onInteractionFinished:page.editFinished()
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
                width:parent.cellWidth
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
                width:parent.cellWidth
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

                        onInteractionStarted:page.editStarted()

                        onInteractionFinished:page.editFinished()
                        valueName: "Density"
                        value: Nav.unitFromDensity(SettingsStore.panelPadding)
                        onMoved: function (next) {
                            var density = Nav.densityFromUnit(next)
                            page.edited(density)
                        }
                    }
                }
            }
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.surfaces"
            title:"Surfaces"
            description:""
            searchQuery:page.query
            controlIds:["panelOpacity", "radius", "shadowOpacity", "shadowSoftness"]
            width:parent.width
            SettingsRow {
                controlId: "panelOpacity"
                visible: page.shows("panelOpacity")
                marked: page.marked("panelOpacity")
                width:parent.cellWidth
                label: "Surface opacity"

                CompactSlider {

                    onInteractionStarted:page.editStarted()

                    onInteractionFinished:page.editFinished()
                    valueName: "Panel opacity"
                    value: Settings.unitFromOpacity(SettingsStore.panelOpacity)
                    onMoved: function (next) { page.edited({ panelOpacity: Settings.opacityFromUnit(next) }) }
                }
            }
            SettingsRow {
                controlId: "radius"
                visible: page.shows("radius")
                marked: page.marked("radius")
                width:parent.cellWidth
                label: "Corner radius"

                CompactSlider {

                    onInteractionStarted:page.editStarted()

                    onInteractionFinished:page.editFinished()
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
                width:parent.cellWidth
                label: "Shadow opacity"

                CompactSlider {

                    onInteractionStarted:page.editStarted()

                    onInteractionFinished:page.editFinished()
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
                width:parent.cellWidth
                label: "Shadow softness"

                CompactSlider {

                    onInteractionStarted:page.editStarted()

                    onInteractionFinished:page.editFinished()
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
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.motion"
            title:"Motion & accessibility"
            description:""
            searchQuery:page.query
            controlIds:["iconScale", "motionScale", "textContrast", "reducedMotion"]
            width:parent.width
            SettingsRow {
                controlId: "iconScale"
                visible: page.shows("iconScale")
                marked: page.marked("iconScale")
                width:parent.cellWidth
                label: "Icon scale"

                CompactSlider {

                    onInteractionStarted:page.editStarted()

                    onInteractionFinished:page.editFinished()
                    valueName: "Icon scale"
                    value: Nav.unitFromIconScale(SettingsStore.iconScale)
                    onMoved: function (next) { page.edited({ iconScale: Nav.iconScaleFromUnit(next) }) }
                }
            }
            SettingsRow {
                controlId: "motionScale"
                visible: page.shows("motionScale")
                marked: page.marked("motionScale")
                width:parent.cellWidth
                label: "Animation speed"

                Column {
                    spacing: 2

                    CompactSlider {

                        onInteractionStarted:page.editStarted()

                        onInteractionFinished:page.editFinished()
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
                width:parent.cellWidth
                controlId: "textContrast"
                visible: page.shows("textContrast")
                marked: page.marked("textContrast")
                label: "High contrast"
                checked: SettingsStore.textContrast === "high"
                onToggled: function (next) { page.edited({ contrast: next ? "high" : "standard" }) }
            }
            SettingsToggle {
                width:parent.cellWidth
                controlId: "reducedMotion"
                visible: page.shows("reducedMotion")
                marked: page.marked("reducedMotion")
                label: "Reduced motion"
                checked: SettingsStore.reducedMotion
                onToggled: function (next) { page.edited({ reducedMotion: next }) }
            }
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.desktop"
            title:"Application windows"
            description:""
            searchQuery:page.query
            controlIds:["windowBorders", "opaqueWindows"]
            width:parent.width
            SettingsToggle {
                width:parent.cellWidth
                controlId:"windowBorders"
                visible:page.shows("windowBorders")
                label:"Window borders"
                enabled:DesktopAppearance.available
                checked:DesktopAppearance.observed.border>0
                onToggled:function(next){DesktopAppearance.request("apply",{border:next ? DesktopAppearance.lastBorderWidth : 0})}
            }
            SettingsRow {
                width:parent.cellWidth
                visible:page.shows("windowBorders")
                label:"Border width"
                ChoiceBox {
                    width:160
                    enabled:DesktopAppearance.available
                    choices:[{label:"None",value:0},{label:"1 pixel",value:1},{label:"2 pixels",value:2},{label:"3 pixels",value:3},{label:"4 pixels",value:4},{label:"6 pixels",value:6},{label:"8 pixels",value:8}]
                    selectedValue:DesktopAppearance.observed.border
                    onChosen:function(value){DesktopAppearance.request("apply",{border:value})}
                }
            }
            SettingsToggle {
                width:parent.cellWidth
                controlId:"opaqueWindows"
                label:"Keep application windows opaque"
                checked:SettingsStore.opaqueWindows
                onToggled:function(next){page.edited({opaqueWindows:next})}
            }
            FlatButton {
                visible:SettingsStore.opaqueWindows && DesktopAppearance.available && (DesktopAppearance.observed.activeOpacity<1 || DesktopAppearance.observed.inactiveOpacity<1)
                label:"Make application windows opaque"
                onActivated:DesktopAppearance.request("apply",{opaqueWindows:true})
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:"Keeps games, videos and other application windows opaque, including inactive windows. SwiftShell’s frosted panels stay translucent."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
            Text {
                width:column.width;wrapMode:Text.WordWrap
                visible:page.shows("windowBorders")
                text:"Applies to active and inactive application windows. Individual window rules may override these defaults."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.readability"
            title:"Bar readability"
            description:""
            searchQuery:page.query
            controlIds:["topGradient", "automaticText"]
            width:parent.width
            SettingsToggle {
                width:parent.cellWidth
                controlId: "topGradient"
                visible: page.shows("topGradient")
                marked: page.marked("topGradient")
                label: "Top edge gradient"
                checked: SettingsStore.topGradient
                onToggled: function (next) { page.edited({ topGradient: next }) }
            }
            SettingsToggle {
                width:parent.cellWidth
                controlId:"automaticText"
                visible:page.shows("automaticText")
                label:"Adaptive bar contrast"
                checked:SettingsStore.automaticText
                onToggled:function(next){page.edited({automaticText:next})}
            }
        }

        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.blur"
            title:"Backdrop blur"
            description:""
            searchQuery:page.query
            controlIds:["backdropBlur"]
            width:parent.width
            SettingsToggle {
                width:parent.cellWidth
                controlId: "backdropBlur"
                visible: page.shows("backdropBlur")
                label: "Backdrop blur"
                enabled: SurfaceService.blurAvailable
                checked: SurfaceService.blurAvailable && SettingsStore.panelBlur > 0
                onToggled: function(next) { page.edited({panelBlur:next ? DesktopAppearance.preferredBlur() : 0}) }
            }
            SettingsRow {
                controlId:"blurStrength"
                width:parent.cellWidth
                label:"Blur strength"
                visible:page.shows("backdropBlur")
                enabled:DesktopAppearance.available && SettingsStore.panelBlur>0
                CompactSlider {
                    onInteractionStarted:page.editStarted()
                    onInteractionFinished:page.editFinished()
                    valueName:"Desktop blur strength"
                    value:DesktopAppearance.managed.size !== undefined ? SettingsStore.panelBlur : Math.max(0,Math.min(1,((DesktopAppearance.observed.size || 1)-1)/11))
                    onMoved:function(next){page.edited({panelBlur:Math.max(.01,next)})}
                }
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                visible:page.shows("backdropBlur")
                text:DesktopAppearance.error || "Blur strength affects all compositor-blurred surfaces. Your configuration files stay unchanged."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
            FlatButton {
                visible:page.shows("backdropBlur") && Object.keys(DesktopAppearance.managed).length>0
                label:"Restore desktop appearance"
                onActivated:DesktopAppearance.restore()
            }
            Text {
                width: parent.width
                visible: page.shows("backdropBlur")
                text: SurfaceService.blurAvailable ? "Shared by Settings, Spotlight and bar panels. Desktop corners also follow your radius." : SurfaceService.reason
                color: Theme.settingsMuted
                wrapMode: Text.WordWrap
                font.family: Theme.settingsFontFamily
                font.pixelSize: Theme.settingsFontSizeSmall
            }
        }
        SettingsSection {
            adaptiveColumns:true
            sectionId:"appearance.colors"
            title:"Colors"
            description:"A neutral interface by default, with an optional accent for selected controls."
            searchQuery:page.query
            controlIds:["accentColor","manualText"]
            width:parent.width
            SettingsRow {
                controlId:"accentColor"
                width:parent.cellWidth
                label:"Accent color"
                Row {
                    spacing:6
                    FlatButton {label:SettingsStore.accentColor || "Neutral";onActivated:page.pickColor("accentColor",SettingsStore.accentColor);Accessible.name:"Choose accent color"}
                    FlatButton {label:"Use neutral";enabled:SettingsStore.accentColor!=="";onActivated:page.edited({accentColor:""})}
                }
            }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.shows("manualText") && Theme.contrastWarning !== ""
            text: Theme.contrastWarning
            color: Theme.settingsText
            font.family: Theme.settingsFontFamily
            font.pixelSize: Theme.settingsFontSizeSmall
        }
        SettingsRow {
            controlId: "manualText"
            visible: page.shows("manualText")
            marked: page.marked("manualText")
            width:parent.cellWidth
            label: "Text"

            Row {
                spacing:8
                FlatButton {
                    label:SettingsStore.manualText || "Choose color"
                    onActivated:page.pickColor("manualText",SettingsStore.manualText)
                    Accessible.name:"Choose text color"
                }
                FlatButton { label:"Reset";enabled:SettingsStore.manualText !== "";onActivated:page.edited({manualText:""}) }
            }
        }
        SettingsRow {
            visible: page.shows("manualText")
            width:parent.cellWidth
            label: "Panel"

            Row {
                spacing:8
                FlatButton {
                    label:SettingsStore.manualPanel || "Choose color"
                    onActivated:page.pickColor("manualPanel",SettingsStore.manualPanel)
                    Accessible.name:"Choose panel color"
                }
                FlatButton { label:"Reset";enabled:SettingsStore.manualPanel !== "";onActivated:page.edited({manualPanel:""}) }
            }
        }
        }
    }
}
