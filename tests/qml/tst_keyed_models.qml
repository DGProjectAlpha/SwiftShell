import QtQuick
import QtTest
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
