import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../logic/shortcuts.js" as Shortcuts
import "../services"
import "../themes"

Item {
    id: page

    property string query: ""
    property string highlightId: ""
    property var recorder: Shortcuts.emptyRecorder()
    signal revealRequested(real y, real itemHeight)

    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) {
        return Nav.controlVisible(page.query, id)
    }

    function focusHighlight() {
        capture.forceActiveFocus()
    }

    function moveHighlight(delta) {
        page.highlightId = Nav.moveSelection(page.query, page.highlightId, delta)
    }

    function map() {
        return Shortcuts.parseMap(SettingsStore.shortcutsJson)
    }

    function modifiersOf(event) {
        var mods = []
        if ((event.modifiers & Qt.AltModifier) !== 0)
            mods.push("alt")
        if ((event.modifiers & Qt.ControlModifier) !== 0)
            mods.push("ctrl")
        if ((event.modifiers & Qt.ShiftModifier) !== 0)
            mods.push("shift")
        if ((event.modifiers & Qt.MetaModifier) !== 0)
            mods.push("super")
        return mods
    }

    function keyName(event) {
        if (event.key === Qt.Key_Escape)
            return "Escape"
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            return "Return"
        if (event.key === Qt.Key_Space)
            return "Space"
        if (event.key === Qt.Key_Tab)
            return "Tab"
        if (event.text && event.text.length === 1)
            return event.text
        return ""
    }

    Column {
        id: column
        width: page.width
        spacing: Theme.panelSpacing

        Text {
            width: parent.width
            text: "Shortcuts"
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "These are preferred chords for SwiftShell actions. Saving one does not install it. Compositor binds are not read and are not changed. Super+Space stays on the documented handoff."
            color: Theme.panelMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: Shortcuts.ACTIONS

            delegate: SettingsRow {
                required property var modelData
                width: column.width
                label: modelData.label

                Row {
                    spacing: Theme.panelSpacing

                    Text {
                        width: 140
                        elide: Text.ElideRight
                        text: Shortcuts.chordText(page.map()[modelData.id])
                        color: Theme.panelText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    FlatButton {
                        label: page.recorder.phase === "recording" && page.recorder.id === modelData.id ? "Listening" : "Record"
                        emphasized: page.recorder.id === modelData.id
                        onActivated: {
                            page.recorder = Shortcuts.reduceRecorder(page.recorder, { type: "start", id: modelData.id })
                            capture.forceActiveFocus()
                        }
                    }

                    FlatButton {
                        label: "Clear"
                        onActivated: SettingsStore.clearShortcut(modelData.id)
                    }
                }
            }
        }

        Item {
            id: capture
            width: parent.width
            height: Theme.controlHeight
            focus: true
            activeFocusOnTab: true
            Accessible.name: "Shortcut capture"

            Keys.onPressed: function (event) {
                if (page.recorder.phase !== "recording")
                    return
                var name = page.keyName(event)
                if (name === "")
                    return
                if (name === "Return" && page.recorder.key !== "") {
                    var saved = Shortcuts.reduceRecorder(page.recorder, { type: "confirm" })
                    if (saved.saved)
                        SettingsStore.setShortcut(saved.saved.id, saved.saved.modifiers, saved.saved.key)
                    page.recorder = saved.saved ? Shortcuts.emptyRecorder() : saved
                    event.accepted = true
                    return
                }
                page.recorder = Shortcuts.reduceRecorder(page.recorder, {
                    type: "key",
                    key: name,
                    modifiers: page.modifiersOf(event),
                    map: page.map()
                })
                event.accepted = true
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: page.recorder.phase === "recording"
            text: page.recorder.error !== "" ? page.recorder.error : "Press the chord, then Enter. Escape cancels. " + Shortcuts.chordText({ modifiers: page.recorder.modifiers, key: page.recorder.key })
            color: Theme.panelText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
