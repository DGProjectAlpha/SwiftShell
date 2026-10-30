import QtQuick
import "../components"
import "../themes"

Item {
    id: root

    required property string title
    visible: title !== ""

    BarLabel {
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.title
        color: Theme.textMuted
        elide: Text.ElideRight
        Accessible.role: Accessible.StaticText
        Accessible.name: root.title === "" ? "No focused window" : "Focused window " + root.title
    }
}
