import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    id:test
    name:"ClockDateContext"
    when:windowShown
    visible:true
    width:600;height:200
    function test_date_and_time_have_independent_targets() {
        const saved=Services.SettingsStore.snapshot()
        Services.SettingsStore.setClockOptions(false,true,"short")
        const component=Qt.createComponent("../../shell/bar/ClockModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        const module=component.createObject(test)
        let clocks=0,calendars=0
        module.activated.connect(function(){clocks++})
        module.calendarActivated.connect(function(){calendars++})
        const date=findChild(module,"barDateButton"),time=findChild(module,"barTimeLabel")
        verify(date!==null);verify(time!==null)
        mouseClick(date,date.width/2,date.height/2)
        compare(calendars,1);compare(clocks,0)
        mouseClick(time,time.width/2,time.height/2)
        compare(calendars,1);compare(clocks,1)
        date.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(calendars,2);compare(clocks,1)
        module.destroy();Services.SettingsStore.applyDocument(saved)
    }
    function test_live_activity_retains_clock_context_and_clicks_tools() {
        const saved=Services.ClockService.state
        const now=Date.now()
        Services.ClockService.state={version:1,tab:"clock",style:"digital",timer:{status:"running",duration:60000,remaining:60000,deadline:now+60000},stopwatch:{status:"ready",elapsed:0,startedAt:0,laps:[]}}
        Services.ClockService.now=now
        const component=Qt.createComponent("../../shell/bar/ClockModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        const widget=component.createObject(test)
        verify(widget.timerVisible)
        verify(widget.activityText.indexOf("01:00")>=0)
        Services.ClockService.now=now+1000
        verify(widget.activityText.indexOf("00:59")>=0)
        waitForRendering(widget)
        const before=widget.width
        Services.ClockService.state=Object.assign({},Services.ClockService.state,{stopwatch:{status:"running",elapsed:0,startedAt:now,laps:[]}})
        Services.ClockService.now=now+2000
        verify(widget.stopwatchVisible)
        tryVerify(function(){return widget.width>before})
        let tab=""
        widget.activityActivated.connect(function(value){tab=value})
        const activity=findChild(widget,"barClockActivity")
        waitForRendering(widget)
        mouseClick(activity,activity.width/2,activity.height/2)
        compare(tab,"timer")
        widget.vertical=true
        wait(1)
        verify(widget.height>30)
        widget.destroy()
        Services.ClockService.state=saved
    }
}
