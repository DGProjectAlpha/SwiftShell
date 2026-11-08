import QtQuick
import "../themes"

Text {
    renderType:Theme.barTextRendering(this)
    antialiasing:true
    font.hintingPreference:Font.PreferVerticalHinting
    textFormat:Text.PlainText
    font.family: Theme.fontFamily
    font.pixelSize: Theme.barFont
    font.weight: Theme.fontWeight
    color: Theme.textPrimary
    elide: Text.ElideRight
}
