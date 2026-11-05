import QtQuick
import "../components"
import "../themes"
Column {
    id:panel
    width:360
    spacing:Theme.settingsSpacing+4
    signal settingsRequested()
    Row {
        width:parent.width
        Text {width:parent.width-settingsButton.width;height:30;verticalAlignment:Text.AlignVCenter;text:"Audio";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        FlatButton {id:settingsButton;label:"Settings";onActivated:panel.settingsRequested()}
    }
    MediaSection {id:media;width:parent.width}
    AudioSection {width:parent.width;heading:"Devices & volume"}
    function diagnostics(){return media.diagnostics()}
}
