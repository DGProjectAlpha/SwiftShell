import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Controls as ControlTypes
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
    property bool showPassword:false
    property string credentialError:""
    property var returnFocus:null
    readonly property bool authOpen:passwordDialog.opened
    readonly property bool confirmationOpen:confirmationDialog.opened
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function shows(id) {return query.trim()==="" || /network|wifi|wi-fi|ethernet|bluetooth|device|connection/i.test(query)}
    function focusHighlight() {if(highlightId==="bluetoothDevices"){bluetoothGroup.reveal();Qt.callLater(function(){bluetoothPage.focusHighlight()})}else {connectionsGroup.reveal();refreshButton.forceActiveFocus()}}
    onHighlightIdChanged:if(highlightId==="bluetoothDevices"){bluetoothGroup.reveal();Qt.callLater(function(){page.revealRequested(bluetoothGroup.y,bluetoothGroup.height)})}
    function moveHighlight(delta) {revealRequested(0,height)}
    function requestDisconnect(device) {confirmation={action:"device-disconnect",device:device.id,label:"Disconnect "+(device.connection || device.id)+"?"}}
    function cancelDraft() {password.text="";joining=null;showPassword=false;credentialError="";passwordDialog.close()}
    function join(network) {
        if(!network || NetworkService.operationBusy)return false
        credentialError="";showPassword=false
        if(network.security) {returnFocus=page.Window.window ? page.Window.window.activeFocusItem : null;joining=network;password.text="";passwordDialog.open()}
        else NetworkService.perform("wifi-connect",{device:network.device,id:network.id,secret:""})
        return true
    }
    function validPassword(value) {
        return typeof value==="string" && !/[\r\n\0]/.test(value) && (value.length>=8 && value.length<=63 || /^[0-9a-fA-F]{64}$/.test(value))
    }
    function retryConnection() {
        const failure=NetworkService.lastFailure
        if(!failure || NetworkService.busy)return false
        if(failure.action==="wifi-connect") {
            const target=NetworkService.networks.find(function(network){return network.id===failure.id && network.device===failure.device})
            if(!target){NetworkService.refresh();return false}
            NetworkService.clearError();return join(target)
        }
        return NetworkService.perform(failure.action,{device:failure.device,id:failure.id,enabled:failure.enabled})
    }
    function submitPassword() {
        // Enter can arrive while a background device refresh is in flight.
        // Keep the local draft until the service actually accepts the request.
        if(!joining || NetworkService.operationBusy)return false
        if(!validPassword(password.text)) {credentialError="Enter an 8–63 character password or a 64-digit hexadecimal key.";return false}
        const values={device:joining.device,id:joining.id,secret:password.text}
        if(!NetworkService.perform("wifi-connect",values))return false
        cancelDraft()
        return true
    }
    onConfirmationChanged: {
        if(confirmation!==null) {
            returnFocus=page.Window.window ? page.Window.window.activeFocusItem : null
            confirmationDialog.open()
        } else confirmationDialog.close()
    }
    function restoreFocus() {
        const target=returnFocus;returnFocus=null
        if(target && target.visible && target.enabled)target.forceActiveFocus()
    }
    Component.onCompleted:NetworkService.startViewing()
    Component.onDestruction:{password.text="";NetworkService.stopViewing()}
    Connections {
        target:NetworkService
        function onWifiEnabledChanged(){if(!NetworkService.wifiEnabled && page.joining)page.cancelDraft()}
        function onDevicesChanged(){if(page.joining && NetworkService.devices.length && !NetworkService.devices.some(function(device){return device.id===page.joining.device})){page.cancelDraft()}}
    }
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

        Row {
            width:parent.width;spacing:8
            visible:NetworkService.progressText!=="" || NetworkService.error!==""
            Text {width:Math.max(100,parent.width-(cancelOperation.visible ? cancelOperation.width+8 : 0)-(retryOperation.visible ? retryOperation.width+8 : 0));height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight;text:NetworkService.progressText;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSizeSmall}
            FlatButton {id:cancelOperation;objectName:"networkCancelOperation";visible:NetworkService.canCancel;label:"Cancel connection";onActivated:NetworkService.cancel()}
            FlatButton {id:retryOperation;objectName:"networkRetryOperation";visible:!NetworkService.busy && ["wifi-connect","device-connect","profile-connect","scan","device-disconnect","wifi-radio"].indexOf(NetworkService.lastFailure.action)>=0;label:"Try again";onActivated:page.retryConnection()}
        }

        SettingsSection {
            id:connectionsGroup
            sectionId:"network.connectionsGroup"
            title:"Connections"
            searchQuery:page.query
            controlIds:["networkStatus"]
            width:parent.width
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
                            FlatButton {label:modelData.connected ? "Disconnect" : modelData.kind==="wifi" ? "Find networks" : "Connect";enabled:NetworkService.available && !NetworkService.operationBusy && modelData.available;onActivated:modelData.connected ? page.requestDisconnect(modelData) : NetworkService.perform(modelData.kind==="wifi" ? "scan" : "device-connect",{device:modelData.id})}
                        }
                    }
                    Text {width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText;text:modelData.connection+(modelData.addresses.length ? " · "+modelData.addresses.join(", ") : "");visible:text!=="";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                }
            }
            Text {visible:NetworkService.available && !NetworkService.devices.length;text:"No network adapters are available.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }

        SettingsSection {
            id:bluetoothGroup
            sectionId:"network.bluetoothGroup"
            title:"Bluetooth"
            searchQuery:page.query
            controlIds:["bluetoothDevices"]
            width:parent.width
            BluetoothPage {id:bluetoothPage;showHeading:false;width:parent.width;query:page.query}
        }

        SettingsSection {
            id:wifiGroup
            sectionId:"network.wifiGroup"
            title:"Wi-Fi"
            searchQuery:page.query
            controlIds:["networkStatus"]
            width:parent.width
            SettingsToggle {
                width:parent.width
                label:"Wi-Fi"
                objectName:"networkWifiToggle"
                checked:NetworkService.requestedWifiEnabled
                enabled:NetworkService.available && NetworkService.devices.some(function(device){return device.kind==="wifi"}) && (NetworkService.wifiHardware || NetworkService.requestedWifiEnabled)
                onToggled:function(value){if(value)NetworkService.perform("wifi-radio",{enabled:true});else page.confirmation={action:"wifi-radio",label:"Turn off Wi-Fi?"}}
            }
            Text {width:parent.width;wrapMode:Text.WordWrap;visible:!NetworkService.wifiEnabled || !NetworkService.wifiHardware;text:!NetworkService.wifiHardware ? "Wi-Fi is blocked by your hardware or no wireless adapter is available." : "Turn on Wi-Fi to find nearby networks.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            FlatButton {
                objectName:"networkFindNetworks"
                label:"Find networks"
                visible:NetworkService.wifiEnabled
                enabled:NetworkService.available && !NetworkService.operationBusy && NetworkService.devices.some(function(device){return device.kind==="wifi" && device.available})
                onActivated:{const adapter=NetworkService.devices.find(function(device){return device.kind==="wifi" && device.available});if(adapter)NetworkService.perform("scan",{device:adapter.id})}
            }
            Text {width:parent.width;visible:NetworkService.wifiEnabled && !NetworkService.networks.length;text:NetworkService.busy ? "Looking for networks…" : NetworkService.wifiScanMessage || "No nearby networks found. Refresh or move closer to your access point.";wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            KeyedModel {
                id:accessPoints
                entries:NetworkService.wifiEnabled ? NetworkService.networks.map(function(network){return Object.assign({},network,{key:network.device+"|"+network.id})}) : []
            }
            Repeater {
                id:accessPointRows
                objectName:"networkAccessPointRows"
                model:accessPoints
                delegate:SettingsRow {
                    required property var entry
                    readonly property var modelData:entry
                    width:column.width;label:modelData.name
                    Row {
                        spacing:6
                        Text {height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:modelData.signal+"% · "+(modelData.security || "Open");color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                        FlatButton {objectName:"networkAccessPointConnect";label:modelData.active ? "Connected" : "Connect";enabled:NetworkService.available && !modelData.active && modelData.supported && !NetworkService.operationBusy;onActivated:page.join(modelData)}
                    }
                }
            }
        }

        SettingsSection {
            id:savedGroup
            sectionId:"network.savedGroup"
            title:"Saved connections"
            searchQuery:page.query
            controlIds:["networkStatus"]
            defaultExpanded:false
            width:parent.width
            Repeater {
                model:NetworkService.profiles
                delegate:SettingsRow {
                    required property var modelData
                    width:column.width;label:modelData.name
                    FlatButton {label:modelData.device ? "Connected" : "Connect";enabled:NetworkService.available && !modelData.device && !NetworkService.operationBusy;onActivated:NetworkService.perform("profile-connect",{id:modelData.id})}
                }
            }
            Text {width:parent.width;wrapMode:Text.WordWrap;visible:true;text:"Enterprise Wi-Fi uses an existing saved connection profile. New connections support open and personal WPA networks.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        }
    }
    Controls.Popup {
        id:passwordDialog
        objectName:"networkPasswordDialog"
        parent:ControlTypes.Overlay.overlay
        Component.onCompleted:if(passwordDialog["popupType"]!==undefined)passwordDialog["popupType"]=Controls.Popup.Item
        x:parent ? Math.round((parent.width-width)/2) : 0
        y:parent ? Math.round((parent.height-height)/2) : 0
        width:Math.min(420,parent ? parent.width-32 : 420)
        padding:18
        modal:true;dim:false;focus:true
        closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onOpened:password.forceActiveFocus()
        onClosed:{if(page.joining)page.cancelDraft();page.restoreFocus()}
        background:Rectangle {radius:Theme.radius;color:Theme.settingsPopupSurface}
        contentItem:Column {
            spacing:10
            Text {width:parent.width;text:"Connect to Wi-Fi";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+3;font.weight:Font.Medium}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:page.joining ? page.joining.name : "";textFormat:Text.PlainText;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSize}
            Rectangle {
                width:parent.width;height:38;radius:6;color:Theme.settingsHover
                Text {anchors.fill:parent;anchors.leftMargin:10;verticalAlignment:Text.AlignVCenter;visible:!password.text;text:"Wi-Fi password";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
                TextInput {id:password;objectName:"wifiPassword";anchors.fill:parent;anchors.margins:9;echoMode:page.showPassword ? TextInput.Normal : TextInput.Password;selectByMouse:true;clip:true;maximumLength:64;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSize;Accessible.name:"Wi-Fi password";onAccepted:page.submitPassword()}
            }
            SettingsToggle {width:parent.width;label:"Show password";checked:page.showPassword;onToggled:function(next){page.showPassword=next}}
            Text {width:parent.width;wrapMode:Text.WordWrap;visible:page.credentialError!=="";text:page.credentialError;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            Row {
                spacing:8
                FlatButton {objectName:"networkPasswordCancel";label:"Cancel";onActivated:page.cancelDraft()}
                FlatButton {objectName:"networkPasswordConnect";label:"Connect";emphasized:true;enabled:!NetworkService.operationBusy && page.validPassword(password.text);onActivated:page.submitPassword()}
            }
        }
    }
    Controls.Popup {
        id:confirmationDialog
        objectName:"networkDisconnectDialog"
        parent:ControlTypes.Overlay.overlay
        Component.onCompleted:if(confirmationDialog["popupType"]!==undefined)confirmationDialog["popupType"]=Controls.Popup.Item
        x:parent ? Math.round((parent.width-width)/2) : 0
        y:parent ? Math.round((parent.height-height)/2) : 0
        width:Math.min(400,parent ? parent.width-32 : 400)
        padding:18
        modal:true;dim:false;focus:true
        closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onClosed:{page.confirmation=null;page.restoreFocus()}
        background:Rectangle {radius:Theme.radius;color:Theme.settingsPopupSurface}
        contentItem:Column {
            spacing:12
            Text {width:parent.width;wrapMode:Text.WordWrap;text:page.confirmation ? page.confirmation.label : "";textFormat:Text.PlainText;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+2}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"Active connections may be interrupted.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            Row {
                spacing:8
                FlatButton {objectName:"networkDisconnectCancel";label:"Cancel";onActivated:page.confirmation=null}
                FlatButton {
                    objectName:"networkDisconnectConfirm"
                    label:page.confirmation && page.confirmation.action==="wifi-radio" ? "Turn off Wi-Fi" : "Disconnect"
                    enabled:page.confirmation && page.confirmation.action==="wifi-radio" || !NetworkService.operationBusy
                    onActivated:{const request=page.confirmation;if(!request)return;page.confirmation=null;NetworkService.perform(request.action,request.action==="wifi-radio" ? {enabled:false} : {device:request.device})}
                }
            }
        }
    }
}
