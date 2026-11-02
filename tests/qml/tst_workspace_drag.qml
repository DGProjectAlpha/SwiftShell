import QtQuick
import QtTest
TestCase {
    id:test
    name:"WorkspaceDragOrdering"
    when:windowShown
    visible:true
    width:560;height:300
    property var list:null
    property int saves:0
    function init() {
        saves=0
        const component=Qt.createComponent("../../shell/settings/WorkspaceOrderList.qml")
        compare(component.status,Component.Ready,component.errorString())
        list=component.createObject(test,{width:500,entries:[{key:"1",name:"1"},{key:"gaming",name:"gaming"},{key:"3",name:"3"}]})
        list.reordered.connect(function(key,destination) {
            const rows=list.entries.slice();const index=rows.findIndex(function(row){return row.key===key})
            const entry=rows.splice(index,1)[0];rows.splice(destination,0,entry)
            list.entries=rows;saves++
        })
    }
    function cleanup() {list.destroy();list=null}
    function test_actual_pointer_drag_commits_once_and_keeps_named_workspace() {
        const handle=findChild(list,"workspaceDrag-1")
        verify(handle!==null)
        mousePress(handle,18,15,Qt.LeftButton)
        mouseMove(handle,18,45,20)
        mouseMove(handle,18,105,20)
        mouseMove(handle,18,120,20)
        compare(saves,0)
        mouseRelease(handle,18,120,Qt.LeftButton)
        compare(saves,1)
        compare(list.entries.map(function(row){return row.key}).join(","),"gaming,3,1")
    }
    function test_bounds_and_explicit_keyboard_move() {
        list.move("gaming",0)
        compare(list.entries[0].key,"gaming")
        compare(saves,1)
        list.move("gaming",-1);list.move("gaming",3)
        compare(saves,1)
    }
}
