import QtQuick
import "../themes"

Item {
    id: root

    default property alias content: body.data

    implicitWidth: card.width + Theme.shadowSoftness
    implicitHeight: card.height + Theme.shadowSoftness

    Rectangle {
        anchors.fill: card
        anchors.margins: -Math.round(Theme.shadowSoftness / 3)
        radius: Theme.radius
        color: Theme.shadowColor
        opacity: Theme.shadowOpacity
    }

    Rectangle {
        id: card
        x: Theme.shadowSoftness / 2
        y: Theme.shadowSoftness / 2
        width: body.implicitWidth + Theme.panelPadding * 2
        height: body.implicitHeight + Theme.panelPadding * 2
        radius: Theme.radius
        color: Theme.panelColor
        border.width: 0

        Column {
            id: body
            x: Theme.panelPadding
            y: Theme.panelPadding
            spacing: Theme.panelSpacing
        }
    }
}
