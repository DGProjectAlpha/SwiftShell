//@ pragma ShellId swiftshell-launcher-keyboard-audit
import QtQuick
import QtTest
import Quickshell
import "services" as Services
import "launcher" as Launcher
ShellRoot {
    id: audit
    property int step: 0
    property int attempts: 0
    Launcher.LauncherWindow { id: launcher }
    TestCase { id: keyboard; when: false }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (++audit.attempts > 60) {
                console.error("Launcher keyboard audit FAILED: timed out at step",audit.step)
                Qt.quit(); return
            }
            if (audit.step === 0) {
                Services.LauncherModel.openLauncher()
                audit.step=1
            } else if (audit.step === 1 && launcher.searchHasFocus) {
                const field=keyboard.findChild(launcher,"launcherSearchInput")
                if (!field) { console.error("Launcher keyboard audit FAILED: input missing");Qt.quit();return }
                keyboard.keyClick(Qt.Key_D)
                audit.step=2
            } else if (audit.step === 2) {
                if (Services.LauncherModel.query !== "d") {
                    console.error("Launcher keyboard audit FAILED: typing did not reach input");Qt.quit();return
                }
                keyboard.keyClick(Qt.Key_Escape)
                audit.step=3
            } else if (audit.step === 3) {
                if (Services.LauncherModel.open) console.error("Launcher keyboard audit FAILED: Escape did not dismiss")
                else console.info("Launcher keyboard audit: real input typing and Escape passed")
                Qt.quit()
            }
        }
    }
}
