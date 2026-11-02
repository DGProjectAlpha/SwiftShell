pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/clipboard.js" as Clipboard
Singleton {
    id:root
    property bool windowOpen:false
    property bool windowReady:false
    property var geometry:({})
    property string notice:""
    property string windowError:""
    property string action:""
    property var queue:[]
    readonly property bool available:DesktopTools.clipboardAvailable
    readonly property bool recording:SettingsStore.clipboardHistory
    readonly property var entries:DesktopTools.history
    signal windowActivated()
    signal windowCompleted(string action,bool success)
    function items(query){return Clipboard.filter(entries,query,Date.now())}
    function copy(id) {
        const item=entries.find(function(entry){return entry.id===id})
        if(!recording || !item || Date.now()-item.time>=1200000)return false
        Quickshell.clipboardText=item.text
        notice="Copied to clipboard"
        return true
    }
    function remove(id){DesktopTools.history=entries.filter(function(entry){return entry.id!==id});notice=""}
    function clear(){DesktopTools.clearHistory();notice="History cleared"}
    function showWindow() {
        notice=""
        if(windowOpen){request("activate");windowActivated();return}
        request("prepare")
    }
    function hideWindow() {
        if(!windowOpen)return
        request("remember-close")
    }
    function request(next) {
        if(bridge.running){if(queue.indexOf(next)<0)queue=queue.concat([next]);return}
        action=next
        bridge.command=["python3",Quickshell.shellDir+"/helpers/clipboardwindow.py",next,"--blur-enabled",SettingsStore.panelBlur>0 ? "1" : "0"]
        bridge.running=true
    }
    Connections {
        target:SettingsStore
        function onClipboardHistoryChanged(){root.notice=""}
        function onPanelBlurChanged(){if(root.windowOpen)root.request("blur")}
    }
    Process {
        id:bridge
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            let success=false
            try {
                const result=JSON.parse(reply.text)
                success=code===0 && result.ok===true
                if(!success)throw new Error("Window integration is unavailable.")
                root.windowError=""
                if(result.geometry)root.geometry=result.geometry
                if(root.action==="prepare"){root.windowReady=false;root.windowOpen=true}
                if(root.action==="mapped")root.windowReady=true
            } catch(error){root.windowError="The clipboard window could not be prepared."}
            if(root.action==="remember-close"){root.windowOpen=false;root.windowReady=false;root.queue=root.queue.filter(function(item){return item!=="mapped" && item!=="activate"})}
            root.windowCompleted(root.action,success)
            if(root.queue.length){const next=root.queue[0];root.queue=root.queue.slice(1);Qt.callLater(function(){root.request(next)})}
        }
    }
}
