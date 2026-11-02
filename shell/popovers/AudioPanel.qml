import QtQuick
import "../components"
import "../themes"
Column {
    id:panel
    width:340
    spacing:Theme.settingsSpacing+4
    signal settingsRequested()
    Row {
        width:parent.width
        Text {width:parent.width-settingsButton.width;height:30;verticalAlignment:Text.AlignVCenter;text:"Audio";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        FlatButton {id:settingsButton;label:"Settings";onActivated:panel.settingsRequested()}
    }
    AudioSection {width:parent.width;heading:""}
    MediaSection {width:parent.width}
}
