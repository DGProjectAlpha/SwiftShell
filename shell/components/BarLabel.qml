import QtQuick
import "../themes"

Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Theme.fontWeight
    color: Theme.textPrimary
    elide: Text.ElideRight
}
