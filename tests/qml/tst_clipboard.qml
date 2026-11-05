import QtQuick
import QtTest
import Quickshell
import "../../shell/services" as Services
import "../../shell/clipboard" as ClipboardUI
TestCase {
    id:test
    name:"ClipboardHistorySurfaces"
    when:windowShown
    visible:true;width:640;height:680
    property var saved:null
    property var panel:null
    property string oldClipboard:""
    SignalSpy {id:dismissSpy;target:panel;signalName:"dismissed"}
    Component {id:panelComponent;ClipboardUI.ClipboardPanel {width:380}}
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved=Services.SettingsStore.snapshot()
        oldClipboard=Quickshell.clipboardText
        Services.SettingsStore.setClipboardHistory(true)
        Services.DesktopTools.clipboardAvailable=true
        Services.DesktopTools.history=[]
        Services.ClipboardModel.notice=""
        panel=panelComponent.createObject(test)
        verify(panel!==null)
        dismissSpy.clear()
    }
    function cleanup() {
        panel.destroy();panel=null
        Services.SettingsStore.applyDocument(saved)
        Services.DesktopTools.clearHistory()
        Quickshell.clipboardText=oldClipboard
    }
    function sample() {
        Services.DesktopTools.history=[{id:"first",time:Date.now(),text:"<b>Literal fixture</b>\nSecond line"},{id:"second",time:Date.now()-1,text:"Another example"}]
        waitForRendering(panel)
    }
    function test_filter_literal_preview_and_copy() {
        sample()
        compare(panel.rows.length,2)
        const search=findChild(panel,"clipboardSearch")
        verify(search!==null)
        search.text="literal"
        compare(panel.rows.length,1)
        let found=false
        function inspect(item) {
            if(item.text==="<b>Literal fixture</b> Second line"){compare(item.textFormat,Text.PlainText);found=true}
            for(let i=0;i<item.children.length;i++)inspect(item.children[i])
        }
        inspect(panel);verify(found,"Clipboard previews must render literal text")
        waitForRendering(panel)
        mouseClick(findChild(panel,"clipboardCopy-0"))
        compare(Quickshell.clipboardText,"<b>Literal fixture</b>\nSecond line")
        compare(dismissSpy.count,1)
    }
    function test_detached_selection_stays_open_and_remove_clear_work() {
        panel.detachedWindow=true
        sample()
        mouseClick(findChild(panel,"clipboardCopy-0"))
        compare(dismissSpy.count,0)
        mouseClick(findChild(panel,"clipboardRemove-0"))
        compare(Services.DesktopTools.history.length,1)
        compare(Services.DesktopTools.history[0].id,"second")
        mouseClick(findChild(panel,"clipboardClear"))
        compare(Services.DesktopTools.history.length,0)
    }
    function test_keyboard_search_and_copy_preserves_newlines() {
        sample()
        panel.focusSearch()
        keyClick(Qt.Key_Down)
        keyClick(Qt.Key_Return)
        compare(Quickshell.clipboardText,"Another example")
        compare(dismissSpy.count,1)
    }
    function test_disabled_and_expired_items_cannot_be_copied() {
        sample()
        Services.SettingsStore.setClipboardHistory(false)
        compare(Services.DesktopTools.history.length,0)
        verify(!Services.ClipboardModel.copy("first"))
        Services.SettingsStore.setClipboardHistory(true)
        Services.DesktopTools.history=[{id:"expired",text:"Old fixture",time:Date.now()-1200001}]
        compare(panel.rows.length,0)
        verify(!Services.ClipboardModel.copy("expired"))
    }
    function test_window_loads_with_real_resize_and_close_controls() {
        const component=Qt.createComponent("../../shell/clipboard/ClipboardWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test)
        verify(window!==null)
        compare(window.title,"SwiftShell Clipboard")
        verify(typeof window.beginResize==="function")
        verify(findChild(window,"clipboardWindowClose")!==null)
        window.destroy()
    }
}
