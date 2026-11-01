import QtQuick
import "../themes"
import "../services"

MouseArea {
    id: control

    property string label: ""
    property string controlId: ""
    property bool marked: false
    property bool checked: false
    signal toggled(bool next)

    implicitWidth: Math.max(labelText.implicitWidth + 40, Theme.controlHeight)
    implicitHeight: Math.max(38, Theme.controlHeight)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : .45
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
        id: track
        width: 32
        height: 18
        radius: 9
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: control.checked ? Theme.settingsText : Theme.settingsSelected
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.settingsText
        Rectangle {
            width:12; height:12; radius:6
            x:control.checked ? 17 : 3; y:3
            color: control.checked ? (SettingsStore.appearanceMode === "light" ? "white" : "#222222") : Theme.settingsMuted
        }
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: track.left
        anchors.leftMargin: 0
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: control.label
        color: Theme.settingsText
        font.family: Theme.settingsFontFamily
        font.pixelSize: Theme.settingsFontSize
        font.weight: control.marked ? Font.Medium : Theme.fontWeight
    }
}
