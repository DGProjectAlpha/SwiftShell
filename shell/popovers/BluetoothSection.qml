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
    property var lastAttempt:null
    readonly property var pendingDevice:pending ? deviceAt(pending.key) : null
    readonly property bool canCancel:pending!==null && ["connect","pair"].indexOf(pending.action)>=0 && !pending.cancelRequested
    readonly property string progressText:pending ? (pending.cancelRequested ? "Cancelling…" : pending.action==="pair" ? "Pairing accessory. Confirm the code or PIN in your system prompt." : pending.action==="connect" ? "Connecting accessory…" : pending.action==="disconnect" ? "Disconnecting accessory…" : pending.action==="forget" ? "Removing the saved pairing…" : "Cancelling pairing…") : ""
    readonly property var adapters:BluetoothLogic.objectValues(Bluetooth.adapters)
    readonly property var adapter:adapters.find(function(item){return (item.dbusPath || item.adapterId)===root.selectedAdapter}) || Bluetooth.defaultAdapter
    readonly property bool adapterPowered:!!adapter && adapter.enabled===true
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
    function finishPending(message,failed) {
        pending=null;actionLimit.stop();notice=message || ""
        if(!failed)lastAttempt=null
    }
    function checkPending() {
        if(!pending)return
        const device=deviceAt(pending.key)
        if(!device) {
            finishPending(pending.action==="forget" ? "" : "The device is no longer available. Keep it nearby and search again.",pending.action!=="forget")
            return
        }
        const changing=device.pairing===true || device.state===3 || device.state===2
        if(changing && !pending.seenActivity)pending=Object.assign({},pending,{seenActivity:true})
        if(pending.cancelRequested) {
            if(!pending.cancelSent) {
                if(pending.action==="pair" && device.pairing===true) {
                    pending=Object.assign({},pending,{cancelSent:true});device.cancelPair()
                } else if(pending.action==="connect" && device.state===3) {
                    // BlueZ Disconnect explicitly cancels a pending Connect.
                    pending=Object.assign({},pending,{cancelSent:true});device.disconnect()
                } else if(pending.action==="pair" && (device.paired || device.bonded) || pending.action==="connect" && device.connected) {
                    finishPending("The device finished before cancellation. Its current status is shown below.",false);return
                }
            }
            if(pending && pending.cancelSent && !changing && (pending.action==="pair" ? !device.pairing : !device.connected))finishPending("Request cancelled.",false)
            return
        }
        const complete=pending.action==="forget" ? !device.paired && !device.bonded
            : pending.action==="connect" ? device.connected : pending.action==="disconnect" ? !device.connected && device.state!==2
                : pending.action==="pair" ? device.paired || device.bonded : !device.pairing
        if(complete){finishPending("",false);return}
        if(pending.seenActivity && !changing) {
            finishPending(pending.action==="pair" ? "Pairing did not finish. Put the accessory into pairing mode and confirm the system prompt before trying again." : "The device could not connect. Keep it nearby and try again.",true)
        }
    }
    function cancelPending() {
        if(!canCancel)return false
        pending=Object.assign({},pending,{cancelRequested:true,cancelSent:false})
        actionLimit.restart();checkPending();return true
    }
    function retryLast() {
        if(!lastAttempt || busy)return
        run(lastAttempt.key,lastAttempt.action)
    }
    function run(key,action) {
        if(busy && action!=="cancel")return
        const device=deviceAt(key),command=BluetoothLogic.deviceCommand(device,action)
        if(!command)return
        try {
            pending={key:key,action:command,seenActivity:device.pairing===true || device.state===3 || device.state===2,cancelRequested:false,cancelSent:false}
            lastAttempt={key:key,action:action};notice=""
            // Start the deadline before invoking an API that can change observed
            // state synchronously; success must be able to stop that deadline.
            actionLimit.restart()
            if(command==="connect")device.connect()
            else if(command==="disconnect")device.disconnect()
            else if(command==="pair")device.pair()
            else if(command==="forget")device.forget()
            else if(command==="cancel")device.cancelPair()
            Qt.callLater(checkPending)
        }catch(error){finishPending("The Bluetooth change could not be started. Try again.",true)}
    }
    Connections {
        target:root.pendingDevice
        ignoreUnknownSignals:true
        function onStateChanged(){root.checkPending()}
        function onConnectedChanged(){root.checkPending()}
        function onPairingChanged(){root.checkPending()}
        function onPairedChanged(){root.checkPending()}
        function onBondedChanged(){root.checkPending()}
    }
    onAdapterPoweredChanged: {
        if(!adapterPowered){root.stopDiscovery();if(root.pending)root.finishPending("Bluetooth was turned off before the request finished.",true)}
    }
    onRowsChanged:Qt.callLater(checkPending)
    onAdapterChanged: {stopDiscovery();pending=null;actionLimit.stop();lastAttempt=null;forgetting=null;notice=""}
    Component.onDestruction:stopDiscovery()
    Timer {id:scanLimit;interval:30000;onTriggered:root.stopDiscovery()}
    Timer {
        id:actionLimit;interval:20000
        onTriggered:{const cancelling=root.pending && root.pending.cancelRequested;root.finishPending(cancelling ? "Cancellation could not be confirmed. Check the accessory's current status before trying again." : "The device did not finish. Keep it nearby, check pairing mode and respond to any system confirmation prompt.",true)}
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
    Row {
        width:parent.width;spacing:6;visible:root.busy
        Text {width:Math.max(100,parent.width-(cancelRequest.visible ? cancelRequest.width+6 : 0));wrapMode:Text.WordWrap;text:root.progressText;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        FlatButton {id:cancelRequest;objectName:"bluetoothCancelRequest";visible:root.canCancel;label:"Cancel";onActivated:root.cancelPending()}
    }
    Repeater {
        model:root.summary.enabled ? root.rows : []
        delegate:Column {
            required property var modelData
            width:root.width;spacing:4
            Row {
                width:parent.width
                Text {width:parent.width-110;text:modelData.name;textFormat:Text.PlainText;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;elide:Text.ElideRight}
                Text {width:110;horizontalAlignment:Text.AlignRight;text:modelData.connected ? "Connected"+(modelData.battery===null ? "" : " · "+modelData.battery+"%") : modelData.pairing ? "Pairing…" : modelData.state===3 ? "Connecting…" : modelData.state===2 ? "Disconnecting…" : modelData.paired ? "Paired" : "Available";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
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
    FlatButton {visible:root.notice!=="" && root.lastAttempt!==null && !root.busy;label:"Try again";enabled:root.lastAttempt!==null && BluetoothLogic.deviceCommand(root.deviceAt(root.lastAttempt.key),root.lastAttempt.action)!=="";onActivated:root.retryLast()}
    Text {width:parent.width;wrapMode:Text.WordWrap;visible:root.summary.enabled;text:"Confirm pairing codes and PINs in your system's Bluetooth prompt. If no prompt appears, check that a system pairing agent is available.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
}
