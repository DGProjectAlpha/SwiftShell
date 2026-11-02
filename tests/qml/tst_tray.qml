import QtQuick
import QtTest
TestCase {
    id:test
    name:"NativeTrayControls"
    when:windowShown
    visible:true
    width:600;height:300
    property var module:null
    property var records:[]
    QtObject {id:windowMock;property var contentItem:test}
    function fixture(index) {
        return Qt.createQmlObject('import QtQuick; QtObject {property string id:"app'+index+'";property string title:"App '+index+'";property string icon:"";property bool onlyMenu:false;property bool hasMenu:true;property int status:1;property int activations:0;property int secondaries:0;property int menus:0;property int delta:0;property bool horizontal:false;property var menuWindow:null;property int menuX:0;property int menuY:0;function activate(){activations++}function secondaryActivate(){secondaries++}function display(window,x,y){menus++;menuWindow=window;menuX=x;menuY=y}function scroll(amount,axis){delta=amount;horizontal=axis}}',test)
    }
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        records=[]
        for(let index=0;index<7;index++)records.push(fixture(index))
        const component=Qt.createComponent("../../shell/bar/TrayModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        module=component.createObject(test,{trayModel:records,hostWindow:windowMock})
        verify(module!==null)
    }
    function cleanup() {
        module.destroy();module=null
        for(let record of records)record.destroy()
        records=[]
    }
    function item(index) {return findChild(module,"trayItems").itemAt(index)}
    function test_every_registered_item_is_visible_without_cap() {
        compare(module.itemCount,7)
        verify(module.width>7*10)
        compare(item(6).entry,records[6])
    }
    function test_real_mouse_buttons_and_menu_coordinates() {
        const target=item(0)
        mouseClick(target,target.width/2,target.height/2,Qt.LeftButton)
        compare(records[0].activations,1);compare(records[0].menus,0)
        mouseClick(target,target.width/2,target.height/2,Qt.RightButton)
        compare(records[0].menus,1);compare(records[0].activations,1)
        compare(records[0].menuWindow,windowMock)
        compare(records[0].menuX,Math.round(target.width/2))
        compare(records[0].menuY,target.height)
        mouseClick(target,target.width/2,target.height/2,Qt.MiddleButton)
        compare(records[0].secondaries,1)
    }
    function test_native_object_roles_update_without_recreating_delegate() {
        const original=item(0)
        records[0].title="A renamed application"
        records[0].status=2
        compare(item(0),original)
        compare(original.itemTitle,"A renamed application")
        compare(original.needsAttention,true)
        records[0].onlyMenu=true;records[0].hasMenu=false
        compare(original.enabled,false)
        records[0].hasMenu=true
        compare(original.enabled,true)
        compare(item(0),original)
    }
    function test_keyboard_menu_and_wheel_use_native_item_methods() {
        const target=item(0)
        target.forceActiveFocus()
        keyClick(Qt.Key_Menu)
        compare(records[0].menus,1)
        keyClick(Qt.Key_Return)
        compare(records[0].activations,1)
        mouseWheel(target,5,5,0,120)
        compare(records[0].delta,120);compare(records[0].horizontal,false)
    }
    function test_menu_only_primary_activation_and_unavailable_menu_are_honest() {
        const target=item(0)
        records[0].onlyMenu=true
        mouseClick(target,target.width/2,target.height/2,Qt.LeftButton)
        compare(records[0].menus,1);compare(records[0].activations,0)
        records[0].hasMenu=false
        compare(target.showMenu(),false)
        compare(records[0].menus,1)
    }
}
