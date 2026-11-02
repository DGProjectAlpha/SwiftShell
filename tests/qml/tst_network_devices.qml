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
    function init() {
        original={devices:Services.NetworkService.devices,profiles:Services.NetworkService.profiles,networks:Services.NetworkService.networks,wifiEnabled:Services.NetworkService.wifiEnabled,wifiHardware:Services.NetworkService.wifiHardware}
        const component=Qt.createComponent("../../shell/settings/NetworkPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        page=component.createObject(test,{width:600})
        worker=findChild(Services.NetworkService,"networkWorker")
        verify(worker!==null)
        worker.running=false
        Services.NetworkService.available=true
        Services.NetworkService.payload={}
        Services.NetworkService.devices=[{id:"eth-test",kind:"ethernet",state:"connected",connected:true,available:true,connection:"Owned fixture",addresses:["192.0.2.1/24"]}]
        Services.NetworkService.profiles=[];Services.NetworkService.networks=[]
    }
    function cleanup() {
        if(page)page.destroy()
        page=null;worker.running=false;Services.NetworkService.payload={}
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
