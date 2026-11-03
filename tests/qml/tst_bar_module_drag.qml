import QtQuick
import QtTest
import "../../shell/settings" as SettingsUI
import "../../shell/services" as Services
TestCase {
    id:test
    name:"BarModuleDragOrdering"
    when:windowShown
    visible:true;width:800;height:1100
    property var list:null
    property var container:null
    property int saves:0
    property var saved:null
    property var contextMenu:null
    property var savedMonitors:null
    property var savedChoices:null
    SignalSpy {id:visibilitySpy;target:list;signalName:"visibilityToggled"}
    SignalSpy {id:sideSpy;target:list;signalName:"sideChosen"}
    Component {id:orderComponent;SettingsUI.BarModuleOrderList {width:500;entries:["clock","search","screenshot"]}}
    Component {id:scrollComponent;Flickable {width:500;height:110;clip:true;contentHeight:order.implicitHeight;property alias order:order;SettingsUI.BarModuleOrderList {id:order;width:500;entries:["clock","search","screenshot","clipboard","performance","network","power","tray"]}}}
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved=Services.SettingsStore.snapshot()
        savedMonitors=Services.HyprlandModel.monitorSnapshot
        savedChoices=Services.HyprlandModel.monitorChoices
        saves=0;visibilitySpy.clear();sideSpy.clear()
        list=orderComponent.createObject(test)
        list.reordered.connect(commit)
    }
    function commit(id,destination) {
        const entries=list.entries.slice(),index=entries.indexOf(id)
        entries.splice(index,1);entries.splice(destination,0,id)
        list.entries=entries;saves++
    }
    function cleanup(){if(contextMenu){contextMenu.destroy();contextMenu=null}if(container){container.destroy();container=null}else if(list)list.destroy();list=null;Services.SettingsStore.applyDocument(saved);Services.HyprlandModel.monitorSnapshot=savedMonitors;Services.HyprlandModel.monitorChoices=savedChoices}
    function prepareVisibilityPage() {
        list.destroy();list=null
        Services.HyprlandModel.monitorSnapshot=[{name:"DP-1",focused:true},{name:"HDMI-A-1",focused:false}]
        Services.HyprlandModel.monitorChoices=[{name:"DP-1",label:"Main · DP-1"},{name:"HDMI-A-1",label:"Second · HDMI-A-1"}]
        Services.SettingsStore.setHiddenModules(["search"])
        Services.SettingsStore.setHiddenForOutput("DP-1",[])
        Services.SettingsStore.setHiddenForOutput("HDMI-A-1",["battery"])
        const component=Qt.createComponent("../../shell/settings/BarPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        container=component.createObject(test,{width:500,query:"module order"})
        list=findChild(container,"barModuleOrderList")
    }
    function test_visibility_defaults_to_current_display_once() {
        prepareVisibilityPage()
        compare(container.modulesOutput,"DP-1")
        Services.HyprlandModel.monitorSnapshot=[{name:"DP-1",focused:false},{name:"HDMI-A-1",focused:true}]
        compare(container.modulesOutput,"DP-1")
        const button=findChild(list,"barModuleVisibility-search")
        compare(button.label,"Hide")
        mouseClick(button)
        compare(Services.SettingsStore.hiddenForOutput("DP-1").indexOf("search")>=0,true)
        compare(Services.SettingsStore.hiddenForOutput("HDMI-A-1").join(","),"battery")
        compare(button.label,"Show")
        mouseClick(button)
        compare(Services.SettingsStore.hiddenForOutput("DP-1").indexOf("search"),-1)
        compare(button.label,"Hide")
    }
    function test_settings_and_context_visibility_share_state_both_directions() {
        prepareVisibilityPage();container.modulesOutput="DP-1"
        const menuComponent=Qt.createComponent("../../shell/bar/BarContextMenu.qml")
        compare(menuComponent.status,Component.Ready,menuComponent.errorString())
        contextMenu=menuComponent.createObject(test,{outputName:"DP-1",x:530})
        const button=findChild(list,"barModuleVisibility-search")
        const toggle=findChild(contextMenu,"barContextVisibility-search")
        verify(toggle!==null)
        compare(button.label,"Hide");verify(toggle.checked)
        mouseClick(button)
        compare(button.label,"Show");verify(!toggle.checked)
        mouseClick(toggle)
        compare(button.label,"Hide");verify(toggle.checked)
        compare(Services.SettingsStore.hiddenForOutput("HDMI-A-1").join(","),"battery")
    }
    function test_late_monitor_discovery_and_explicit_default_selection() {
        list.destroy();list=null
        Services.HyprlandModel.monitorSnapshot=[];Services.HyprlandModel.monitorChoices=[]
        const component=Qt.createComponent("../../shell/settings/BarPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        container=component.createObject(test,{width:500,query:"module order"})
        list=findChild(container,"barModuleOrderList")
        compare(container.modulesOutput,"");verify(!container.outputInitialized)
        Services.HyprlandModel.monitorSnapshot=[{name:"DP-1",focused:true}]
        Services.HyprlandModel.monitorChoices=[{name:"DP-1",label:"Main · DP-1"}]
        compare(container.modulesOutput,"DP-1");verify(container.outputInitialized)
        findChild(container,"barModulesOutput").chosen("")
        Services.HyprlandModel.monitorChoices=[{name:"DP-1",label:"Changed · DP-1"}]
        compare(container.modulesOutput,"")
        const button=findChild(list,"barModuleVisibility-search")
        const before=Services.SettingsStore.hiddenForOutput("").indexOf("search")>=0
        mouseClick(button)
        compare(Services.SettingsStore.hiddenForOutput("").indexOf("search")>=0,!before)
    }
    function test_full_page_drop_preserves_other_output_and_grouping() {
        list.destroy();list=null
        const component=Qt.createComponent("../../shell/settings/BarPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        container=component.createObject(test,{width:500,query:"module order",modulesOutput:"DP-1"})
        list=findChild(container,"barModuleOrderList")
        const initial=Services.SettingsStore.layoutForOutput("DP-1"),other=JSON.stringify(Services.SettingsStore.layoutForOutput("HDMI-A-1"))
        const first=list.entries[0],handle=findChild(list,"barModuleDrag-"+first)
        mousePress(handle,18,18,Qt.LeftButton);mouseMove(handle,18,50,20);mouseMove(handle,18,105,20)
        mouseRelease(handle,18,105,Qt.LeftButton)
        const result=Services.SettingsStore.layoutForOutput("DP-1")
        compare(result.order[2],first);compare(result.edge,initial.edge);compare(result.scale,initial.scale);compare(result.sides,initial.sides)
        compare(JSON.stringify(Services.SettingsStore.layoutForOutput("HDMI-A-1")),other)
    }
    function test_pointer_drop_commits_once_and_retains_controls() {
        const handle=findChild(list,"barModuleDrag-clock")
        mousePress(handle,18,18,Qt.LeftButton)
        mouseMove(handle,18,50,20);mouseMove(handle,18,105,20)
        compare(saves,0)
        mouseRelease(handle,18,105,Qt.LeftButton)
        compare(saves,1)
        compare(list.entries.join(","),"search,screenshot,clock")
        compare(findChild(list,"barModuleDrag-clock"),handle)
    }
    function test_escape_cancels_even_if_pointer_moves_afterwards() {
        const handle=findChild(list,"barModuleDrag-clock")
        mousePress(handle,18,18,Qt.LeftButton)
        mouseMove(handle,18,100,20)
        handle.forceActiveFocus();keyClick(Qt.Key_Escape)
        mouseMove(handle,18,120,20)
        mouseRelease(handle,18,120,Qt.LeftButton)
        compare(saves,0);compare(list.entries[0],"clock");compare(list.dropIndex,-1)
    }
    function test_keyboard_and_visibility_do_not_conflict() {
        const handle=findChild(list,"barModuleDrag-clock")
        handle.forceActiveFocus();keyClick(Qt.Key_J,Qt.AltModifier)
        compare(list.entries.join(","),"search,clock,screenshot");compare(saves,1)
        mouseClick(findChild(list,"barModuleVisibility-clock"))
        compare(visibilitySpy.count,1);compare(saves,1)
        findChild(list,"barModuleSide-clock").chosen("center")
        compare(sideSpy.count,1);compare(sideSpy.signalArguments[0][1],"center");compare(saves,1)
    }
    function test_drag_scrolls_only_while_held_and_commits_at_drop() {
        list.destroy();container=scrollComponent.createObject(test);list=container.order
        list.reordered.connect(commit)
        const handle=findChild(list,"barModuleDrag-clock")
        mousePress(handle,18,18,Qt.LeftButton)
        mouseMove(handle,18,60,20);mouseMove(handle,18,100,20)
        tryVerify(function(){return container.contentY>0})
        compare(saves,0)
        mouseRelease(handle,18,18,Qt.LeftButton)
        verify(saves<=1)
        const y=container.contentY;wait(100);compare(container.contentY,y)
    }
}
