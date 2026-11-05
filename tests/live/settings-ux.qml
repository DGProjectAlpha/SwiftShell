//@ pragma ShellId swiftshell-settings-ux-audit
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services" as Services
ShellRoot {
    Loader {
        id:settings
        active:Services.SettingsModel.open
        source:"settings/SettingsWindow.qml"
        // Visual QA captures only this opaque, owned Qt surface.
        onLoaded:item.color="#424242"
    }
    TestCase {id:finder;when:false}
    IpcHandler {
        target:"audit"
        function open(output:string,category:string):void {Services.SettingsStore.setSettingsCategory(category);Services.SettingsModel.show(output)}
        function close():void {if(settings.item)settings.item.performAction("close")}
        function page(category:string):void {Services.SettingsStore.setSettingsCategory(category);if(settings.item)finder.findChild(settings.item,"settingsSearch").text=""}
        function search(text:string):void {if(settings.item)finder.findChild(settings.item,"settingsSearch").text=text}
        function scroll(y:real):void {if(settings.item){const scroll=finder.findChild(settings.item,"settingsScroller");scroll.contentY=y}}
        function undo():void {if(settings.item)settings.item.undo()}
        function capture(path:string):void {if(settings.item)settings.item.capturePreview(path)}
        function status():string {
            const w=settings.item
            return JSON.stringify({open:Services.SettingsModel.open,busy:Services.WindowService.busy || Services.WindowService.queue.length>0,persistence:Services.SettingsStore.persistenceState,error:Services.WindowService.error,category:Services.SettingsStore.settingsWindowCategory,width:w ? w.width : 0,height:w ? w.height : 0,frame:w ? w.frameGeometry() : null,ui:w ? w.uiGeometry() : null,fontSize:Services.SettingsStore.fontSize,panelOpacity:Services.SettingsStore.panelOpacity,accentColor:Services.SettingsStore.accentColor,past:w ? w.history.past.length : 0})
        }
        function quit():void {Qt.quit()}
    }
}
