import QtQuick
import "../components"
import "../services"
import "../themes"
Column {
    id:panel
    width:320
    spacing:Theme.settingsSpacing
    signal settingsRequested()
    property bool confirmWifiOff:false
    Component.onCompleted:NetworkService.startViewing()
    Component.onDestruction:NetworkService.stopViewing()
    Row {
        width:parent.width
        Text {width:parent.width-settingsButton.width;height:30;verticalAlignment:Text.AlignVCenter;text:"Network & Devices";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+3;font.weight:Font.Medium}
        FlatButton {id:settingsButton;label:"Settings";onActivated:panel.settingsRequested()}
    }
    Text {width:parent.width;wrapMode:Text.WordWrap;text:NetworkService.error || (!NetworkService.available ? NetworkService.reason : NetworkService.connectivity==="full" ? "Internet connected" : "Local connections");color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
    Repeater {
        model:NetworkService.devices
        delegate:Column {
            required property var modelData
            width:panel.width;spacing:2
            Text {width:parent.width;text:(modelData.kind==="wifi" ? "Wi-Fi" : "Ethernet")+" · "+modelData.state;textFormat:Text.PlainText;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSize}
            Text {width:parent.width;text:modelData.connection;textFormat:Text.PlainText;visible:text!=="";elide:Text.ElideRight;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }
    }
    SettingsToggle {
        width:parent.width
        label:"Wi-Fi"
        checked:NetworkService.wifiEnabled
        enabled:NetworkService.available && !NetworkService.busy && NetworkService.devices.some(function(device){return device.kind==="wifi"})
        onToggled:function(value){if(value)NetworkService.perform("wifi-radio",{enabled:true});else panel.confirmWifiOff=true}
    }
    Column {
        visible:panel.confirmWifiOff;width:parent.width;spacing:4
        Text {text:"Turn off Wi-Fi and disconnect?";color:Theme.settingsText;font.pixelSize:Theme.settingsFontSizeSmall}
        Row {
            spacing:6
            FlatButton {label:"Cancel";onActivated:panel.confirmWifiOff=false}
            FlatButton {label:"Turn off";enabled:!NetworkService.busy;onActivated:{panel.confirmWifiOff=false;NetworkService.perform("wifi-radio",{enabled:false})}}
        }
    }
    FlatButton {label:NetworkService.busy ? "Updating…" : "Manage connections";onActivated:panel.settingsRequested()}
    BluetoothSection {width:panel.width}
}
