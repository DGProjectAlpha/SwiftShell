import QtQuick
import QtQuick.Effects
import "../themes"
Item {
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radius
        blur: Theme.shadowSoftness
        offset: Qt.vector2d(0, 3)
        color: Qt.rgba(0,0,0,Theme.shadowOpacity)
    }
}
