import QtQuick
import "../themes"

MouseArea {
    id: control

    property string label: ""
    property string controlId: ""
    property bool marked: false
    property bool checked: false
    signal toggled(bool next)

    implicitWidth: Math.max(labelText.implicitWidth + 40, Theme.controlHeight)
    implicitHeight: Theme.controlHeight
    width: implicitWidth
    height: implicitHeight
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: checked

    function flip() {
        toggled(!checked)
    }

    onClicked: flip()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            flip()
            event.accepted = true
        }
    }

    Rectangle {
        width: 28
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        color: control.checked ? Theme.panelText : Theme.panelHover
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.panelText
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 36
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: control.label
        color: Theme.panelText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: control.marked ? Font.Medium : Font.Normal
    }
}
