//@ pragma ShellId swiftshell-save-cycle-audit
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
    property int stage: 0
    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            const store = Services.SettingsStore;
            if (store.persistenceState !== "ready") return;
            if (stage === 0) {
                stage = 1;
                store.setBarSurface("", "solid", "#161616", .37);
                Qt.callLater(function() { store.writeLatest(); store.writeLatest(); });
            } else if (stage === 1) {
                stage = 2;
                for (let index = 0; index < 20; index++)
                    store.setBarSurface("", "solid", "#161616", .20 + index / 100);
                store.setUse24Hour(false);
            } else if (stage === 2) {
                stage = 3;
                store.writeLatest();
                store.writeLatest();
            } else {
                console.info("Settings save cycle: duplicate and rapid writes passed");
                Qt.quit();
            }
        }
    }
    Timer {
        interval: 6000
        running: true
        onTriggered: { console.warn("Settings save cycle: FAILED", Services.SettingsStore.persistenceState); Qt.quit(); }
    }
}
