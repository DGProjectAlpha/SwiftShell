import QtQuick
import "../themes"

Item {
    id: row

    property string label: ""
    property string controlId: ""
    property bool marked: false
    default property alias extra: slot.data

    readonly property bool stacked: slot.childrenRect.width > width * .75

    implicitWidth: 480
    implicitHeight: stacked ? labelText.implicitHeight + slot.height + 12 : Math.max(34, labelText.implicitHeight + 8, slot.height + 4)
    height: implicitHeight

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: row.stacked ? parent.right : slot.left
        anchors.rightMargin: Theme.panelSpacing
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        y: row.stacked ? 0 : (row.height-height)/2
        textFormat:Text.PlainText
        text: row.label
        color: Theme.settingsText
        font.family: Theme.settingsFontFamily
        font.pixelSize: Theme.settingsFontSize
        font.weight: row.marked ? Font.Medium : Theme.fontWeight
        elide: Text.ElideRight
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        y: row.stacked ? labelText.implicitHeight + 6 : (row.height-height)/2
        width: childrenRect.width
        height: Math.max(Theme.controlHeight, childrenRect.height)
    }
}
