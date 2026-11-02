//@ pragma ShellId swiftshell-clock-audit
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
    id: audit
    property int stage: 0
    property double started: 0
    readonly property bool readback: Quickshell.env("SWIFTSHELL_CLOCK_READBACK") === "1"
    Timer {
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            const service = Services.ClockService;
            if (!service.loaded) return;
            if (audit.readback) {
                if (audit.stage === 0) {
                    if (service.state.style !== "analogue" || service.state.stopwatch.status !== "running" || service.state.stopwatch.laps.length !== 1) {
                        console.warn("Clock audit: FAILED restart state"); Qt.quit(); return;
                    }
                    audit.stage = 1;
                }
                if (service.finished && !service.writing) {
                    service.stopwatch("pause");
                    console.info("Clock audit: restarted countdown expired and stopwatch retained its lap");
                    finish.restart();
                    running = false;
                }
            } else if (audit.stage === 0) {
                service.setStyle("analogue");
                service.stopwatch("start");
                service.timer("start", 3000);
                audit.started = Date.now();
                audit.stage = 1;
            } else if (audit.stage === 1 && Date.now() - audit.started > 200) {
                service.stopwatch("lap");
                audit.stage = 2;
            } else if (audit.stage === 2 && !service.writing && service.persisted === JSON.stringify(service.state)) {
                console.info("Clock audit: running countdown and stopwatch saved");
                Qt.quit();
            }
        }
    }
    Timer { id: finish; interval: 400; onTriggered: Qt.quit() }
    Timer { interval: 10000; running: true; onTriggered: {console.warn("Clock audit: FAILED timeout"); Qt.quit()} }
}
