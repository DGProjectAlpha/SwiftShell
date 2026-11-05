import QtQuick
import "../components"
import "../logic/displays.js" as Displays
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page
    property string query: ""
    property string highlightId: "displayLayout"
    property var staged: []
    property string selectedId: ""
    property bool dirty: false
    property bool resetRequested: false
    property bool wasPending: false
    property string enableError: ""
    signal revealRequested(real y, real itemHeight)
    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight
    function shows(id) { return Nav.controlVisible(query, id) }
    function moveHighlight(delta) { highlightId = "displayLayout"; revealRequested(0, canvas.height) }
    function focusHighlight() { canvas.forceActiveFocus() }
    function capture() {
        staged = DisplayService.outputs.map(function (m) { return Displays.outputFrom(Object.assign({}, m, {id:m.name})) })
        if (!staged.some(function (m) { return m.id === selectedId })) selectedId = staged.length ? staged[0].id : ""
        dirty = false
        enableError = ""
    }
    function selected() { return staged.find(function (m) { return m.id === selectedId }) || null }
    function update(patch) {
        const list = Displays.clone(staged)
        const item = list.find(function (m) { return m.id === selectedId })
        if (!item) return
        for (const key of Object.keys(patch)) item[key] = patch[key]
        staged = list; dirty = true; enableError = ""
    }
    function modeChoices() {
        const item = selected(); if (!item) return []
        const seen = []
        return (item.modes || []).filter(function (m) {
            const key = m.width + "×" + m.height
            if (seen.indexOf(key) >= 0) return false
            seen.push(key); return true
        }).map(function (m) { return {label:m.width + " × " + m.height, value:m.width + "x" + m.height} })
    }
    function refreshChoices() {
        const item = selected(); if (!item) return []
        return (item.modes || []).filter(function (m) { return m.width === item.width && m.height === item.height })
            .map(function (m) { return {label:m.refresh.toFixed(2) + " Hz", value:m.refresh} })
    }
    function scaleChoices() {
        const item=selected()
        return [.5,.75,1,1.25,1.5,1.6,1.75,2,2.5,3].filter(function(value) {
            return !item || (Math.abs(item.width/value-Math.round(item.width/value))<.02 && Math.abs(item.height/value-Math.round(item.height/value))<.02)
        }).map(function(value){return {label:Math.round(value*100)+"%",value:value}})
    }
    function selectMode(value) {
        const parts = value.split("x")
        const w = Number(parts[0]), h = Number(parts[1])
        const modes = selected().modes.filter(function (m) { return m.width === w && m.height === h })
        const mode = modes.sort(function (a,b) { return b.refresh-a.refresh })[0]
        if (mode) update({width:w, height:h, refresh:mode.refresh})
    }
    function placeBeside(side) {
        const current = selected()
        const other = staged.find(function (m) { return m.id !== selectedId && m.enabled })
        if (!current || !other) return
        update({x:Math.round(side < 0 ? other.x - Displays.logicalWidth(current) : other.x + Displays.logicalWidth(other)), y:other.y})
    }
    Component.onCompleted: { capture(); DisplayService.refresh() }
    Connections {
        target: DisplayService
        function onRefreshed() {
            if (!page.dirty || page.resetRequested || (page.wasPending && !DisplayService.pending)) {
                page.capture(); page.resetRequested = false
            }
            page.wasPending = DisplayService.pending
        }
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.settingsSpacing + 4
        Text { text:"Displays"; color:Theme.settingsText; font.pixelSize:Theme.settingsFontSize+6; font.weight:Font.Medium }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Arrange your screens, then apply. Changes revert automatically unless you keep them."
            color: Theme.settingsMuted
            font.pixelSize: Theme.settingsFontSizeSmall
        }

        Text {
            visible: page.staged.length === 0
            text: "No outputs are connected."
            color: Theme.settingsMuted
            font.pixelSize: Theme.settingsFontSize
        }

        SettingsSection {
            sectionId:"displays.arrangement"
            title:"Arrangement"
            description:""
            searchQuery:page.query
            controlIds:["displayLayout"]
            width:parent.width
            Item {
                id: canvas
                objectName: "displayDiagram"
                width: parent.width
                height: 230
                activeFocusOnTab: true
                property var frozen: null
                readonly property var boxes: Displays.project(page.staged, width, height, 24, frozen)
                Accessible.name: "Display arrangement. Drag to move a screen."
                Rectangle { anchors.fill: parent; radius:Theme.radius; color:Qt.rgba(.5,.5,.5,.04) }
                Repeater {
                    model: canvas.boxes
                    delegate: Rectangle {
                        required property var modelData
                        x:modelData.x; y:modelData.y; width:modelData.width; height:modelData.height
                        radius: 5
                        color: page.selectedId === modelData.id ? Qt.rgba(.6,.6,.6,.2) : Qt.rgba(.5,.5,.5,.07)
                        border.width: 1
                        border.color: page.selectedId === modelData.id ? Theme.settingsText : Theme.settingsMuted
                        Column {
                            anchors.centerIn: parent
                            width: parent.width-8
                            spacing: 4
                            Text { width:parent.width; horizontalAlignment:Text.AlignHCenter; text:modelData.label; color:Theme.settingsText; font.pixelSize:Theme.settingsFontSize; elide:Text.ElideRight }
                            Text { width:parent.width; horizontalAlignment:Text.AlignHCenter; text:page.staged.find(function(m) { return m.id===modelData.id }).friendly || modelData.label; color:Theme.settingsMuted; font.pixelSize:Theme.settingsFontSizeSmall; elide:Text.ElideRight }
                        }
                    }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    enabled: !DisplayService.pending && !DisplayService.busy
                    property string dragId: ""
                    property real lastX: 0
                    property real lastY: 0
                    function hit(px,py) {
                        for (let i=canvas.boxes.length-1;i>=0;i--) {
                            const b=canvas.boxes[i]
                            if (px>=b.x && px<=b.x+b.width && py>=b.y && py<=b.y+b.height) return b.id
                        }
                        return ""
                    }
                    onPressed: function(mouse) {
                        canvas.forceActiveFocus()
                        dragId = hit(mouse.x,mouse.y)
                        if (dragId === "") return
                        page.selectedId = dragId
                        canvas.frozen = {bounds:Displays.bounds(page.staged),scale:Displays.canvasScale(page.staged,canvas.width,canvas.height,24)}
                        lastX=mouse.x; lastY=mouse.y
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed || dragId === "" || !canvas.frozen) return
                        page.staged=Displays.moveBy(page.staged,dragId,(mouse.x-lastX)/canvas.frozen.scale,(mouse.y-lastY)/canvas.frozen.scale)
                        page.dirty=true; lastX=mouse.x; lastY=mouse.y
                    }
                    onReleased: { if (dragId !== "") page.staged=Displays.snapEdges(page.staged,dragId,32); canvas.frozen=null; dragId="" }
                    onCanceled: { canvas.frozen=null; dragId="" }
                }
                Keys.onPressed: function(event) {
                    if (DisplayService.pending) return
                    const directions = ({[Qt.Key_Left]:"left",[Qt.Key_Right]:"right",[Qt.Key_Up]:"up",[Qt.Key_Down]:"down"})
                    const alt = (event.modifiers & Qt.AltModifier) !== 0
                    const keys = ({[Qt.Key_H]:"left",[Qt.Key_L]:"right",[Qt.Key_K]:"up",[Qt.Key_J]:"down"})
                    const direction=directions[event.key] || (alt ? keys[event.key] : "")
                    if (!direction) return
                    page.staged=Displays.nudge(page.staged,page.selectedId,direction,20); page.dirty=true; event.accepted=true
                }
            }
            ChoiceBox {
                width: parent.width
                choices: page.staged.map(function(m) { return {label:m.friendly + " · " + m.name, value:m.id} })
                selectedValue: page.selectedId
                onChosen: function(value) { page.selectedId=value }
                Accessible.name: "Selected display"
            }
        }

        SettingsSection {
            sectionId:"displays.options"
            title:"Display options"
            description:""
            searchQuery:page.query
            controlIds:["displayLayout"]
            width:parent.width
            Column {
                width: parent.width
                spacing: Theme.settingsSpacing
                enabled: !!page.selected() && !DisplayService.pending && !DisplayService.busy
                SettingsToggle {
                    label: "Enable display"
                    checked: page.selected() ? page.selected().enabled : false
                    onToggled: function(next) {
                        const result=Displays.setEnabled(page.staged,page.selectedId,next)
                        page.staged=result.outputs; page.enableError=result.error; page.dirty=result.error === ""
                    }
                }
                SettingsRow {
                    width:parent.width; label:"Resolution"
                    ChoiceBox {
                        choices:page.modeChoices()
                        selectedValue: page.selected() ? page.selected().width + "x" + page.selected().height : ""
                        onChosen: function(value) { page.selectMode(value) }
                        Accessible.name: "Resolution"
                    }
                }
                SettingsRow {
                    width:parent.width; label:"Refresh rate"
                    ChoiceBox {
                        choices:page.refreshChoices()
                        selectedValue: {
                            const item=page.selected()
                            const modes=page.refreshChoices()
                            if (!item) return null
                            const match=modes.find(function(m) { return Math.abs(m.value-item.refresh)<.1 })
                            return match ? match.value : null
                        }
                        onChosen: function(value) { page.update({refresh:value}) }
                        Accessible.name: "Refresh rate"
                    }
                }
                SettingsRow {
                    width:parent.width; label:"Scale"
                    ChoiceBox {
                        choices: page.scaleChoices()
                        selectedValue: page.selected() ? page.selected().scale : 1
                        onChosen: function(value) { page.update({scale:value}) }
                        Accessible.name: "Display scale"
                    }
                }
                SettingsRow {
                    width:parent.width; label:"Orientation"
                    ChoiceBox {
                        choices:["Landscape","Portrait (90°)","Landscape (180°)","Portrait (270°)","Flipped","Flipped (90°)","Flipped (180°)","Flipped (270°)"].map(function(label,value) { return {label:label,value:value} })
                        selectedValue:page.selected() ? page.selected().transform : 0
                        onChosen:function(value) { page.update({transform:value}) }
                        Accessible.name: "Display orientation"
                    }
                }
                SettingsToggle {
                    label:"Adaptive sync"
                    checked:page.selected() ? page.selected().vrr === true : false
                    enabled:!!page.selected() && !!page.selected().hardware && page.selected().vrrSupported === true
                    onToggled:function(value) { page.update({vrr:value}) }
                }
                Text {
                    width:parent.width;wrapMode:Text.WordWrap
                    visible:!!page.selected() && !!page.selected().vrrReason
                    text:page.selected() ? page.selected().vrrReason || "" : ""
                    color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
                }
                SettingsRow {
                    width:parent.width; label:"Position"
                    Row {
                        spacing: 8
                        Repeater {
                            model:["x","y"]
                            delegate: TextInput {
                                required property string modelData
                                width:90; height:Theme.controlHeight
                                color:Theme.settingsText; font.pixelSize:Theme.settingsFontSize
                                text:page.selected() ? page.selected()[modelData] : "0"
                                validator: IntValidator { bottom:-32768; top:32768 }
                                selectByMouse:true; activeFocusOnTab:true
                                Accessible.name:modelData === "x" ? "Horizontal position" : "Vertical position"
                                onEditingFinished: { const patch={}; patch[modelData]=Number(text); page.update(patch) }
                            }
                        }
                    }
                }
                Flow {
                    width:parent.width
                    spacing:8
                    FlatButton { label:"Place left"; enabled:page.staged.length>1; onActivated:page.placeBeside(-1) }
                    FlatButton { label:"Place right"; enabled:page.staged.length>1; onActivated:page.placeBeside(1) }
                }
            }
            Text {
                width:parent.width
                wrapMode:Text.WordWrap
                text: page.selected() ? "Color format: " + page.selected().format + " · " + (page.selected().vrr ? "Adaptive sync on" : "Adaptive sync off") + ". Existing color and HDR settings are preserved." : ""
                color:Theme.settingsMuted; font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        Text {
            width:parent.width; wrapMode:Text.WordWrap
            visible:text !== ""
            text:DisplayService.error || page.enableError || Displays.warnings(page.staged).join(" ") || DisplayService.message
            color:Theme.settingsText; font.pixelSize:Theme.settingsFontSizeSmall
        }

        Column {
            width:parent.width; spacing:8
            visible:DisplayService.pending
            Text { text:"Keep these display settings? " + DisplayService.remaining + " seconds"; color:Theme.settingsText; font.pixelSize:Theme.settingsFontSize }
            Row {
                spacing:8
                FlatButton { label:"Keep"; emphasized:true; enabled:!DisplayService.busy && DisplayService.state === "pending"; onActivated:DisplayService.keep() }
                FlatButton { label:"Revert"; enabled:!DisplayService.busy; onActivated:DisplayService.revert() }
            }
        }

        Flow {
            width:parent.width; spacing:8
            enabled:!DisplayService.busy && !DisplayService.pending
            FlatButton { label:"Reset"; onActivated:{ page.resetRequested=true; DisplayService.refresh() } }
            FlatButton { label:"Apply"; emphasized:true; enabled:page.dirty && Displays.warnings(page.staged).length===0; onActivated:DisplayService.apply(page.staged) }
            FlatButton { label:"Restore saved layout"; enabled:DisplayService.hasSaved; onActivated:DisplayService.restore() }
        }

        Text {
            width:parent.width; wrapMode:Text.WordWrap
            text:"Your original display configuration stays intact. Reloading it restores its layout; Restore saved layout brings back your last kept choice."
            color:Theme.settingsMuted; font.pixelSize:Theme.settingsFontSizeSmall
        }
    }
}
