import QtQuick
import Quickshell.Bluetooth
import "../components"
import "../logic/bluetooth.js" as BluetoothLogic
import "../themes"
Column {
    id:root
    spacing:Theme.settingsSpacing
    width:parent ? parent.width : Theme.controlWidth
    property string notice:""
    property string selectedAdapter:""
    property var discoveryOwner:null
    property var pending:null
    property var forgetting:null
    readonly property var adapters:BluetoothLogic.objectValues(Bluetooth.adapters)
    readonly property var adapter:adapters.find(function(item){return (item.dbusPath || item.adapterId)===root.selectedAdapter}) || Bluetooth.defaultAdapter
    readonly property var summary:BluetoothLogic.adapterSummary(adapter)
    readonly property var deviceModel:adapter && adapter.devices ? adapter.devices : Bluetooth.devices
    readonly property var rows:BluetoothLogic.deviceRows(deviceModel).sort(function(a,b){return Number(b.connected)-Number(a.connected) || Number(b.paired)-Number(a.paired) || a.name.localeCompare(b.name)})
    readonly property bool busy:pending!==null
    function deviceAt(key) {
        const values=BluetoothLogic.objectValues(deviceModel)
        return values.find(function(device,index){return BluetoothLogic.deviceKey(device,index)===key}) || null
    }
    function stopDiscovery() {
        if(discoveryOwner) {try{discoveryOwner.discovering=false}catch(error){};discoveryOwner=null}
        if(scanLimit)scanLimit.stop()
    }
    function scan() {
        if(!adapter || !adapter.enabled)return
        if(discoveryOwner || adapter.discovering) {stopDiscovery();return}
        try {adapter.discovering=true;discoveryOwner=adapter;scanLimit.restart();notice=""}
        catch(error){notice="Nearby devices could not be searched. Check your adapter and try again."}
    }
    function checkPending() {
        if(!pending)return
        const device=deviceAt(pending.key)
        const complete=pending.action==="forget" ? !device || !device.paired && !device.bonded
            : device && (pending.action==="connect" ? device.connected : pending.action==="disconnect" ? !device.connected
                : pending.action==="pair" ? device.paired || device.bonded : !device.pairing)
        if(complete) {pending=null;actionLimit.stop();notice=""}
    }
    function run(key,action) {
        if(busy && action!=="cancel")return
        const device=deviceAt(key),command=BluetoothLogic.deviceCommand(device,action)
        if(!command)return
        try {
            pending={key:key,action:command};notice=""
            if(command==="connect")device.connect()
            else if(command==="disconnect")device.disconnect()
            else if(command==="pair")device.pair()
            else if(command==="forget")device.forget()
            else if(command==="cancel")device.cancelPair()
            actionLimit.restart();Qt.callLater(checkPending)
        }catch(error){pending=null;notice="The Bluetooth change could not be started. Try again."}
    }
    onRowsChanged:Qt.callLater(checkPending)
    onAdapterChanged: {stopDiscovery();pending=null;forgetting=null;notice=""}
    Component.onDestruction:stopDiscovery()
    Timer {id:scanLimit;interval:30000;onTriggered:root.stopDiscovery()}
    Timer {
        id:actionLimit;interval:20000
        onTriggered:{root.pending=null;root.notice="The device did not finish connecting or pairing. Keep it nearby and check its pairing mode or system confirmation prompt."}
    }
    SectionHeader {width:parent.width;text:"Bluetooth"}
    ChoiceBox {
        visible:root.adapters.length>1
        width:Math.min(360,parent.width)
        choices:root.adapters.map(function(adapter){return {label:adapter.name || adapter.adapterId,value:adapter.dbusPath || adapter.adapterId}})
        selectedValue:root.adapter ? (root.adapter.dbusPath || root.adapter.adapterId) : ""
        Accessible.name:"Bluetooth adapter"
        onChosen:function(value){root.stopDiscovery();root.selectedAdapter=value}
    }
    SettingsToggle {
        width:parent.width
        label:root.summary.name || "Bluetooth"
        enabled:root.summary.present
        checked:root.summary.enabled
        onToggled:function(value) {
            if(!root.adapter)return
            try {if(!value)root.stopDiscovery();root.adapter.enabled=value;root.notice=""}
            catch(error){root.notice="The Bluetooth adapter could not be changed."}
        }
    }
    Text {
        width:parent.width;wrapMode:Text.WordWrap
        visible:!root.summary.present || !root.summary.enabled
        text:!root.summary.present ? "No Bluetooth adapter is available." : "Turn on Bluetooth to connect accessories."
        color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
    }
    Row {
        spacing:8;visible:root.summary.present && root.summary.enabled
        FlatButton {objectName:"bluetoothDiscovery";label:root.discoveryOwner ? "Stop searching" : "Find devices";enabled:!root.busy && root.adapter!==null && (!root.adapter.discovering || root.discoveryOwner!==null);onActivated:root.scan()}
        Text {height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:root.adapter && root.adapter.discovering ? "Searching nearby…" : root.rows.length+" devices";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
    }
    Text {
        width:parent.width;wrapMode:Text.WordWrap;visible:root.summary.enabled && !root.rows.length
        text:"Put your accessory into pairing mode, then choose Find devices."
        color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
    }
    Repeater {
        model:root.summary.enabled ? root.rows : []
        delegate:Column {
            required property var modelData
            width:root.width;spacing:4
            Row {
                width:parent.width
                Text {width:parent.width-110;text:modelData.name;textFormat:Text.PlainText;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;elide:Text.ElideRight}
                Text {width:110;horizontalAlignment:Text.AlignRight;text:modelData.connected ? "Connected"+(modelData.battery===null ? "" : " · "+modelData.battery+"%") : modelData.pairing ? "Pairing…" : modelData.paired ? "Paired" : "Available";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            }
            Flow {
                width:parent.width;spacing:4
                FlatButton {visible:modelData.paired && !modelData.connected;label:"Connect";enabled:!root.busy;onActivated:root.run(modelData.key,"connect")}
                FlatButton {visible:modelData.connected;label:"Disconnect";enabled:!root.busy;onActivated:root.run(modelData.key,"disconnect")}
                FlatButton {visible:!modelData.paired && !modelData.pairing;label:"Pair";enabled:!root.busy;onActivated:root.run(modelData.key,"pair")}
                FlatButton {visible:modelData.pairing;label:"Cancel pairing";onActivated:root.run(modelData.key,"cancel")}
                FlatButton {visible:modelData.paired;label:"Forget…";enabled:!root.busy;onActivated:root.forgetting=modelData}
            }
        }
    }
    Column {
        width:parent.width;spacing:4;visible:root.forgetting!==null
        Text {width:parent.width;wrapMode:Text.WordWrap;text:root.forgetting ? "Forget "+root.forgetting.name+"? You will need to pair it again." : "";textFormat:Text.PlainText;color:Theme.settingsText;font.pixelSize:Theme.settingsFontSizeSmall}
        Row {
            spacing:6
            FlatButton {label:"Cancel";onActivated:root.forgetting=null}
            FlatButton {label:"Forget device";onActivated:{const key=root.forgetting.key;root.forgetting=null;root.run(key,"forget")}}
        }
    }
    Text {visible:root.notice!=="";width:parent.width;wrapMode:Text.WordWrap;text:root.notice;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    Text {width:parent.width;wrapMode:Text.WordWrap;visible:root.summary.enabled;text:"Accessories that require a PIN use your system's pairing confirmation prompt.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
}
