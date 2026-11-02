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
}
