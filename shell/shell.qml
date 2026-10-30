//@ pragma ShellId swiftshell

import Quickshell
import QtQuick
import "bar"
import "launcher"
import "services"

ShellRoot {
    id: root

    Component.onCompleted: {
        console.info("SwiftShell: M1 prototype started");
        console.info("SwiftShell: calendar, control center, and launcher are available");
        console.info("SwiftShell: target monitor", SettingsStore.targetMonitor);
        console.info("SwiftShell: screen count", Quickshell.screens ? Quickshell.screens.length : 0);
    }

    Component.onDestruction: console.info("SwiftShell: prototype stopped")

    BarHost {}
    LauncherWindow {}
}
