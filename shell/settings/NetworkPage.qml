import QtQuick
import QtQuick.Controls.Basic as Controls
import "../components"
import "../services"
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"networkStatus"
    property var joining:null
    property var confirmation:null
    property bool showSaved:false
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function shows(id) {return query.trim()==="" || /network|wifi|wi-fi|ethernet|bluetooth|device|connection/i.test(query)}
    function focusHighlight() {refreshButton.forceActiveFocus()}
    function moveHighlight(delta) {revealRequested(0,height)}
    function requestDisconnect(device) {confirmation={action:"device-disconnect",device:device.id,label:"Disconnect "+(device.connection || device.id)+"?"}}
    function join(network) {
        if(network.security) {joining=network;password.text="";Qt.callLater(function(){password.forceActiveFocus()})}
        else NetworkService.perform("wifi-connect",{device:network.device,id:network.id,secret:""})
    }
    function submitPassword() {
        // Enter can arrive while a background device refresh is in flight.
        // Keep the local draft until the service actually accepts the request.
        if(!joining || NetworkService.busy)return false
        const values={device:joining.device,id:joining.id,secret:password.text}
        if(!NetworkService.perform("wifi-connect",values))return false
        password.text="";joining=null
        return true
    }
    Component.onCompleted:NetworkService.startViewing()
    Component.onDestruction:{password.text="";NetworkService.stopViewing()}
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {text:"Network & Devices";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Manage your internet connections, wireless networks and Bluetooth devices.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Row {
            spacing:8
            FlatButton {id:refreshButton;label:NetworkService.busy ? "Updating…" : "Refresh";enabled:!NetworkService.busy;onActivated:NetworkService.refresh()}
            Text {anchors.verticalCenter:parent.verticalCenter;text:NetworkService.available ? (NetworkService.connectivity==="full" ? "Internet connected" : "Network connections") : "";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        Text {width:parent.width;wrapMode:Text.WordWrap;visible:text!=="";text:NetworkService.error || (!NetworkService.available ? NetworkService.reason : "");color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Column {
            width:parent.width;spacing:6;visible:page.confirmation!==null
            Text {width:parent.width;wrapMode:Text.WordWrap;text:page.confirmation ? page.confirmation.label : "";textFormat:Text.PlainText;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSize}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"Active connections may be interrupted.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            Row {
                spacing:6
                FlatButton {label:"Cancel";onActivated:page.confirmation=null}
                FlatButton {label:"Disconnect";enabled:!NetworkService.busy;onActivated:{const request=page.confirmation;page.confirmation=null;NetworkService.perform(request.action,request.action==="wifi-radio" ? {enabled:false} : {device:request.device})}}
            }
        }
        SectionHeader {width:parent.width;text:"Connections"}
        Repeater {
            model:NetworkService.devices
            delegate:Column {
                required property var modelData
                width:column.width;spacing:4
                SettingsRow {
                    width:parent.width
                    label:(modelData.kind==="wifi" ? "Wi-Fi" : "Ethernet")+" · "+modelData.id
                    Row {
                        spacing:6
                        Text {height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:modelData.state.replace(/\b\w/g,function(c){return c.toUpperCase()});color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                        FlatButton {label:modelData.connected ? "Disconnect" : "Connect";enabled:NetworkService.available && !NetworkService.busy && modelData.available;onActivated:modelData.connected ? page.requestDisconnect(modelData) : NetworkService.perform("device-connect",{device:modelData.id})}
                    }
                }
                Text {width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText;text:modelData.connection+(modelData.addresses.length ? " · "+modelData.addresses.join(", ") : "");visible:text!=="";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            }
        }
        Text {visible:NetworkService.available && !NetworkService.devices.length;text:"No network adapters are available.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        SectionHeader {width:parent.width;text:"Wi-Fi"}
        SettingsToggle {
            width:parent.width
            label:"Wi-Fi"
            checked:NetworkService.wifiEnabled
            enabled:NetworkService.available && NetworkService.devices.some(function(device){return device.kind==="wifi"}) && !NetworkService.busy
            onToggled:function(value){if(value)NetworkService.perform("wifi-radio",{enabled:true});else page.confirmation={action:"wifi-radio",label:"Turn off Wi-Fi?"}}
        }
        Text {width:parent.width;wrapMode:Text.WordWrap;visible:!NetworkService.wifiEnabled || !NetworkService.wifiHardware;text:!NetworkService.wifiHardware ? "Wi-Fi is blocked by your hardware or no wireless adapter is available." : "Turn on Wi-Fi to find nearby networks.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        FlatButton {
            label:"Find networks"
            visible:NetworkService.wifiEnabled
            enabled:NetworkService.available && !NetworkService.busy && NetworkService.devices.some(function(device){return device.kind==="wifi" && device.available})
            onActivated:{const adapter=NetworkService.devices.find(function(device){return device.kind==="wifi" && device.available});if(adapter)NetworkService.perform("scan",{device:adapter.id})}
        }
        Text {width:parent.width;visible:NetworkService.wifiEnabled && !NetworkService.networks.length;text:NetworkService.busy ? "Looking for networks…" : "No nearby networks found. Refresh or move closer to your access point.";wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        Repeater {
            model:NetworkService.wifiEnabled ? NetworkService.networks : []
            delegate:SettingsRow {
                required property var modelData
                width:column.width;label:modelData.name
                Row {
                    spacing:6
                    Text {height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:modelData.signal+"% · "+(modelData.security || "Open");color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                    FlatButton {label:modelData.active ? "Connected" : "Connect";enabled:NetworkService.available && !modelData.active && modelData.supported && !NetworkService.busy;onActivated:page.join(modelData)}
                }
            }
        }
        Column {
            width:parent.width;spacing:6;visible:page.joining!==null
            Text {text:page.joining ? "Connect to "+page.joining.name : "";textFormat:Text.PlainText;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSize}
            Rectangle {
                width:Math.min(320,parent.width);height:34;radius:6;color:Theme.settingsHover
                Text {anchors.fill:parent;anchors.leftMargin:10;verticalAlignment:Text.AlignVCenter;visible:!password.text;text:"Wi-Fi password";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                TextInput {id:password;objectName:"wifiPassword";anchors.fill:parent;anchors.margins:8;echoMode:TextInput.Password;selectByMouse:true;clip:true;maximumLength:64;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSize;Accessible.name:"Wi-Fi password";onAccepted:page.submitPassword()}
            }
            Row {
                spacing:6
                FlatButton {label:"Cancel";onActivated:{password.text="";page.joining=null}}
                FlatButton {label:"Connect";enabled:!NetworkService.busy && password.text.length>=8;onActivated:page.submitPassword()}
            }
        }
        FlatButton {label:page.showSaved ? "Hide saved connections" : "Saved connections";onActivated:page.showSaved=!page.showSaved}
        Repeater {
            model:page.showSaved ? NetworkService.profiles : []
            delegate:SettingsRow {
                required property var modelData
                width:column.width;label:modelData.name
                FlatButton {label:modelData.device ? "Connected" : "Connect";enabled:NetworkService.available && !modelData.device && !NetworkService.busy;onActivated:NetworkService.perform("profile-connect",{id:modelData.id})}
            }
        }
        Text {width:parent.width;wrapMode:Text.WordWrap;visible:page.showSaved;text:"Enterprise Wi-Fi uses an existing saved connection profile. New connections support open and personal WPA networks.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        BluetoothPage {width:parent.width;query:page.query}
    }
}
