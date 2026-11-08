import QtQuick
import "../themes"

Text {
    readonly property var barSizing:Theme.barMetricsFor(this)
    renderType:Theme.barTextRendering(this)
    antialiasing:true
    font.hintingPreference:Font.PreferVerticalHinting
    textFormat:Text.PlainText
    font.family: Theme.fontFamily
    font.pixelSize: barSizing.font
    font.weight: Theme.fontWeight
    color: Theme.textPrimary
    elide: Text.ElideRight
}
