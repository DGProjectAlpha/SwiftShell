import QtQuick
import "../components"
import "../services"
import "../themes"
MouseArea {
    id:root
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    property color textHover:Theme.textPrimary
    signal activated()
    implicitWidth:SettingsStore.weatherEnabled ? content.implicitWidth : 0
    implicitHeight:Theme.barHeight
    width:implicitWidth;height:implicitHeight
    visible:SettingsStore.weatherEnabled
    hoverEnabled:true;activeFocusOnTab:true;cursorShape:Qt.PointingHandCursor
    Accessible.role:Accessible.Button
    Accessible.name:"Weather "+WeatherService.barText
    onClicked:activated()
    Keys.onPressed:function(event){if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activated();event.accepted=true}}
    Row {
        id:content;anchors.verticalCenter:parent.verticalCenter;spacing:5
        WeatherGlyph {width:Math.max(16,Theme.barIcon);height:width;code:WeatherService.forecast ? WeatherService.forecast.current.code : null;daylight:!WeatherService.forecast || WeatherService.forecast.current.isDay;foreground:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary}
        Text {text:WeatherService.barText;textFormat:Text.PlainText;color:root.containsMouse || root.activeFocus ? root.textHover : root.textPrimary;font.family:Theme.fontFamily;font.pixelSize:Theme.barFont;renderType:Theme.barTextRendering(root);anchors.verticalCenter:parent.verticalCenter}
    }
}
