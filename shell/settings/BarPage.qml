import QtQuick
import "../logic/settingsFocus.js" as Focus
import "../components"
import "../logic/bar.js" as Bar
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    readonly property bool colorPickerOpen: colorPicker.item ? colorPicker.item.opened : false
    function geometry() {
        const position=modulesOutputChoice.mapToItem(null,0,0)
        const items=[],popup=modulesOutputChoice.popup.contentItem
        if(modulesOutputChoice.popup.visible)for(let i=0;i<modulesOutputChoice.resolvedChoices.length;i++) {
            const item=popup.itemAtIndex(i)
            if(item){const point=item.mapToItem(null,0,0);items.push({value:modulesOutputChoice.resolvedChoices[i].value,x:point.x,y:point.y,width:item.width,height:item.height})}
        }
        return {output:page.modulesOutput,rows:moduleOrder.geometry(),selector:{x:position.x,y:position.y,width:modulesOutputChoice.width,height:modulesOutputChoice.height,items:items}}
    }
    function colorPickerGeometry() { return colorPickerOpen ? colorPicker.item.geometry() : null }
    property string pickingOutput: ""
    function openSurfaceColorPicker() {
        if(colorPicker.status !== Loader.Ready) return
        pickingOutput=surfaceOutput
        colorPicker.item.selectedColor=selectedSurface.color
        colorPicker.item.open()
    }
    property alias modulesOutput:page.layoutOutput
    property string layoutOutput:""
    property bool outputInitialized:false
    readonly property var outputChoices:HyprlandModel.monitorChoices.map(function(m){return {label:m.label,value:m.name}})
    readonly property string scopeLabel: {
        if(layoutOutput==="")return "All displays"
        const found=HyprlandModel.monitorChoices.find(function(m){return m.name===page.layoutOutput})
        return found ? found.label : layoutOutput+" (disconnected)"
    }
    readonly property real selectedSize:selectedLayout.height*selectedLayout.scale
    function mixed(field) {
        if(layoutOutput!=="")return false
        const values=HyprlandModel.monitorChoices.map(function(m){
            const layout=SettingsStore.layoutForOutput(m.name)
            return field==="size" ? layout.height*layout.scale : layout[field]
        })
        return values.some(function(value){return value!==values[0]})
    }
    function chooseInitialOutput() {
        if(outputInitialized)return
        if(layoutOutput!==""){outputInitialized=true;return}
        const choices=HyprlandModel.monitorChoices
        if(!choices.length)return
        const focused=HyprlandModel.focusedOutput
        layoutOutput=focused && choices.some(function(choice){return choice.name===focused.name}) ? focused.name : choices[0].name
        outputInitialized=true
    }
    function selectOutput(output) {outputInitialized=true;layoutOutput=output}
    Component.onCompleted:chooseInitialOutput()
    Connections {target:HyprlandModel;function onMonitorChoicesChanged(){page.chooseInitialOutput()}}
    readonly property var selectedLayout:SettingsStore.layoutForOutput(layoutOutput)
    function edit(patch) { return SettingsStore.patchBarOutput(layoutOutput,patch) }
    function editModuleSide(id,side) {
        SettingsStore.setBarModuleSideForScope(modulesOutput,id,side)
    }
    function editModuleOrder(order) {
        edit({order:order})
    }
    property alias surfaceOutput:page.layoutOutput
    readonly property var surfaceOverrides: JSON.parse(SettingsStore.barSurfaceOutputsJson)
    readonly property bool hasSurfaceOverride: Object.prototype.hasOwnProperty.call(surfaceOverrides,surfaceOutput)
    readonly property var selectedSurface: hasSurfaceOverride ? surfaceOverrides[surfaceOutput] : ({mode:SettingsStore.barSurfaceMode,color:SettingsStore.barSurfaceColor,opacity:SettingsStore.barSurfaceOpacity})
    function editSurface(patch) { SettingsStore.patchBarSurfaceForScope(surfaceOutput,patch) }
    function useSharedSettings() {
        SettingsStore.inheritOutputLayout(layoutOutput)
        SettingsStore.clearBarSurface(layoutOutput)
        SettingsStore.inheritHidden(layoutOutput)
    }
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
        Focus.revealAncestors(item);Qt.callLater(function(){Focus.focusFirst(item)})
    }

    function itemFor(id) {return Focus.findControl(column,id)}

    function hidden(id) {
        var list = SettingsStore.hiddenForOutput(modulesOutput)
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
        if (item) {Focus.revealAncestors(item);Qt.callLater(function(){const point=item.mapToItem(page,0,0);page.revealRequested(point.y,item.height)})}
    }

    Loader {
        id: colorPicker
        source: "ColorPicker.qml"
        Connections {
            target: colorPicker.item
            function onColorChosen(field,value) {
                SettingsStore.patchBarSurfaceForScope(page.pickingOutput,{color:value})
            }
        }
    }
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing

        Text {
            width:parent.width;text:"Top bar";color:Theme.settingsText
            font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium
        }
        SettingsSection {
            sectionId:"bar.displays";title:"Where bars appear"
            description:"This setting controls all displays."
            searchQuery:page.query;controlIds:["barPlacement","targetMonitor"]
            SettingsRow {
                controlId:"barPlacement";width:parent.width;label:"Show bars on"
                ChoiceBox {
                    objectName:"barPlacementChoice"
                    choices:[{label:"All displays",value:"all"},{label:"Focused display",value:"focused"},{label:"Primary display",value:"primary"}].concat(page.outputChoices.map(function(m){return {label:m.label,value:"output:"+m.value}}))
                    selectedValue:SettingsStore.targetMonitor!=="" ? "output:"+SettingsStore.targetMonitor : SettingsStore.barPlacement
                    onChosen:function(value) {
                        if(value.indexOf("output:")===0)SettingsStore.setTargetMonitor(value.substring(7))
                        else SettingsStore.setBarPlacement(value)
                    }
                }
            }
        }
        SettingsRow {
            width:parent.width;label:"Apply to"
            ChoiceBox {
                id:modulesOutputChoice
                objectName:"barModulesOutput"
                choices:[{label:"All displays",value:""}].concat(page.outputChoices)
                selectedValue:page.layoutOutput
                customLabel:page.scopeLabel
                onChosen:function(value){page.selectOutput(value)}
            }
        }
        Text {
            objectName:"barScopeDescription"
            width:parent.width;wrapMode:Text.WordWrap
            text:page.layoutOutput==="" ? "Controls show shared settings. Each edit updates that setting on every display, including customized bars. Changes save automatically."
                : "Changes below apply only to "+page.scopeLabel+". Other displays keep their settings."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        FlatButton {
            objectName:"barUseSharedSettings"
            visible:page.layoutOutput!==""
            label:"Use shared settings for this display"
            onActivated:page.useSharedSettings()
        }
        Text {
            width:parent.width;visible:page.query.trim()!=="" && !Nav.filterControls(page.query).some(function(c){return c.category==="bar"})
            text:"No matching settings";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSize
        }
        SettingsSection {
            sectionId:"bar.geometry";title:"Size & position"
            searchQuery:page.query;controlIds:["barHeight","barEdgeScale","reserveSpace"]
            SettingsRow {
                controlId:"barHeight";visible:page.shows("barHeight");marked:page.marked("barHeight")
                width:parent.width;label:"Bar size"
                Row {
                    spacing:Theme.settingsSpacing
                    Text {
                        anchors.verticalCenter:parent.verticalCenter
                        text:page.mixed("size") ? "Mixed" : Math.round(page.selectedSize)+" px"
                        color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
                    }
                    CompactSlider {
                        objectName:"barSizeSlider"
                        valueName:"Bar size"
                        value:Bar.unitFromSize(page.selectedSize)
                        onMoved:function(next){SettingsStore.setBarSizeForOutput(page.layoutOutput,Bar.sizeFromUnit(next))}
                    }
                }
            }
            Text {
                visible:page.shows("barHeight")
                width:parent.width;wrapMode:Text.WordWrap
                text:"Resizes the bar, text and icons together. Your desktop’s display scale stays unchanged."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
            SettingsRow {
                controlId:"barEdgeScale";visible:page.shows("barEdgeScale")
                width:parent.width;label:"Screen edge"
                ChoiceBox {
                    id:edgeChoice
                    objectName:"barEdgeChoice"
                    choices:[{label:"Top",value:"top"},{label:"Bottom",value:"bottom"},{label:"Left",value:"left"},{label:"Right",value:"right"}]
                    selectedValue:page.selectedLayout.edge
                    displayText:page.mixed("edge") ? "Mixed" : currentText
                    onChosen:function(value){page.edit({edge:value})}
                }
            }
            SettingsToggle {
                objectName:"barReserveSpace"
                controlId:"reserveSpace";visible:page.shows("reserveSpace")
                label:"Keep windows below the bar"
                checked:page.selectedLayout.reserveSpace
                onToggled:function(next){page.edit({reserveSpace:next})}
            }
        }
        SettingsSection {
            sectionId:"bar.background";title:"Background"
            searchQuery:page.query;controlIds:["barSurface"]
            property string controlId:"barSurface"
            SettingsRow {
                width:parent.width;label:"Style"
                ChoiceBox {
                    objectName:"barSurfaceStyle"
                    choices:[{label:"Transparent",value:"transparent"},{label:"Solid",value:"solid"},{label:"Frosted",value:"frosted"}]
                    selectedValue:page.selectedSurface.mode
                    onChosen:function(value){page.editSurface({mode:value})}
                }
            }
            SettingsRow {
                visible:page.selectedSurface.mode!=="transparent"
                width:parent.width;label:"Color"
                Row {
                    spacing:Theme.settingsSpacing
                    Rectangle {width:24;height:24;radius:4;color:page.selectedSurface.color;anchors.verticalCenter:parent.verticalCenter}
                    FlatButton {label:"Choose color…";enabled:colorPicker.status===Loader.Ready;onActivated:page.openSurfaceColorPicker()}
                }
            }
            SettingsRow {
                visible:page.selectedSurface.mode!=="transparent"
                width:parent.width;label:"Opacity"
                Row {
                    spacing:Theme.settingsSpacing
                    Text {anchors.verticalCenter:parent.verticalCenter;text:Math.round(page.selectedSurface.opacity*100)+"%";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                    CompactSlider {
                        objectName:"barSurfaceOpacity"
                        valueName:"Bar surface opacity";value:page.selectedSurface.opacity
                        onMoved:function(value){page.editSurface({opacity:value})}
                    }
                }
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:page.selectedSurface.mode==="frosted" ? (SurfaceService.blurAvailable ? "Uses your desktop’s backdrop blur. Opacity controls the tint." : SurfaceService.reason+" A readable background is used instead.") : "Transparent leaves your wallpaper visible behind the bar."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
            Text {
                visible:colorPicker.status===Loader.Error
                width:parent.width;wrapMode:Text.WordWrap;text:"Color selection is unavailable on this system."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }
        SettingsSection {
            sectionId:"bar.widgets";title:"Widgets"
            description:"Show or hide widgets, choose a group, and drag handles to reorder."
            searchQuery:page.query;controlIds:["moduleOrder","showTitle"]
            BarModuleOrderList {
                id:moduleOrder
                objectName:"barModuleOrderList"
                property string controlId:"moduleOrder"
                width:parent.width
                entries:page.selectedLayout.order
                hidden:SettingsStore.hiddenForOutput(page.modulesOutput)
                sides:page.selectedLayout.sides
                onReordered:function(id,destination){page.editModuleOrder(Bar.moveModuleTo(entries,id,destination))}
                onVisibilityToggled:function(id){SettingsStore.setBarWidgetVisible(page.modulesOutput,id,page.hidden(id))}
                onSideChosen:function(id,side){page.editModuleSide(id,side)}
            }
        }
        SettingsSection {
            sectionId:"bar.clock";title:"Clock & labels"
            searchQuery:page.query;controlIds:["clock24","clockDisplay","searchLabel"]
            SettingsToggle {
                objectName:"barClock24"
                controlId:"clock24";visible:page.shows("clock24")
                label:"24-hour clock";checked:page.selectedLayout.use24Hour
                onToggled:function(value){page.edit({use24Hour:value})}
            }
            Column {
                property string controlId:"clockDisplay"
                width:parent.width;spacing:Theme.settingsSpacing
                visible:page.shows("clockDisplay")
                SettingsToggle {
                    objectName:"barClockSeconds"
                    label:"Show seconds";checked:page.selectedLayout.showSeconds
                    onToggled:function(value){page.edit({showSeconds:value})}
                }
                SettingsToggle {
                    objectName:"barClockDate"
                    label:"Show date";checked:page.selectedLayout.showDate
                    onToggled:function(value){page.edit({showDate:value})}
                }
                SettingsRow {
                    width:parent.width;label:"Date style"
                    ChoiceBox {
                        objectName:"barDateFormat"
                        enabled:page.selectedLayout.showDate
                        choices:[{label:"Day and month",value:"short"},{label:"Weekday and date",value:"weekday"},{label:"Year–month–day",value:"iso"}]
                        selectedValue:page.selectedLayout.dateFormat
                        onChosen:function(value){page.edit({dateFormat:value})}
                    }
                }
            }
            SettingsToggle {
                objectName:"barSearchLabel"
                controlId:"searchLabel";visible:page.shows("searchLabel")
                label:"Show Search label";checked:page.selectedLayout.searchLabel
                onToggled:function(value){page.edit({searchLabel:value})}
            }
        }
        SettingsSection {
            sectionId:"bar.fullscreen";title:"Fullscreen apps"
            searchQuery:page.query;controlIds:["fullscreenBarPeek"]
            SettingsToggle {
                objectName:"barFullscreenPeek"
                controlId:"fullscreenBarPeek"
                label:"Reveal bar at the screen edge"
                checked:page.selectedLayout.fullscreenPeek
                onToggled:function(next){page.edit({fullscreenPeek:next})}
            }
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:"Move the pointer to the bar’s screen edge to reveal it over a fullscreen app."
                color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }
    }
}
