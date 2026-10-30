import QtQuick
import "../themes"

Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.Normal
    color: Theme.textPrimary
    elide: Text.ElideRight
}
