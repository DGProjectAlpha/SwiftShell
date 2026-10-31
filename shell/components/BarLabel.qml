import QtQuick
import "../themes"

Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.barFont
    font.weight: Theme.fontWeight
    color: Theme.textPrimary
    elide: Text.ElideRight
}
