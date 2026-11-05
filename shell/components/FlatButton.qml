import QtQuick
import QtQuick.Controls.Basic as Controls
import "../themes"

MouseArea {
    id: control

    property string label: ""
    property bool emphasized: false
    property bool navigation: false
    signal activated()

    implicitWidth: Math.max(labelText.implicitWidth + Theme.panelPadding + 8, Theme.controlHeight)
    implicitHeight: Theme.controlHeight
    width: implicitWidth
    height: implicitHeight
    enabled: true
    hoverEnabled: true
    activeFocusOnTab: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: label
    Controls.ToolTip.visible: navigation && (containsMouse || activeFocus)
    Controls.ToolTip.text: Accessible.name
    Controls.ToolTip.delay: 600

    onClicked: {
        if (enabled)
            activated()
    }

    Keys.onPressed: function (event) {
        if (!enabled)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: control.emphasized ? Theme.settingsSelected : (control.containsMouse ? Theme.settingsHover : Theme.transparent)
        radius: Theme.controlRadius
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.controlAccent
    }

    Rectangle {
        visible:control.navigation && control.emphasized
        anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter
        width:2;height:16;radius:1;color:Theme.controlAccent
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: control.navigation ? 12 : Theme.panelPadding / 2
        anchors.rightMargin: Theme.panelPadding / 2
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: control.navigation ? Text.AlignLeft : Text.AlignHCenter
        elide: Text.ElideRight
        text: control.label
        textFormat:Text.PlainText
        font.family: Theme.settingsFontFamily
        font.pixelSize: Theme.settingsFontSize
        font.weight: control.emphasized ? Font.Medium : Theme.fontWeight
        color: Theme.settingsText

        Behavior on color {
            enabled: Theme.motionHover > 0
            ColorAnimation {
                duration: Theme.motionHover
                easing.type: Easing.OutCubic
            }
        }
    }
}
