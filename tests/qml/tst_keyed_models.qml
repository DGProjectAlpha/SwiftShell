import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    name:"StableBarModels"
    when:windowShown
    function test_workspace_controls_survive_snapshot_role_updates() {
        const component=Qt.createComponent("../../shell/bar/WorkspaceIndicators.qml")
        compare(component.status,Component.Ready,component.errorString())
        const rows=[{key:"1",id:1,name:"1",active:true,urgent:false},{key:"gaming",id:-1,name:"gaming",active:false,urgent:false}]
        const indicators=component.createObject(this,{workspaces:rows})
        const repeater=findChild(indicators,"workspaceRepeater")
        compare(repeater.count,2)
        const first=repeater.itemAt(0),gaming=repeater.itemAt(1)
        for(let i=0;i<20;i++) indicators.workspaces=rows.map(function(r){return Object.assign({},r,{urgent:i%2===0,active:r.key===(i%2===0 ? "gaming" : "1")})})
        compare(repeater.itemAt(0),first);compare(repeater.itemAt(1),gaming)
        compare(first.modelData.active,true);compare(gaming.modelData.active,false);compare(first.modelData.urgent,false)
        indicators.workspaces=[rows[1],{key:"2",id:2,name:"2",active:false,urgent:false},rows[0]]
        compare(repeater.itemAt(0),gaming);compare(repeater.itemAt(2),first)
        compare(repeater.count,3)
        indicators.destroy()
    }
    function test_module_settings_are_scoped_and_resettable() {
        const saved=Services.SettingsStore.snapshot()
        verify(Services.SettingsStore.setModuleSide("clock","center"))
        compare(JSON.parse(Services.SettingsStore.moduleSidesJson).clock,"center")
        verify(!Services.SettingsStore.setModuleSide("clock","bottom"))
        verify(Services.SettingsStore.setHiddenForOutput("DP-1",["clock"]))
        compare(Services.SettingsStore.hiddenForOutput("DP-1")[0],"clock")
        verify(Services.SettingsStore.hiddenForOutput("HDMI-A-1").indexOf("clock")<0)
        Services.SettingsStore.inheritHidden("DP-1")
        verify(!Object.prototype.hasOwnProperty.call(JSON.parse(Services.SettingsStore.hiddenOutputsJson),"DP-1"))
        Services.SettingsStore.resetModuleSides()
        compare(Services.SettingsStore.moduleSidesJson,"{}")
        Services.SettingsStore.applyDocument(saved)
    }
    function test_tall_popover_scrolls_inside_rounded_surface() {
        const component=Qt.createComponent("../../shell/popovers/PopoverSurface.qml")
        const surface=component.createObject(this,{maximumHeight:400})
        const body=findChild(surface,"popoverBody")
        Qt.createQmlObject('import QtQuick; Rectangle {width:240;height:1000}',body)
        tryVerify(function(){return surface.implicitHeight<=400})
        const scroll=findChild(surface,"popoverScroll")
        tryVerify(function(){return scroll.contentHeight>scroll.height})
        surface.scrollBy(150)
        compare(scroll.contentY,150)
        surface.destroy()
    }
    function test_module_reorder_preserves_existing_rows() {
        const component=Qt.createComponent("../../shell/components/KeyedModel.qml")
        const model=component.createObject(this,{entries:["workspaces","title","search","clock"]})
        model.entries=["clock","workspaces","search"]
        compare(model.count,3);compare(model.get(0).entry,"clock");compare(model.get(2).entry,"search")
        model.entries=["clock","workspaces","search","control"]
        compare(model.count,4);compare(model.get(3).identity,"control")
        model.destroy()
    }
}
