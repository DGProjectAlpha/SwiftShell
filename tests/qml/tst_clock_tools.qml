import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/logic/clocktools.js" as Tools
TestCase {
    id: test
    name: "ClockTools"
    when: windowShown
    visible: true
    width: 500; height: 650
    property var panel: null
    property var saved: null
    property var clockSettings: null
    function init() {
        saved = Services.ClockService.state;
        clockSettings = Services.SettingsStore.snapshot();
        Services.ClockService.protectedFile = true;
        Services.ClockService.loaded = true;
        Services.ClockService.state = Tools.emptyState();
        const component = Qt.createComponent("../../shell/popovers/CalendarPanel.qml");
        compare(component.status, Component.Ready, component.errorString());
        panel = component.createObject(test);
        verify(panel !== null);
    }
    function cleanup() {
        panel.destroy(); panel = null;
        Services.ClockService.state = saved;
        Services.SettingsStore.applyDocument(clockSettings);
    }
    function test_default_clock_and_real_style_controls() {
        compare(panel.activeTab, "clock");
        verify(findChild(panel, "clockReadout") !== null);
        mouseClick(findChild(panel, "clockAnalogue"));
        compare(Services.ClockService.state.style, "analogue");
        verify(panel.implicitHeight > 300);
        mouseClick(findChild(panel, "clockDigital"));
        compare(Services.ClockService.state.style, "digital");
    }
    function test_calendar_month_selection_and_navigation() {
        panel.showTab("calendar");
        const calendar = findChild(panel, "clockCalendar");
        verify(calendar !== null);
        calendar.year = 2024; calendar.month = 1;
        compare(calendar.monthModel.weeks.length, 5);
        calendar.selectDate({year: 2024, month: 1, day: 29});
        compare(calendar.selectedDate.getDate(), 29);
        calendar.shift(1); compare(calendar.month, 2);
        calendar.showToday();
        compare(calendar.selectedDate.getDate(), calendar.today.getDate());
        const openButton = findChild(calendar, "openCalendarApplication");
        verify(openButton !== null);
        compare(openButton.enabled, false);
    }
    function test_calendar_seconds_do_not_recreate_month_model() {
        panel.showTab("calendar");
        const calendar = findChild(panel, "clockCalendar");
        calendar.today = new Date(2026, 10, 1, 12, 0, 0);
        const before = calendar.monthModel;
        calendar.today = new Date(2026, 10, 1, 12, 0, 1);
        verify(calendar.monthModel === before, "Second ticks must retain calendar delegates");
        calendar.today = new Date(2026, 10, 2, 0, 0, 0);
        verify(calendar.monthModel !== before, "A new day must update today indicators");
    }
    function test_timer_start_pause_resume_cancel() {
        panel.showTab("timer");
        const page = findChild(panel, "clockPage").item;
        page.selectedSeconds = 12;
        waitForRendering(page);
        mouseClick(findChild(page, "timerPrimary"));
        compare(Services.ClockService.timerStatus, "running");
        verify(Services.ClockService.remaining > 11000);
        waitForRendering(page);
        mouseClick(findChild(page, "timerPrimary"));
        compare(Services.ClockService.timerStatus, "paused");
        waitForRendering(page);
        mouseClick(findChild(page, "timerPrimary"));
        compare(Services.ClockService.timerStatus, "running");
        waitForRendering(page);
        mouseClick(findChild(page, "timerReset"));
        compare(Services.ClockService.timerStatus, "ready");
    }
    function test_stopwatch_laps_pause_reset() {
        panel.showTab("stopwatch");
        const page = findChild(panel, "clockPage").item;
        mouseClick(findChild(page, "stopwatchPrimary"));
        compare(Services.ClockService.state.stopwatch.status, "running");
        wait(80);
        mouseClick(findChild(page, "stopwatchLapReset"));
        compare(Services.ClockService.state.stopwatch.laps.length, 1);
        verify(Services.ClockService.state.stopwatch.laps[0] > 0);
        mouseClick(findChild(page, "stopwatchPrimary"));
        compare(Services.ClockService.state.stopwatch.status, "paused");
        mouseClick(findChild(page, "stopwatchLapReset"));
        compare(Services.ClockService.state.stopwatch.laps.length, 0);
        compare(Services.ClockService.elapsed, 0);
    }
}
