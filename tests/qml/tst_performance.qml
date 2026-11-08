import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/bar" as BarUI
import "../../shell/components" as Components
import "../../shell/logic/bar.js" as Bar
TestCase {
    id:test
    name:"SystemPerformance"
    when:windowShown
    visible:true;width:500;height:700
    property var panel:null
    property var saved:({})
    property var peekTarget:null
    Component {
        id:renderContextComponent
        Item {
            id:context
            width:500;height:100
            property real devicePixelRatio:1
            property real contentScale:1
            property bool vertical:false
            property real railWidth:168
            readonly property int barTextRenderType:Bar.textRenderMode(devicePixelRatio,contentScale)==="native" ? Text.NativeRendering : Text.QtRendering
            readonly property Item contentItem:context
            function componentFor(id){return renderModule}
            Component {id:renderModule;Item {implicitWidth:37.375;implicitHeight:30;Components.BarLabel {objectName:"renderLabel";text:"12:34"}}}
            BarUI.ModuleStrip {objectName:"renderStrip";x:10.375;y:6.375;barWindow:context;modules:["search","clock","network"]}
        }
    }
    function init() {
        const service=Services.SystemPerformance
        saved={viewers:service.viewers,failed:service.failed,cpu:service.cpu,memory:service.memory,gpus:service.gpus,cpuHistory:service.cpuHistory,memoryHistory:service.memoryHistory,gpuHistory:service.gpuHistory,available:service.available,error:service.error}
        service.viewers=0;service.cpuHistory=[];service.memoryHistory=[];service.gpuHistory=[]
        service.failed=false
    }
    function cleanup() {
        if(panel){panel.destroy();panel=null}
        if(peekTarget){peekTarget.destroy();peekTarget=null}
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
        const original=findChild(panel,"performanceBarMetric-cpu")
        verify(original!==null)
        service.accept(sample(100))
        compare(panel.implicitWidth,initialWidth)
        compare(findChild(panel,"performanceBarMetric-cpu"),original)
        const spy=Qt.createQmlObject('import QtTest; SignalSpy {}',test)
        spy.target=panel;spy.signalName="activated"
        panel.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(spy.count,1)
        spy.destroy()
    }
    function test_compact_icons_and_correct_units_update_without_recreating_labels() {
        const service=Services.SystemPerformance
        const component=Qt.createComponent("../../shell/bar/PerformanceModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        panel=component.createObject(test)
        verify(panel!==null)
        service.accept(sample(15))
        const cpu=findChild(panel,"performanceLoad-cpu"),cpuTemperature=findChild(panel,"performanceTemperature-cpu")
        const gpu=findChild(panel,"performanceLoad-gpu"),gpuTemperature=findChild(panel,"performanceTemperature-gpu")
        compare(cpu.text,"15%");compare(cpuTemperature.text,"47°C")
        compare(gpu.text,"22%");compare(gpuTemperature.text,"40°C")
        compare(findChild(panel,"performanceLoad-ram").text,"27%")
        verify(!findChild(panel,"performanceTemperature-ram").visible)
        compare(findChild(panel,"performanceGlyph-cpu").kind,"cpu")
        compare(findChild(panel,"performanceGlyph-gpu").kind,"gpu")
        compare(findChild(panel,"performanceGlyph-ram").kind,"ram")
        verify(panel.implicitWidth<200,"Five live metrics must fit compact bar clusters")
        verify(cpu.font.pixelSize>=10);verify(cpuTemperature.font.pixelSize>=10)
        verify(cpu.height+cpuTemperature.height<=panel.height)
        const width=panel.implicitWidth,cpuX=cpu.mapToItem(panel,0,0).x,gpuX=gpu.mapToItem(panel,0,0).x
        const hot=sample(100);hot.cpu.temperature=100;hot.gpus[0].usage=100;hot.gpus[0].temperature=99
        service.accept(hot)
        compare(cpu.text,"100%");compare(cpuTemperature.text,"100°C")
        compare(gpuTemperature.text,"99°C")
        compare(panel.implicitWidth,width)
        compare(findChild(panel,"performanceLoad-cpu"),cpu)
        compare(findChild(panel,"performanceTemperature-cpu"),cpuTemperature)
        compare(cpu.mapToItem(panel,0,0).x,cpuX);compare(gpu.mapToItem(panel,0,0).x,gpuX)
        verify(panel.Accessible.name.indexOf("CPU temperature 100 °C")>=0)
        service.accept({ok:true,cpu:{usage:null,temperature:null},memory:{usage:null,usedBytes:null,totalBytes:null,temperature:null},gpus:[]})
        compare(cpu.text,"—");compare(cpuTemperature.text,"—")
        compare(gpu.text,"—");compare(gpuTemperature.text,"—")
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
    function test_native_hinted_rendering_is_scoped_to_one_to_one_bar_context() {
        panel=renderContextComponent.createObject(test)
        verify(panel!==null)
        const label=findChild(panel,"renderLabel")
        verify(label!==null)
        compare(label.renderType,Text.NativeRendering)
        verify(label.antialiasing)
        compare(label.font.hintingPreference,Font.PreferVerticalHinting)
        panel.devicePixelRatio=1.25
        compare(label.renderType,Text.QtRendering)
        panel.devicePixelRatio=1;panel.contentScale=.9
        compare(label.renderType,Text.QtRendering)
        panel.contentScale=1
        compare(label.renderType,Text.NativeRendering)
        const component=Qt.createComponent("../../shell/components/BarLabel.qml")
        const standalone=component.createObject(test,{text:"Outside bar"})
        compare(standalone.renderType,Text.QtRendering)
        standalone.destroy()
    }
    function test_bar_canvas_glyphs_antialias_without_geometry_changes() {
        const widget=Qt.createComponent("../../shell/bar/WidgetIndicator.qml").createObject(test,{kind:"notifications"})
        verify(widget!==null)
        const canvas=findChild(widget,"barWidgetGlyph")
        verify(canvas!==null);verify(canvas.antialiasing);verify(canvas.smooth)
        for(const path of ["PerformanceGlyph.qml","WeatherGlyph.qml"]) {
            const glyph=Qt.createComponent("../../shell/components/"+path).createObject(test)
            verify(glyph!==null);verify(glyph.antialiasing);verify(glyph.smooth)
            glyph.destroy()
        }
        widget.destroy()
    }
    function test_module_origins_snap_only_on_unscaled_one_to_one_output() {
        panel=renderContextComponent.createObject(test)
        verify(panel!==null)
        const strip=findChild(panel,"renderStrip")
        const aligned=strip.renderingGeometry()
        compare(aligned.length,3)
        for(let i=0;i<aligned.length;i++){compare(aligned[i].x,Math.round(aligned[i].x));compare(aligned[i].y,Math.round(aligned[i].y))}
        panel.devicePixelRatio=1.25
        const fractional=strip.renderingGeometry()
        compare(fractional[0].x,10.375);compare(fractional[0].y,6.375)
        panel.devicePixelRatio=1;panel.contentScale=1.25
        const custom=strip.renderingGeometry()
        compare(custom[0].x,10.375);compare(custom[0].y,6.375)
    }
    function createPeekController() {
        peekTarget=Qt.createQmlObject('import QtQuick;QtObject {property bool outputFullscreen:false;property string edge:"top";property real width:1536;property real height:28;property var screen:({x:2560,y:720,width:1536,height:864})}',test)
        const component=Qt.createComponent("../../shell/services/BarPeekController.qml")
        compare(component.status,Component.Ready,component.errorString())
        panel=component.createObject(test,{barWindow:peekTarget})
        verify(panel!==null)
    }
    function test_peek_sampling_requires_opt_in_and_this_outputs_actual_fullscreen() {
        createPeekController()
        verify(!panel.watching)
        peekTarget.outputFullscreen=true;verify(!panel.watching)
        panel.requested=true;verify(panel.watching)
        panel.cursor={x:2700,y:721}
        wait(50);panel.cursor={x:2700,y:760}
        wait(200);verify(!panel.open) // A short crossing is not a peek request.
        panel.cursor={x:2700,y:721}
        tryVerify(function(){return panel.open})
        peekTarget.outputFullscreen=false
        verify(!panel.open);verify(!panel.watching)
    }
    function test_peek_stays_for_its_popover_then_releases_without_resizing_bar() {
        createPeekController();peekTarget.outputFullscreen=true;panel.requested=true
        panel.cursor={x:2700,y:721}
        tryVerify(function(){return panel.open})
        panel.popupOpen=true;panel.cursor={x:2700,y:1000}
        wait(450);verify(panel.open)
        compare(peekTarget.width,1536);compare(peekTarget.height,28)
        panel.popupOpen=false
        tryVerify(function(){return !panel.open})
        panel.requested=false
        verify(!panel.watching);compare(panel.cursor,null)
    }
}
