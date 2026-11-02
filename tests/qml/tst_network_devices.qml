import QtQuick
import QtTest
import "../../shell/services" as Services
import Quickshell.Bluetooth
TestCase {
    id:test
    name:"NetworkDeviceManager"
    when:windowShown
    visible:true
    width:700;height:900
    property var page:null
    property var worker:null
    property var original:({})
    property var cancellation:null
    function init() {
        original={devices:Services.NetworkService.devices,profiles:Services.NetworkService.profiles,networks:Services.NetworkService.networks,wifiEnabled:Services.NetworkService.wifiEnabled,wifiHardware:Services.NetworkService.wifiHardware}
        const component=Qt.createComponent("../../shell/settings/NetworkPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        page=component.createObject(test,{width:600})
        worker=findChild(Services.NetworkService,"networkWorker")
        verify(worker!==null)
        worker.running=false
        cancellation=findChild(Services.NetworkService,"networkCancellation")
        verify(cancellation!==null);cancellation.running=false
        Services.NetworkService.cancelRequested=false
        Services.NetworkService.lastFailure={}
        Services.NetworkService.available=true
        Services.NetworkService.payload={}
        Services.NetworkService.devices=[{id:"eth-test",kind:"ethernet",state:"connected",connected:true,available:true,connection:"Owned fixture",addresses:["192.0.2.1/24"]}]
        Services.NetworkService.profiles=[];Services.NetworkService.networks=[]
    }
    function cleanup() {
        if(page)page.destroy()
        page=null;worker.running=false;cancellation.running=false;Services.NetworkService.payload={}
        Services.NetworkService.cancelRequested=false;Services.NetworkService.lastFailure={};Services.NetworkService.requestContext={};Services.NetworkService.notice=""
        Services.NetworkService.devices=original.devices;Services.NetworkService.networks=original.networks
        Services.NetworkService.profiles=original.profiles;Services.NetworkService.wifiEnabled=original.wifiEnabled;Services.NetworkService.wifiHardware=original.wifiHardware
        Services.NetworkService.error=""
    }
    function test_disconnect_requires_explicit_confirmation() {
        page.requestDisconnect(Services.NetworkService.devices[0])
        compare(page.confirmation.action,"device-disconnect")
        compare(Services.NetworkService.busy,false)
        compare(Object.keys(Services.NetworkService.payload).length,0)
        page.confirmation=null
        compare(Services.NetworkService.busy,false)
    }
    function test_password_is_masked_and_cleared_after_stdin_handoff() {
        Services.NetworkService.wifiEnabled=true;Services.NetworkService.wifiHardware=true
        const target={id:"AA:BB:CC:DD:EE:FF",name:"Owned fixture",security:"WPA2",device:"wlan-test"}
        page.join(target)
        const input=findChild(page,"wifiPassword")
        compare(input.echoMode,TextInput.Password)
        input.text="synthetic-password"
        page.submitPassword()
        compare(input.text,"")
        compare(page.joining,null)
        compare(Services.NetworkService.payload.secret,"synthetic-password")
        verify(worker.command.join(" ").indexOf("synthetic-password")<0)
        worker.started()
        compare(Object.keys(Services.NetworkService.payload).length,0)
    }
    function test_enter_during_refresh_preserves_password_until_request_is_accepted() {
        const target={id:"AA:BB:CC:DD:EE:FF",name:"Owned fixture",security:"WPA2",device:"wlan-test"}
        page.join(target)
        const input=findChild(page,"wifiPassword")
        input.text="synthetic-password"
        worker.running=true
        compare(page.submitPassword(),false)
        compare(input.text,"synthetic-password")
        compare(page.joining,target)
        compare(Object.keys(Services.NetworkService.payload).length,0)
        worker.running=false
        compare(page.submitPassword(),true)
        compare(input.text,"")
        compare(page.joining,null)
        compare(Services.NetworkService.payload.secret,"synthetic-password")
    }
    function test_password_enter_is_validated_before_starting_a_connection() {
        const target={id:"AA:BB:CC:DD:EE:FF",name:"Owned fixture",security:"WPA2",device:"wlan-test"}
        page.join(target)
        const input=findChild(page,"wifiPassword")
        input.text="short"
        compare(page.submitPassword(),false)
        verify(page.credentialError!=="")
        compare(Services.NetworkService.busy,false)
        input.text="a".repeat(64)
        verify(page.validPassword(input.text))
        page.showPassword=true;compare(input.echoMode,TextInput.Normal)
        page.cancelDraft();compare(input.text,"");compare(page.showPassword,false)
    }
    function test_operation_error_preserves_manager_and_has_secret_free_retry_context() {
        Services.NetworkService.perform("wifi-connect",{device:"wlan-test",id:"AA:BB:CC:DD:EE:FF",secret:"synthetic-password"})
        verify(Services.NetworkService.canCancel)
        verify(Services.NetworkService.progressText.indexOf("Connecting")>=0)
        verify(JSON.stringify(Services.NetworkService.requestContext).indexOf("synthetic-password")<0)
        worker.started()
        const reply=findChild(Services.NetworkService,"networkReply")
        reply.text=JSON.stringify({ok:false,code:"activation-failed",message:"Connection failed"})
        worker.running=false;worker.exited(0,0)
        compare(Services.NetworkService.available,true)
        compare(Services.NetworkService.error,"Connection failed")
        compare(Services.NetworkService.lastFailure.action,"wifi-connect")
        verify(JSON.stringify(Services.NetworkService.lastFailure).indexOf("synthetic-password")<0)
        Services.NetworkService.refresh()
        reply.text=JSON.stringify({ok:true,available:true,devices:[],networks:[],profiles:[]})
        worker.running=false;worker.exited(0,0)
        compare(Services.NetworkService.error,"Connection failed")
    }
    function test_cancellation_uses_separate_targeted_request_and_clears_handoff() {
        Services.NetworkService.perform("wifi-connect",{device:"wlan-test",id:"AA:BB:CC:DD:EE:FF",secret:"synthetic-password"})
        worker.started()
        verify(Services.NetworkService.cancel())
        compare(Services.NetworkService.cancelPayload.action,"cancel-connect")
        compare(Services.NetworkService.cancelPayload.device,"wlan-test")
        verify(JSON.stringify(Services.NetworkService.cancelPayload).indexOf("synthetic-password")<0)
        cancellation.started()
        compare(Object.keys(Services.NetworkService.cancelPayload).length,0)
        compare(Services.NetworkService.canCancel,false)
        const reply=findChild(Services.NetworkService,"networkCancelReply")
        reply.text=JSON.stringify({ok:true,available:true,cancelled:true,message:"Connection cancelled.",devices:[],networks:[],profiles:[]})
        cancellation.running=false;cancellation.exited(0,0)
        const failed=findChild(Services.NetworkService,"networkReply")
        failed.text=JSON.stringify({ok:false,message:"Activation interrupted"})
        worker.running=false;worker.exited(0,0)
        compare(Services.NetworkService.busy,false)
        compare(Services.NetworkService.error,"")
        compare(Services.NetworkService.notice,"Connection cancelled.")
        compare(Services.NetworkService.available,true)
    }
    function bluetoothFixture(count) {
        const devices=[]
        for(let index=0;index<count;index++)devices.push(Qt.createQmlObject('import QtQuick;QtObject {property string name:"Fixture '+index+'";property string dbusPath:"/owned/device'+index+'";property bool connected:false;property bool paired:false;property bool bonded:false;property bool pairing:false;property int state:0;property int pairCalls:0;property int cancelCalls:0;property int connectCalls:0;property int disconnectCalls:0;function pair(){pairCalls++;pairing=true}function cancelPair(){cancelCalls++;pairing=false;state=0}function connect(){connectCalls++;state=3}function disconnect(){disconnectCalls++;connected=false;state=0}function forget(){paired=false;bonded=false}}',test))
        const adapter=Qt.createQmlObject('import QtQuick;QtObject {property string name:"Owned adapter";property string adapterId:"owned";property string dbusPath:"/owned/adapter";property bool enabled:true;property bool discovering:false;property QtObject devices:QtObject{property var values:[]}}',test)
        adapter.devices.values=devices
        Bluetooth.defaultAdapter=adapter;Bluetooth.adapters.values=[adapter]
        const component=Qt.createComponent("../../shell/popovers/BluetoothSection.qml")
        compare(component.status,Component.Ready,component.errorString())
        return {section:component.createObject(test,{width:500}),adapter:adapter,devices:devices}
    }
    function destroyBluetoothFixture(fixture) {
        fixture.section.destroy();wait(0)
        Bluetooth.defaultAdapter=null;Bluetooth.adapters.values=[]
        for(let device of fixture.devices)device.destroy()
        fixture.adapter.destroy()
    }
    function test_bluetooth_pairing_progress_cancellation_and_failure_are_observed() {
        const fixture=bluetoothFixture(1),section=fixture.section,device=fixture.devices[0]
        section.run(device.dbusPath,"pair");section.checkPending()
        verify(section.busy);verify(section.progressText.indexOf("system prompt")>=0)
        verify(section.cancelPending())
        tryCompare(section,"busy",false)
        compare(device.cancelCalls,1)
        compare(section.notice,"Request cancelled.")
        section.run(device.dbusPath,"pair");section.checkPending()
        device.pairing=false
        tryCompare(section,"busy",false)
        verify(section.notice.indexOf("Pairing did not finish")>=0)
        verify(section.lastAttempt!==null)
        section.retryLast();compare(device.pairCalls,3)
        section.checkPending();device.paired=true;device.pairing=false
        tryCompare(section,"busy",false)
        compare(section.lastAttempt,null)
        destroyBluetoothFixture(fixture)
    }
    function test_bluetooth_pending_connection_can_cancel_and_all_devices_remain_available() {
        const fixture=bluetoothFixture(24),section=fixture.section,device=fixture.devices[23]
        compare(section.rows.length,24)
        section.run(device.dbusPath,"connect");section.checkPending()
        verify(section.busy);verify(section.cancelPending())
        tryCompare(section,"busy",false)
        compare(device.disconnectCalls,1)
        compare(device.connected,false)
        compare(section.notice,"Request cancelled.")
        destroyBluetoothFixture(fixture)
    }
    function test_bluetooth_discovery_is_owned_and_stops_on_close() {
        const adapter=Qt.createQmlObject('import QtQuick;QtObject {property string name:"Test adapter";property string adapterId:"test";property string dbusPath:"/owned/test";property bool enabled:true;property bool discovering:false;property QtObject devices:QtObject{property var values:[]}}',test)
        Bluetooth.defaultAdapter=adapter;Bluetooth.adapters.values=[adapter]
        const component=Qt.createComponent("../../shell/popovers/BluetoothSection.qml")
        compare(component.status,Component.Ready,component.errorString())
        const section=component.createObject(test,{width:320})
        section.scan();compare(adapter.discovering,true)
        compare(section.discoveryOwner,adapter)
        section.destroy();wait(0)
        compare(adapter.discovering,false)
        Bluetooth.defaultAdapter=null;Bluetooth.adapters.values=[];adapter.destroy()
    }
}
