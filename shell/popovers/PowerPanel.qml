import QtQuick
import "../components"
import "../services"
import "../themes"
Item {
    id:panel
    signal settingsRequested()
    implicitWidth:280
    implicitHeight:column.implicitHeight
    width:implicitWidth
    height:implicitHeight
    Component.onCompleted:{PowerProfiles.viewers++;if(!PowerProfiles.busy)PowerProfiles.refresh()}
    Component.onDestruction:PowerProfiles.viewers=Math.max(0,PowerProfiles.viewers-1)
    Column {
        id:column
        width:panel.width
        spacing:Theme.settingsSpacing
        Text {text:"Power";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        SectionHeader {visible:PowerProfiles.available;text:"Power profile"}
        PowerProfileOptions {width:parent.width;compact:true;visible:PowerProfiles.available}
        Text {
            visible:PowerProfiles.error!=="";width:parent.width;wrapMode:Text.WordWrap
            text:PowerProfiles.error;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Text {
            visible:text!=="";width:parent.width;wrapMode:Text.WordWrap
            text:PowerProfiles.reason(PowerProfiles.inhibited || PowerProfiles.degraded)
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Loader {width:parent.width;source:"BatterySection.qml";visible:status===Loader.Ready && item && item.report.available}
        PowerSection {width:parent.width}
        FlatButton {width:parent.width;label:"Power settings…";onActivated:panel.settingsRequested()}
    }
}
