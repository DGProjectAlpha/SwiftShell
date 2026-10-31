import QtQuick
import Quickshell
import "../components"
import "../logic/displays.js" as Displays
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    property var staged: []
    property string selectedId: ""
    property bool usingFallback: false
    property string enableError: ""
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
        canvas.forceActiveFocus()
    }

    function capture() {
        var screens = Quickshell.screens || []
        var records = []
        for (var index = 0; index < screens.length; index++) {
            var screen = screens[index]
            records.push(Displays.fromScreen(screen, HyprlandModel.monitorObjectForScreen(screen)))
        }
        page.usingFallback = Displays.needsRow(records)
        page.staged = Displays.withFallbackRow(records)
        page.enableError = ""
        if (page.staged.length > 0 && page.selectedId === "")
            page.selectedId = page.staged[0].id
    }

    function selected() {
        for (var index = 0; index < page.staged.length; index++) {
            if (page.staged[index].id === page.selectedId)
                return page.staged[index]
        }
        return null
    }

    onQueryChanged: page.highlightId = Nav.firstControlId(page.query)
    Component.onCompleted: capture()

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Displays"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Displays.APPLY_REASON
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.usingFallback
            text: "Positions were not reported, so the preview places outputs in a row."
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: !Quickshell.screens || Quickshell.screens.length === 0
            text: "No outputs are connected to this process."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Item {
            id: canvas
            width: parent.width
            height: 220
            focus: true
            activeFocusOnTab: true
            Accessible.name: "Display arrangement preview"

            readonly property var boxes: Displays.project(page.staged, width, height, 12)

            Rectangle {
                anchors.fill: parent
                color: Theme.transparent
                border.width: 1
                border.color: Theme.panelMuted
            }

            Repeater {
                model: canvas.boxes

                delegate: Rectangle {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height
                    color: page.selectedId === modelData.id ? Theme.panelHover : Theme.transparent
                    border.width: 1
                    border.color: Theme.panelText

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.label
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                property string dragId: ""
                property real lastX: 0
                property real lastY: 0

                function hit(px, py) {
                    var boxes = canvas.boxes
                    for (var index = boxes.length - 1; index >= 0; index--) {
                        var box = boxes[index]
                        if (px >= box.x && px <= box.x + box.width && py >= box.y && py <= box.y + box.height)
                            return box.id
                    }
                    return ""
                }

                onPressed: function (mouse) {
                    canvas.forceActiveFocus()
                    drag.dragId = hit(mouse.x, mouse.y)
                    page.selectedId = drag.dragId
                    drag.lastX = mouse.x
                    drag.lastY = mouse.y
                }

                onPositionChanged: function (mouse) {
                    if (!pressed || drag.dragId === "")
                        return
                    var scale = Displays.canvasScale(page.staged, canvas.width, canvas.height, 12)
                    if (!(scale > 0))
                        return
                    page.staged = Displays.moveBy(page.staged, drag.dragId, (mouse.x - drag.lastX) / scale, (mouse.y - drag.lastY) / scale)
                    drag.lastX = mouse.x
                    drag.lastY = mouse.y
                }

                onReleased: page.staged = Displays.snapEdges(page.staged, drag.dragId, 40)
            }

            Keys.onPressed: function (event) {
                var alt = (event.modifiers & Qt.AltModifier) !== 0
                var direction = ""
                if (alt && event.key === Qt.Key_H)
                    direction = "left"
                else if (alt && event.key === Qt.Key_L)
                    direction = "right"
                else if (alt && event.key === Qt.Key_K)
                    direction = "up"
                else if (alt && event.key === Qt.Key_J)
                    direction = "down"
                else if (event.key === Qt.Key_Left)
                    direction = "left"
                else if (event.key === Qt.Key_Right)
                    direction = "right"
                else if (event.key === Qt.Key_Up)
                    direction = "up"
                else if (event.key === Qt.Key_Down)
                    direction = "down"
                if (direction === "")
                    return
                page.staged = Displays.nudge(page.staged, page.selectedId, direction, 80)
                event.accepted = true
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Drag a display in the preview. Alt+H, Alt+J, Alt+K, and Alt+L move the selected one. Arrow keys do the same when the diagram is focused."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: Displays.warnings(page.staged).length > 0
            text: Displays.warnings(page.staged).join(" ")
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.enableError !== ""
            text: page.enableError
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            id: detail
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
                var item = page.selected()
                if (!item)
                    return "No display is selected."
                return item.name + "  " + item.width + "×" + item.height + "  scale " + item.scale + (item.refresh > 0 ? "  " + item.refresh + " Hz" : "") + (item.description !== "" ? "  " + item.description : "")
            }
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "The current size is shown. Choosing another resolution, refresh rate, rotation, or HDR mode is unavailable because no verified mode list is connected."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            spacing: Theme.panelSpacing

            FlatButton {
                label: "Reset preview"
                onActivated: page.capture()
            }

            FlatButton {
                label: "Apply unavailable"
                enabled: false
                onActivated: {}
            }
        }
    }
}
