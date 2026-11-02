pragma Singleton

import QtQuick
import Quickshell
import "../logic/capabilities.js" as Capabilities

Singleton {
    id: root

    property bool shadowAvailable: false
    property bool open: false
    property var nativeWindow: null
    property int focusTicket: 0
    property string reason: ""
    property string pendingControl:""
    function requestControl(id,category) {pendingControl=id;SettingsStore.setSettingsCategory(category);show()}

    signal windowActionRequested(string action)
    signal appearanceEditRequested(string key, real value)

    function show() {
        const step = Capabilities.reduceSettingsWindow(
            { open: root.open, instances: root.open ? 1 : 0, focused: root.open, reason: root.reason },
            "launch"
        )
        root.reason = step.reason
        if (root.open) {
            WindowService.request("activate")
            root.focusTicket += 1
            return
        }
        WindowService.request("prepare")
    }

    Connections {
        target: WindowService
        function onCompleted(action, success) {
            if (action === "prepare") root.open = true
        }
    }

    function hide() {
        const step = Capabilities.reduceSettingsWindow(
            { open: root.open, instances: root.open ? 1 : 0, focused: false, reason: root.reason },
            "close"
        )
        root.open = step.open
        root.reason = step.reason
    }

    function noteLoadFailed() {
        const step = Capabilities.reduceSettingsWindow(
            { open: true, instances: 1, focused: false, reason: "" },
            "load-failed"
        )
        root.open = step.open
        root.reason = step.reason
        console.warn("SwiftShell: settings window did not load")
    }
}
