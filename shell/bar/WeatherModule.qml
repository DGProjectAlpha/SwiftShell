import QtQuick
import "../components"
import "../services"
import "../themes"
MouseArea {
    id:root
    readonly property var barSizing:Theme.barMetricsFor(root)
    function sized(value) {return Math.round(value*barSizing.sizeScale)}
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    property color textHover:Theme.textPrimary
    signal activated()
    implicitWidth:SettingsStore.weatherEnabled ? content.implicitWidth : 0
    implicitHeight:root.barSizing.height
    width:implicitWidth;height:implicitHeight
    visible:SettingsStore.weatherEnabled
    hoverEnabled:true;activeFocusOnTab:true;cursorShape:Qt.PointingHandCursor
    Accessible.role:Accessible.Button
    Accessible.name:"Weather "+WeatherService.barText
    onClicked:activated()
    Keys.onPressed:function(event){if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activated();event.accepted=true}}
    Row {
        id:content;anchors.verticalCenter:parent.verticalCenter;spacing:root.sized(5)
        WeatherGlyph {width:root.barSizing.weatherIcon;height:width;code:WeatherService.forecast ? WeatherService.forecast.current.code : null;daylight:!WeatherService.forecast || WeatherService.forecast.current.isDay;foreground:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary}
        Text {text:WeatherService.barText;textFormat:Text.PlainText;color:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary;font.family:Theme.fontFamily;font.pixelSize:root.barSizing.font;renderType:Theme.barTextRendering(root);antialiasing:true;font.hintingPreference:Font.PreferVerticalHinting;anchors.verticalCenter:parent.verticalCenter}
    }
}
