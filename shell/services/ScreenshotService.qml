pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    property bool open:false
    property bool available:false
    property bool regionAvailable:false
    property bool copyAvailable:false
    property string output:""
    property string mode:"region"
    property int delaySeconds:0
    property int countdown:0
    property string token:""
    property string imageUrl:""
    property int imageWidth:0
    property int imageHeight:0
    property string message:""
    property bool failed:false
    property bool cancelling:false
    property string action:""
    readonly property bool busy:bridge.running || cancelling || countdownTimer.running || settle.running
    readonly property bool capturing:countdownTimer.running || settle.running || (bridge.running && action==="capture")
    readonly property bool hasImage:token!=="" && imageUrl!==""
    readonly property var screen:Quickshell.screens.find(function(screen){return screen.name===root.output}) || Quickshell.screens[0] || null
    signal captureRequested()
    signal saveRequested()
    function show(outputName) {if(capturing)cancel();if(outputName)output=outputName;if(!available){message="Screenshot tools are unavailable.";failed=true}open=true}
    function close() {if(capturing)cancel();open=false}
    function request(next,args) {
        if(bridge.running)return false
        action=next;failed=false;message=""
        bridge.command=["python3",Quickshell.shellDir+"/helpers/screenshotctl.py",next].concat(args || [])
        bridge.running=true
        return true
    }
    function capture(nextMode,outputName) {
        if(busy)return false
        if(!available || (nextMode==="region" && !regionAvailable)){message="Screenshot tools are unavailable.";failed=true;open=true;return false}
        mode=nextMode==="output" ? "output" : "region"
        if(outputName)output=outputName
        if(!output && screen)output=screen.name
        message="";failed=false
        countdown=Math.max(0,Math.min(5,delaySeconds))
        if(countdown>0){open=true;countdownTimer.start()}else beginCapture()
        return true
    }
    function beginCapture() {message=mode==="region" ? "Drag to select an area. Press Escape to cancel." : "Capturing this display…";open=false;captureRequested();settle.start()}
    function cancel() {
        countdownTimer.stop();settle.stop()
        if(bridge.running && action==="capture"){cancelling=true;bridge.running=false}
        countdown=0;message="Screenshot cancelled.";failed=false;open=true
    }
    function copy() {if(!busy && hasImage && copyAvailable)return request("copy",["--token",token]);return false}
    function saveAs() {if(busy || !hasImage)return false;saveRequested();return true}
    function save(destination) {if(!busy && hasImage)return request("save",["--token",token,"--destination",String(destination)]);return false}
    function discard() {if(!busy && hasImage)return request("discard",["--token",token]);return false}
    function saveDialogUnavailable() {message="The save dialog is unavailable. Copy the PNG and paste it into an image app.";failed=true;open=true}
    Timer {id:countdownTimer;interval:1000;repeat:true;onTriggered:{root.countdown--;if(root.countdown<=0){stop();root.beginCapture()}}}
    Timer {id:settle;interval:250;onTriggered:root.request("capture",["--mode",root.mode,"--output",root.output,"--token",root.token])}
    Process {
        id:probe
        command:["python3",Quickshell.shellDir+"/helpers/screenshotctl.py","capabilities"]
        running:true
        stdout:StdioCollector {id:capabilities;waitForEnd:true}
        onExited:function(code,status) {
            try {const data=JSON.parse(capabilities.text);root.available=data.available===true;root.regionAvailable=data.region===true;root.copyAvailable=data.copy===true}catch(error){}
        }
    }
    Process {
        id:bridge
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            if(root.cancelling){root.cancelling=false;return}
            try {
                const result=JSON.parse(reply.text)
                root.failed=result.cancelled!==true && (code!==0 || result.ok!==true)
                root.message=result.message || "The screenshot operation could not finish."
                if(result.ok && root.action==="capture") {
                    root.token=result.token;root.imageUrl=result.imageUrl
                    root.imageWidth=result.width;root.imageHeight=result.height
                } else if(result.ok && root.action==="discard") {
                    root.token="";root.imageUrl="";root.imageWidth=0;root.imageHeight=0
                }
            } catch(error) {root.failed=true;root.message="The screenshot operation could not finish. Try again."}
            if(root.action==="capture")root.open=true
        }
    }
}
