//@ pragma ShellId swiftshell-shortcuts-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "settings" as Settings
ShellRoot {
    FloatingWindow {
        id:window
        title:"SwiftShell Shortcut Audit"
        visible:true
        implicitWidth:800
        implicitHeight:600
        color:"#202020"
        Settings.ShortcutsPage {id:page;anchors.fill:parent}
        Component.onCompleted:Services.SettingsModel.nativeWindow=window
    }
    IpcHandler {
        target:"audit"
        function status():string {return JSON.stringify({recording:page.recordingStatus(),busy:Services.ShortcutsService.busy,error:Services.ShortcutsService.error,actions:Services.ShortcutsService.actions})}
        function record():void {page.startRecording("settings")}
        function apply():void {Services.ShortcutsService.apply("settings",page.draftModifiers,page.draftKey)}
        function remove():void {Services.ShortcutsService.remove("settings")}
        function quit():void {Qt.quit()}
    }
}
