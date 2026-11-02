import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    id:test
    name:"SystemPerformance"
    when:windowShown
    visible:true;width:500;height:700
    property var panel:null
    property var saved:({})
    function init() {
        const service=Services.SystemPerformance
        saved={viewers:service.viewers,failed:service.failed,cpu:service.cpu,memory:service.memory,gpus:service.gpus,cpuHistory:service.cpuHistory,memoryHistory:service.memoryHistory,gpuHistory:service.gpuHistory,available:service.available,error:service.error}
        service.viewers=0;service.cpuHistory=[];service.memoryHistory=[];service.gpuHistory=[]
        service.failed=false
    }
    function cleanup() {
        if(panel){panel.destroy();panel=null}
        const service=Services.SystemPerformance
        service.viewers=saved.viewers;service.cpu=saved.cpu;service.memory=saved.memory;service.gpus=saved.gpus
        service.cpuHistory=saved.cpuHistory;service.memoryHistory=saved.memoryHistory;service.gpuHistory=saved.gpuHistory
        service.available=saved.available;service.error=saved.error
        service.failed=saved.failed
    }
    function sample(usage) {return {ok:true,cpu:{usage:usage,temperature:47},memory:{usage:26.8,usedBytes:8710092*1024,totalBytes:32528792*1024,temperature:null},gpus:[{name:"NVIDIA GeForce RTX 4070",usage:22,usedBytes:1255*1048576,totalBytes:12282*1048576,temperature:40}]}}
    function test_live_data_and_bounded_history() {
        const service=Services.SystemPerformance
        for(let i=0;i<85;i++)verify(service.accept(sample(i)))
        compare(service.cpuHistory.length,60);compare(service.cpuHistory[0],25)
        compare(service.percent(service.gpu.usage),"22%")
        compare(service.temperature(service.gpu.temperature),"40 °C")
        compare(service.temperature(service.memory.temperature),"Not reported")
        compare(service.bytes(1255*1048576),"1.2 GiB")
        verify(service.available)
        verify(!service.accept({ok:false}))
    }
    function test_sampling_only_while_viewed_and_unsupported_is_unknown() {
        const service=Services.SystemPerformance
        verify(!service.sampling)
        service.startViewing();verify(service.sampling)
        service.startViewing();service.stopViewing();verify(service.sampling)
        service.stopViewing();verify(!service.sampling)
        service.stopViewing();compare(service.viewers,0)
        service.accept({ok:true,cpu:{usage:null,temperature:null},memory:{usage:null,usedBytes:null,totalBytes:null,temperature:null},gpus:[]})
        compare(service.percent(service.cpu.usage),"—")
        compare(service.percent(service.gpu.usage),"—")
        compare(service.gpuHistory.length,0)
        verify(!service.available)
    }
    function test_panel_loads_actual_metric_components_and_releases_viewer() {
        const service=Services.SystemPerformance
        service.accept(sample(15))
        const component=Qt.createComponent("../../shell/popovers/PerformancePanel.qml")
        compare(component.status,Component.Ready,component.errorString())
        panel=component.createObject(test)
        verify(panel!==null)
        service.accept(sample(15))
        compare(service.viewers,1)
        compare(findChild(panel,"performanceCpu").value,"15%")
        compare(findChild(panel,"performanceGpu").value,"22%")
        compare(findChild(panel,"performanceMemory").temperature,"Not reported")
        panel.destroy();panel=null;wait(1)
        compare(service.viewers,0)
    }
    function test_bar_keyboard_action_and_stable_geometry() {
        const service=Services.SystemPerformance
        service.accept(sample(9))
        const component=Qt.createComponent("../../shell/bar/PerformanceModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        panel=component.createObject(test)
        verify(panel!==null)
        const initialWidth=panel.implicitWidth
        const original=findChild(panel,"performanceBarMetric-C")
        verify(original!==null)
        service.accept(sample(100))
        compare(panel.implicitWidth,initialWidth)
        compare(findChild(panel,"performanceBarMetric-C"),original)
        const spy=Qt.createQmlObject('import QtTest; SignalSpy {}',test)
        spy.target=panel;spy.signalName="activated"
        panel.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(spy.count,1)
        spy.destroy()
    }
    function test_sampler_failure_clears_stale_metrics_and_retry_is_real() {
        const service=Services.SystemPerformance
        service.accept(sample(15));service.startViewing()
        const sampler=findChild(service,"systemPerformanceSampler")
        verify(sampler!==null)
        sampler.exited(1,0)
        verify(service.failed);verify(!service.available)
        compare(service.percent(service.cpu.usage),"—")
        compare(service.cpuHistory.length,0)
        service.retry();verify(!service.failed);verify(service.sampling)
    }
}
