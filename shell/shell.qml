//@ pragma ShellId swiftshell

import Quickshell
import QtQuick
import "bar"
import "services"

ShellRoot {
    id: root

    Component.onCompleted: {
        console.info("SwiftShell: M1 prototype started");
        console.info("SwiftShell: target monitor", SettingsStore.targetMonitor);
        console.info("SwiftShell: screen count", Quickshell.screens ? Quickshell.screens.length : 0);
    }

    Component.onDestruction: console.info("SwiftShell: prototype stopped")

    BarHost {}
}
