import QtQuick
import "../themes"

Row {
    id: root

    property string name: ""
    property string detail: ""

    width: parent ? parent.width : implicitWidth
    spacing: Theme.panelSpacing
    Accessible.role: Accessible.StaticText
    Accessible.name: name + " " + detail

    Text {
        id: nameText
        text: root.name
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Normal
        color: Theme.panelMuted
    }

    Text {
        width: Math.max(0, root.width - nameText.implicitWidth - root.spacing)
        text: root.detail
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Normal
        color: Theme.panelMuted
    }
}
