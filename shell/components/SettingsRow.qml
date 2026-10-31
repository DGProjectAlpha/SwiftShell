import QtQuick
import "../themes"

Item {
    id: row

    property string label: ""
    default property alias extra: slot.data

    implicitWidth: 480
    implicitHeight: Math.max(Theme.controlHeight, labelText.implicitHeight, slot.implicitHeight)
    height: implicitHeight

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Theme.panelSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: Theme.panelText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: Math.max(Theme.controlHeight, childrenRect.height)
    }
}
