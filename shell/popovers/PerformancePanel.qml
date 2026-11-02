import QtQuick
import "../components"
import "../services"
import "../themes"
Column {
    id:panel
    width:340
    spacing:Theme.settingsSpacing
    Component.onCompleted:SystemPerformance.startViewing()
    Component.onDestruction:SystemPerformance.stopViewing()
    Text {text:"Performance";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
    Text {width:parent.width;wrapMode:Text.WordWrap;text:SystemPerformance.error || (SystemPerformance.available ? "Live usage · last two minutes" : "Reading hardware…");color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    FlatButton {label:"Try again";visible:SystemPerformance.failed;onActivated:SystemPerformance.retry()}
    PerformanceMetric {
        objectName:"performanceCpu"
        width:parent.width;label:"CPU";value:SystemPerformance.percent(SystemPerformance.cpu.usage)
        detail:"Processor usage";temperature:SystemPerformance.temperature(SystemPerformance.cpu.temperature)
        history:SystemPerformance.cpuHistory
    }
    PerformanceMetric {
        objectName:"performanceGpu"
        width:parent.width;label:"GPU";value:SystemPerformance.percent(SystemPerformance.gpu.usage)
        detail:SystemPerformance.gpus.length ? SystemPerformance.gpu.name : "Usage not reported by this hardware"
        temperature:SystemPerformance.temperature(SystemPerformance.gpu.temperature)
        history:SystemPerformance.gpuHistory
    }
    Text {
        width:parent.width;visible:SystemPerformance.gpu.totalBytes!==null
        text:"Graphics memory · "+SystemPerformance.bytes(SystemPerformance.gpu.usedBytes)+" / "+SystemPerformance.bytes(SystemPerformance.gpu.totalBytes)
        color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
    }
    PerformanceMetric {
        objectName:"performanceMemory"
        width:parent.width;label:"Memory";value:SystemPerformance.percent(SystemPerformance.memory.usage)
        detail:SystemPerformance.bytes(SystemPerformance.memory.usedBytes)+" / "+SystemPerformance.bytes(SystemPerformance.memory.totalBytes)
        temperature:SystemPerformance.temperature(SystemPerformance.memory.temperature)
        history:SystemPerformance.memoryHistory
    }
    Text {width:parent.width;wrapMode:Text.WordWrap;text:"Temperature appears only when a sensor reports it. Memory usage excludes reclaimable cache.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
}
