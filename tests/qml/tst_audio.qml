import QtQuick
import QtTest
import Quickshell.Services.Pipewire
import "../../shell/services" as Services
import "../../shell/popovers" as Popovers
TestCase {
    id:test
    name:"SharedAudioControls"
    when:windowShown
    visible:true;width:620;height:720
    property var saved:null
    property var output:null
    property var alternate:null
    property var microphone:null
    property var application:null
    property var section:null
    Component {
        id:nodeComponent
        QtObject {
            property string id:"owned-output"
            property bool ready:true
            property bool isSink:true
            property bool isStream:false
            property string description:"Owned test device"
            property string nickname:""
            property string name:"owned-test-node"
            property var properties:({})
            property QtObject audio:QtObject {property real volume:.4;property bool muted:false}
        }
    }
    Component {id:sectionComponent;Popovers.AudioSection {width:360}}
    Component {
        id:scrollingComponent
        Flickable {
            width:360;height:170;contentWidth:width;contentHeight:body.height;clip:true
            boundsBehavior:Flickable.StopAtBounds
            Column {
                id:body;width:parent.width
                Popovers.AudioSection {objectName:"audioInsideScroll";width:parent.width;showInput:false;showApplications:false;heading:""}
                Item {width:1;height:600}
            }
        }
    }
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved={nodes:Pipewire.nodes.values,sink:Pipewire.defaultAudioSink,source:Pipewire.defaultAudioSource,ready:Pipewire.ready,preferredSink:Pipewire.preferredDefaultAudioSink,preferredSource:Pipewire.preferredDefaultAudioSource}
        output=nodeComponent.createObject(test)
        alternate=nodeComponent.createObject(test,{id:"owned-alternate"})
        microphone=nodeComponent.createObject(test,{id:"owned-microphone",isSink:false})
        application=nodeComponent.createObject(test,{id:"owned-app",isSink:false,isStream:true})
        Pipewire.ready=true;Pipewire.nodes.values=[output,alternate,microphone,application];Pipewire.defaultAudioSink=output;Pipewire.defaultAudioSource=microphone
        Services.AudioService.error=""
        section=sectionComponent.createObject(test)
        verify(section!==null);waitForRendering(section)
    }
    function cleanup() {
        section.destroy();section=null
        Pipewire.nodes.values=saved.nodes;Pipewire.defaultAudioSink=saved.sink;Pipewire.defaultAudioSource=saved.source;Pipewire.ready=saved.ready
        Pipewire.preferredDefaultAudioSink=saved.preferredSink;Pipewire.preferredDefaultAudioSource=saved.preferredSource
        output.destroy();alternate.destroy();microphone.destroy();application.destroy()
    }
    function test_output_input_and_application_reach_same_adapter() {
        verify(Services.AudioService.setVolume(output.id,.7));compare(output.audio.volume,.7)
        verify(Services.AudioService.setVolume(microphone.id,.3));compare(microphone.audio.volume,.3)
        verify(Services.AudioService.setVolume(application.id,.6));compare(application.audio.volume,.6)
        mouseClick(findChild(section,"audioOutputMute"));compare(output.audio.muted,true)
        mouseClick(findChild(section,"audioInputMute"));compare(microphone.audio.muted,true)
        verify(Services.AudioService.setVolume(microphone.id,.2));compare(microphone.audio.muted,false)
    }
    function test_not_ready_or_removed_nodes_cannot_be_changed() {
        output.ready=false
        verify(!Services.AudioService.outputReady)
        verify(!findChild(section,"audioOutputVolume").enabled)
        verify(!Services.AudioService.setVolume(output.id,.9));compare(output.audio.volume,.4)
        output.ready=true
        Pipewire.nodes.values=[output,microphone]
        verify(!Services.AudioService.setVolume(application.id,.9));compare(application.audio.volume,.4)
    }
    function test_default_change_during_gesture_cannot_change_old_device() {
        const id=Services.AudioService.idFor("sink")
        Pipewire.defaultAudioSink=alternate
        verify(!Services.AudioService.setDefaultVolume("sink",id,.8))
        compare(output.audio.volume,.4);compare(alternate.audio.volume,.4)
    }
    function test_choose_output_and_input_validate_type_and_streams() {
        verify(Services.AudioService.chooseDefault(alternate.id,"sink"))
        compare(Pipewire.preferredDefaultAudioSink,alternate)
        verify(!Services.AudioService.chooseDefault(application.id,"sink"))
        verify(!Services.AudioService.chooseDefault(output.id,"source"))
    }
    function test_application_updates_keep_slider_instance_during_drag() {
        const slider=findChild(section,"audioApplicationVolume-owned-app")
        verify(slider!==null)
        mousePress(slider,slider.width*.2,slider.height/2)
        application.audio.volume=.6
        compare(findChild(section,"audioApplicationVolume-owned-app"),slider)
        mouseMove(slider,slider.width*.7,slider.height/2)
        mouseRelease(slider,slider.width*.7,slider.height/2)
        verify(Math.abs(application.audio.volume-.7)<.02)
    }
    function test_slider_drag_inside_scroll_reaches_backend_without_scrolling() {
        section.destroy();section=scrollingComponent.createObject(test)
        waitForRendering(section)
        const slider=findChild(section,"audioOutputVolume")
        mousePress(slider,slider.width*.2,slider.height/2)
        mouseMove(slider,slider.width*.5,slider.height/2+12,80)
        mouseMove(slider,slider.width*.8,slider.height/2,80)
        mouseRelease(slider,slider.width*.8,slider.height/2)
        verify(Math.abs(output.audio.volume-.8)<.02)
        compare(section.contentY,0)
    }
}
