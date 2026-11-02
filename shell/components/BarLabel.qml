import QtQuick
import "../themes"

Text {
    textFormat:Text.PlainText
    font.family: Theme.fontFamily
    font.pixelSize: Theme.barFont
    font.weight: Theme.fontWeight
    color: Theme.textPrimary
    elide: Text.ElideRight
}
