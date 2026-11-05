import QtQuick
import QtQuick.Controls.Basic as Controls
import "../logic/weather.js" as Weather
import "../themes"
Item {
    id:root
    property var hours:[]
    implicitWidth:380;implicitHeight:108
    Flickable {
        anchors.fill:parent;clip:true
        contentWidth:row.implicitWidth;contentHeight:height
        boundsBehavior:Flickable.StopAtBounds;flickableDirection:Flickable.HorizontalFlick
        Controls.ScrollBar.horizontal:Controls.ScrollBar {height:3;policy:parent.contentWidth>parent.width ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff;contentItem:Rectangle {color:Theme.settingsMuted;radius:1.5;opacity:.35} background:Item {}}
        Row {
            id:row;spacing:8
            Repeater {
                model:root.hours
                delegate:Column {
                    required property var modelData
                    width:48;spacing:5
                    Text {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:modelData.label;textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                    WeatherGlyph {anchors.horizontalCenter:parent.horizontalCenter;width:25;height:25;code:modelData.code;daylight:modelData.isDay;foreground:Theme.settingsText}
                    Text {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:Weather.temperature(modelData.temperature);color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                    Text {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:Weather.percent(modelData.probability);color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                }
            }
        }
    }
}
