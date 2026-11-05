import QtQuick
import "../themes"

Item {
    id:preview
    implicitHeight:126
    height:implicitHeight
    Accessible.name:"Appearance preview: text, controls, corners, opacity and shadow"
    Rectangle {
        anchors.fill:parent
        radius:Theme.radius
        color:Theme.lightSurface ? "#d7d7d7" : "#373737"
        gradient:Gradient {
            orientation:Gradient.Horizontal
            GradientStop {position:0;color:Theme.lightSurface ? "#c7c7c7" : "#262626"}
            GradientStop {position:1;color:Theme.lightSurface ? "#e9e9e9" : "#626262"}
        }
    }
    Item {
        id:sample
        x:16;y:14;width:parent.width-32;height:parent.height-28
        Loader {anchors.fill:parent;source:"../components/SurfaceShadow.qml";active:Theme.shadowOpacity>0}
        Rectangle {
            anchors.fill:parent
            radius:Theme.radius
            color:Theme.settingsSurface
            Text {
                x:14;y:14;width:Math.max(100,parent.width-280)
                text:"Live preview";color:Theme.settingsText
                font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+2;font.weight:Theme.fontWeight
                elide:Text.ElideRight
            }
            Text {
                x:14;y:44;width:Math.max(100,parent.width-280)
                text:Theme.settingsFontSize+" px · "+Theme.radius+" px corners"
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
                elide:Text.ElideRight
            }
            Row {
                x:parent.width-width-16;y:(parent.height-height)/2
                spacing:12
                Rectangle {width:84;height:28;radius:Theme.controlRadius;color:Theme.settingsSelected;Text {anchors.centerIn:parent;text:"Selected";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}}
                Rectangle {width:78;height:5;radius:height/2;anchors.verticalCenter:parent.verticalCenter;color:Theme.controlAccent;Rectangle {width:14;height:14;radius:7;x:parent.width*.6;anchors.verticalCenter:parent.verticalCenter;color:Theme.controlAccent}}
                Rectangle {width:32;height:18;radius:9;anchors.verticalCenter:parent.verticalCenter;color:Theme.controlAccent;Rectangle {x:17;y:3;width:12;height:12;radius:6;color:Theme.accentForeground}}
            }
        }
    }
}
