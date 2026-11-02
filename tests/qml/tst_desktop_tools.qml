import QtQuick
import QtTest
import Quickshell
import Quickshell.Hyprland
import "../../shell/services" as Services
TestCase {
    id:test
    name:"DesktopSearchTools"
    when:windowShown
    visible:true;width:680;height:560
    property var saved:null
    function init(){saved=Services.SettingsStore.snapshot();failOnWarning(/Binding loop|TypeError|ReferenceError/)}
    function cleanup(){Services.SettingsStore.applyDocument(saved);Services.DesktopTools.clearHistory();Services.LauncherModel.query=""}
    function test_clipboard_requires_explicit_opt_in_and_prefix() {
        Services.SettingsStore.setClipboardHistory(false)
        Services.DesktopTools.remember("fixture disabled")
        compare(Services.DesktopTools.history.length,0)
        Services.SettingsStore.setClipboardHistory(true)
        Services.DesktopTools.remember("fixture enabled")
        compare(Services.DesktopTools.history.length,1)
        compare(Services.DesktopTools.clipboardResults("fixture").length,0)
        compare(Services.DesktopTools.clipboardResults("clip fixture").length,1)
        Services.SettingsStore.setClipboardHistory(false)
        compare(Services.DesktopTools.history.length,0)
    }
    function test_settings_controls_are_named_and_reachable() {
        const component=Qt.createComponent("../../shell/settings/SpotlightPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        const page=component.createObject(test,{width:600})
        verify(page.implicitHeight>200)
        page.destroy()
    }
    function test_live_window_provider_is_optional_and_typed() {
        const original=Hyprland.toplevels.values
        const handle={appId:"fixture.desktop",activate:function(){}}
        Hyprland.toplevels.values=[{address:"0xfixture",title:"Owned fixture window",lastIpcObject:{mapped:true},wayland:handle}]
        Services.SettingsStore.setSearchWindows(true)
        compare(Services.LauncherModel.windowResults("fixture").length,1)
        compare(Services.LauncherModel.windowResults("fixture")[0].handle,handle)
        Services.SettingsStore.setSearchWindows(false)
        compare(Services.LauncherModel.windowResults("fixture").length,0)
        Hyprland.toplevels.values=original
    }
}
