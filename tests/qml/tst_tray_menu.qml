import QtQuick
import QtTest
import "../../shell/themes" as Themes
TestCase {
    id:test
    name:"ThemedNativeTrayMenus"
    when:windowShown
    visible:true
    width:600;height:650
    property var content:null
    property var rows:[]
    property int activations:0
    property int backs:0
    function entry(label,properties) {
        const item=Qt.createQmlObject('import QtQuick;QtObject {property string text:"";property string icon:"";property bool enabled:true;property bool isSeparator:false;property bool hasChildren:false;property int buttonType:0;property int checkState:0;property var children:[];property int calls:0;signal triggered();onTriggered:calls++}',test)
        item.text=label
        for(const key in properties)item[key]=properties[key]
        return item
    }
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        activations=0;backs=0
        rows=[entry('&Open',{buttonType:0}),entry('Disabled',{enabled:false}),entry('',{isSeparator:true}),entry('Checked',{buttonType:1,checkState:Qt.Checked}),entry('Radio',{buttonType:2,checkState:Qt.Checked}),entry('Submenu',{hasChildren:true})]
        const component=Qt.createComponent('../../shell/components/TrayMenuContent.qml')
        compare(component.status,Component.Ready,component.errorString())
        content=component.createObject(test,{width:300,entries:rows,heading:'Owned fixture'})
        content.activated.connect(function(item){activations++;item.triggered()})
        content.backRequested.connect(function(){backs++})
        wait(0)
    }
    function cleanup() {
        content.destroy();content=null
        for(let index=0;index<rows.length;index++)rows[index].destroy()
        rows=[]
    }
    function test_native_states_and_disabled_action_are_preserved() {
        const items=findChild(content,'trayMenuRows')
        compare(items.count,6)
        compare(items.itemAt(1).entry.enabled,false)
        compare(items.itemAt(3).entry.checkState,Qt.Checked)
        compare(items.itemAt(4).entry.buttonType,2)
        const disabled=items.itemAt(1)
        mouseClick(disabled,100,15)
        compare(activations,0)
        const checked=items.itemAt(3)
        mouseClick(checked,100,15)
        compare(rows[3].calls,1)
        compare(activations,1)
    }
    function test_keyboard_skips_separator_and_disabled_and_supports_back() {
        content.forceActiveFocus()
        tryCompare(content,'selectedIndex',0)
        keyClick(Qt.Key_Down)
        compare(content.selectedIndex,3)
        keyClick(Qt.Key_Return)
        compare(rows[3].calls,1)
        keyClick(Qt.Key_Down);compare(content.selectedIndex,4)
        keyClick(Qt.Key_End);compare(content.selectedIndex,5)
        keyClick(Qt.Key_Home);compare(content.selectedIndex,0)
        content.canGoBack=true
        keyClick(Qt.Key_Left);compare(backs,1)
        keyClick(Qt.Key_Escape);compare(backs,2)
    }
    function test_role_changes_do_not_replace_native_entries() {
        const items=findChild(content,'trayMenuRows'),original=items.itemAt(3)
        rows[3].checkState=Qt.Unchecked
        rows[3].text='A changed title'
        compare(items.itemAt(3),original)
        compare(original.entry.checkState,Qt.Unchecked)
        compare(original.entry.text,'A changed title')
    }
    function test_blank_bar_dismissal_releases_the_menu() {
        const host=Qt.createQmlObject('import QtQuick;QtObject {signal dismissPopoutsRequested()}',test)
        const component=Qt.createComponent('../../shell/components/TrayMenu.qml')
        const controller=component.createObject(test,{nativeWindowEnabled:false,hostWindow:host})
        verify(controller.open({children:rows},'Owned app'))
        compare(controller.opened,true)
        host.dismissPopoutsRequested()
        compare(controller.opened,false)
        compare(controller.depth,0)
        controller.destroy();host.destroy()
    }
    function test_controller_retains_ancestor_openers_until_deferred_native_action_returns() {
        const child=entry('Child',{}),parent=rows[5]
        parent.children=[child]
        const component=Qt.createComponent('../../shell/components/TrayMenu.qml')
        compare(component.status,Component.Ready,component.errorString())
        const controller=component.createObject(test,{nativeWindowEnabled:false})
        verify(controller.open({children:rows},'Owned app'))
        compare(controller.depth,1)
        verify(controller.activate(parent));compare(controller.depth,2)
        compare(controller.entries[0],child)
        controller.back();compare(controller.depth,1)
        verify(controller.activate(parent));verify(controller.activate(child))
        compare(child.calls,1)
        // Native entries remain alive throughout triggered(), then close safely.
        compare(controller.opened,true)
        tryCompare(controller,'opened',false)
        controller.destroy();child.destroy()
    }
}
