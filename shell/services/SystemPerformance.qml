pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    property int viewers:0
    property bool available:false
    property bool failed:false
    property string error:""
    property var cpu:({usage:null,temperature:null})
    property var memory:({usage:null,usedBytes:null,totalBytes:null,temperature:null})
    property var gpus:[]
    property var cpuHistory:[]
    property var memoryHistory:[]
    property var gpuHistory:[]
    readonly property var gpu:gpus.length ? gpus[0] : ({name:"GPU",usage:null,usedBytes:null,totalBytes:null,temperature:null})
    readonly property bool sampling:sampler.running
    function clearMetrics() {
        available=false
        cpu={usage:null,temperature:null};memory={usage:null,usedBytes:null,totalBytes:null,temperature:null};gpus=[]
        cpuHistory=[];memoryHistory=[];gpuHistory=[]
    }
    function startViewing() {if(viewers===0){failed=false;error="";clearMetrics()}viewers++}
    function stopViewing() {viewers=Math.max(0,viewers-1)}
    function retry() {failed=false;error=""}
    function percent(value) {return typeof value==="number" && isFinite(value) ? Math.round(value)+"%" : "—"}
    function temperature(value) {return typeof value==="number" && isFinite(value) ? Math.round(value)+" °C" : "Not reported"}
    function bytes(value) {return typeof value==="number" && isFinite(value) ? (value/1073741824).toFixed(1)+" GiB" : "—"}
    function history(previous,value) {
        if(typeof value!=="number" || !isFinite(value))return []
        return previous.concat([Math.max(0,Math.min(100,value))]).slice(-60)
    }
    function accept(sample) {
        if(!sample || sample.ok!==true || !sample.cpu || !sample.memory || !Array.isArray(sample.gpus))return false
        cpu=sample.cpu;memory=sample.memory;gpus=sample.gpus.slice(0,8)
        cpuHistory=history(cpuHistory,cpu.usage)
        memoryHistory=history(memoryHistory,memory.usage)
        gpuHistory=history(gpuHistory,gpu.usage)
        available=typeof cpu.usage==="number" || typeof memory.usage==="number" || typeof gpu.usage==="number"
        error=""
        return true
    }
    Process {
        id:sampler
        objectName:"systemPerformanceSampler"
        command:["python3",Quickshell.shellDir+"/helpers/performancectl.py","--watch","--interval","2"]
        running:root.viewers>0 && !root.failed
        stdout:SplitParser {
            onRead:function(data) {
                try {if(!root.accept(JSON.parse(data)))root.error="Performance data is unavailable."}
                catch(error){root.error="Performance data could not be read."}
            }
        }
        onExited:function(code,status) {
            if(root.viewers>0 && !root.failed) {
                root.failed=true;root.clearMetrics()
                root.error="Performance monitoring stopped. Try again."
            }
        }
    }
}
