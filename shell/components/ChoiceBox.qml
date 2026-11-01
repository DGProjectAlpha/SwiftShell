import QtQuick
import QtQuick.Controls.Basic as Controls
import "../themes"

Controls.ComboBox {
    id: control
    property var choices: []
    property var selectedValue: null
    signal chosen(var value)
    model: choices
    textRole: "label"
    valueRole: "value"
    currentIndex: {
        for (let i = 0; i < choices.length; i++) {
            if (choices[i].value === selectedValue) return i
        }
        return -1
    }
    width: 240
    height: Theme.controlHeight + 6
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    onActivated: chosen(currentValue)
    background: Rectangle {
        radius: Theme.controlRadius
        color: control.down ? Qt.rgba(.5,.5,.5,.18) : Qt.rgba(.5,.5,.5,control.hovered ? .12 : .07)
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.panelMuted
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 26
        text: control.displayText
        verticalAlignment: Text.AlignVCenter
        font: control.font
        color: control.enabled ? Theme.panelText : Theme.panelMuted
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - 22
        y: (control.height-height)/2
        text: "⌄"
        color: Theme.panelMuted
    }
    delegate: Controls.ItemDelegate {
        width: control.width
        text: modelData.label
        font: control.font
        highlighted: control.highlightedIndex === index
        contentItem: Text { text: modelData.label; color: Theme.panelText; font: control.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Theme.controlRadius; color: highlighted ? Qt.rgba(.5,.5,.5,.2) : "transparent" }
    }
    popup: Controls.Popup {
        y: control.height + 4
        width: control.width
        padding: 5
        implicitHeight: Math.min(260, list.contentHeight + 10)
        contentItem: ListView {
            id: list
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }
        background: Rectangle { radius: Theme.controlRadius + 2; color: Theme.panelColor }
    }
}
