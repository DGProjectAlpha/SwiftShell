import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    id:test
    name:"SystemPowerProfiles"
    when:windowShown
    visible:true
    width:700;height:700
    property var page:null
    property var saved:({})
    property var bridge:null
    function init() {
        const service=Services.PowerProfiles
        saved={available:service.available,active:service.active,profiles:service.profiles,previous:service.previousProfile,error:service.error}
        bridge=findChild(service,"powerProfileBridge")
        verify(bridge!==null)
        bridge.running=false
        service.available=true;service.active="balanced";service.error=""
        service.profiles=[{id:"power-saver",label:"Power Saver",description:"Save energy",enabled:true},
            {id:"balanced",label:"Balanced",description:"Balanced operation",enabled:true},
            {id:"performance",label:"Performance",description:"Maximum responsiveness",enabled:false}]
        const component=Qt.createComponent("../../shell/settings/PowerPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        page=component.createObject(test,{width:600})
        verify(page!==null)
        bridge.running=false
    }
    function cleanup() {
        page.destroy();page=null
        bridge.running=false
        const service=Services.PowerProfiles
        service.available=saved.available;service.active=saved.active;service.profiles=saved.profiles
        service.previousProfile=saved.previous;service.error=saved.error
    }
    function test_only_advertised_profiles_are_actionable() {
        verify(findChild(page,"powerProfile-balanced")!==null)
        compare(findChild(page,"powerProfile-performance").enabled,false)
        const saver=findChild(page,"powerProfile-power-saver")
        verify(saver.enabled)
        mouseClick(saver,saver.width/2,saver.height/2,Qt.LeftButton)
        compare(Services.PowerProfiles.active,"balanced") // Readback, not an optimistic fake.
        compare(bridge.command[0],"python3")
        compare(bridge.command[bridge.command.length-2],"set")
        compare(bridge.command[bridge.command.length-1],"power-saver")
    }
    function test_keyboard_selection_and_disabled_profile_rejection() {
        const saver=findChild(page,"powerProfile-power-saver")
        saver.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(bridge.command[bridge.command.length-1],"power-saver")
        bridge.running=false
        compare(Services.PowerProfiles.choose("performance"),false)
        compare(Services.PowerProfiles.choose("unknown"),false)
    }
    function test_actual_selected_profile_and_geometry_are_exposed() {
        const geometry=page.geometry()
        compare(geometry.active,"balanced")
        compare(geometry.profiles.length,3)
        verify(geometry.profiles[0].height>=64)
        compare(geometry.profiles[2].enabled,false)
        compare(Services.PowerProfiles.reason("high-operating-temperature"),"Performance is limited while the computer cools down.")
    }
}
