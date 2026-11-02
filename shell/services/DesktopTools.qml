pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/desktoptools.js" as Tools
Singleton {
    id:root
    property var history:[]
    property bool clipboardAvailable:false
    readonly property bool screenshotAvailable:ScreenshotService.available
    readonly property bool regionAvailable:ScreenshotService.regionAvailable
    property bool readAgain:false
    property int generation:0
    property int readGeneration:0
    property string message:""
    readonly property bool busy:ScreenshotService.busy
    signal captureRequested()
    function clearHistory(){history=[]}
    function expireHistory(){const now=Date.now();history=history.filter(function(item){return now-item.time<1200000})}
    Timer {
        interval:root.history.length ? Math.max(1,Math.min.apply(null,root.history.map(function(item){return item.time}))+1200000-Date.now()) : 1200000
        running:SettingsStore.clipboardHistory && root.history.length>0
        repeat:false
        onTriggered:root.expireHistory()
    }
    function remember(text) {if(SettingsStore.clipboardHistory)history=Tools.remember(history,text,Date.now())}
    function clipboardResults(query){return SettingsStore.clipboardHistory ? Tools.results(history,query,Date.now()) : []}
    function readClipboard() {
        if(!SettingsStore.clipboardHistory || !clipboardAvailable)return
        if(reader.running){readAgain=true;return}
        readGeneration=generation
        reader.running=true
    }
    function screenshot(mode,output) {
        return ScreenshotService.capture(mode,output)
    }
    Connections {target:ScreenshotService;function onCaptureRequested(){root.captureRequested()}}
    Connections {
        target:Quickshell
        function onClipboardTextChanged(){if(SettingsStore.clipboardHistory)readDelay.restart()}
    }
    Connections {
        target:SettingsStore
        function onClipboardHistoryChanged(){root.generation++;root.clearHistory();if(!SettingsStore.clipboardHistory){readAgain=false;reader.running=false}}
    }
    // Coalesced clipboard events and one-shot capture preparation; no polling.
    Timer {id:readDelay;interval:40;onTriggered:root.readClipboard()}
    Process {
        id:probe
        command:["python3",Quickshell.shellDir+"/helpers/desktoptools.py","capabilities"]
        running:true
        stdout:StdioCollector {id:capabilities;waitForEnd:true}
        onExited:function(code,status) {
            try {const data=JSON.parse(capabilities.text);root.clipboardAvailable=data.clipboard===true} catch(error) {}
        }
    }
    Process {
        id:reader
        command:["python3",Quickshell.shellDir+"/helpers/desktoptools.py","clipboard"]
        stdout:SplitParser {
            onRead:function(line) {
                if(SettingsStore.clipboardHistory && root.readGeneration===root.generation)
                    try {const data=JSON.parse(line);if(data.ok && !data.skip)root.remember(data.text)}catch(error){}
            }
        }
        onExited:function(code,status) {
            if(root.readAgain){root.readAgain=false;readDelay.restart()}
        }
    }
}
