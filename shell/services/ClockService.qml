pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../logic/clocktools.js" as Tools

Singleton {
    id: root
    property var state: Tools.emptyState()
    property bool loaded: false
    property bool protectedFile: false
    property string persistenceMessage: ""
    property string notificationMessage: ""
    property var deliveryQueue:[]
    property string deliverySummary:"Timer finished"
    property string deliveryBody:"Your countdown has finished."
    property double now: Date.now()
    property int viewers: 0
    readonly property bool interactive: viewers > 0
    property bool directoryReady: false
    property bool writing: false
    property string persisted: ""
    property string inflight: ""
    readonly property string stateDirectory: ((typeof Quickshell.env === "function" ? Quickshell.env("XDG_STATE_HOME") : "") || StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/state") + "/swiftshell"
    readonly property string statePath: stateDirectory + "/clock-tools.json"
    readonly property string timerStatus: state.timer.status
    readonly property double remaining: Tools.timerRemaining(state.timer, now)
    readonly property double elapsed: Tools.stopwatchElapsed(state.stopwatch, now)
    readonly property bool running: state.timer.status === "running" || state.stopwatch.status === "running"
    readonly property bool finished: state.timer.status === "finished"
    signal timerFinished()

    function update(next) {
        state = next;
        now = Date.now();
        if (loaded && !protectedFile) saveDelay.restart();
    }
    function restore(document) {
        if (!loaded) return false;
        const result = Tools.readState(document);
        if (!result.ok) return false;
        update(result.state);
        Qt.callLater(root.tick);
        return true;
    }
    function setTab(value) {
        if (["clock", "calendar", "timer", "stopwatch"].indexOf(value) >= 0)
            update(Object.assign({}, state, { tab: value }));
    }
    function setStyle(value) {
        if (value === "digital" || value === "analogue") update(Object.assign({}, state, { style: value }));
    }
    function timer(action, duration) {
        if (!loaded) return;
        const previousStatus = state.timer.status;
        const next = Tools.timerAction(state.timer, action, Date.now(), duration);
        update(Object.assign({}, state, { timer: next }));
        if (action === "start" || action === "reset") notificationMessage = "";
        if (previousStatus !== "finished" && next.status === "finished") {
            timerFinished();
            notificationMessage = "Timer finished";
            deliver("Timer finished","Your countdown has finished.","timer");
        }
    }
    function stopwatch(action) {
        if (!loaded) return;
        const previous=state.stopwatch.status
        update(Object.assign({}, state, { stopwatch: Tools.stopwatchAction(state.stopwatch, action, Date.now()) }));
        if(action==="pause" && previous==="running" && elapsed>=1000)
            deliver("Stopwatch paused",Tools.durationText(elapsed,false)+" elapsed.","stopwatch");
    }
    function deliver(summary,body,kind) {
        if(NotificationsModel.publishLocal(summary,body,kind))return
        deliveryQueue=deliveryQueue.concat([{summary:summary,body:body}]).slice(-8)
        deliverNext()
    }
    function deliverNext() {
        if(notification.running || !deliveryQueue.length)return
        const item=deliveryQueue[0]
        deliveryQueue=deliveryQueue.slice(1)
        deliverySummary=item.summary;deliveryBody=item.body
        notification.running=true
    }
    function tick() {
        now = Date.now();
        if (loaded && state.timer.status === "running" && remaining === 0) {
            timer("finish");
        }
    }
    function write() {
        if (!loaded || protectedFile || !directoryReady || writing) return;
        const document = JSON.stringify(state);
        if (document === persisted) return;
        inflight = document;
        writing = true;
        stateFile.setText(document);
    }
    Timer { id: saveDelay; interval: 120; onTriggered: root.write() }
    Timer {
        // Background deadlines need no high-frequency polling. Hundredths are
        // refreshed only while a visible stopwatch is being used.
        interval: root.interactive && root.state.stopwatch.status === "running" ? 40 : 250
        repeat: true
        running: root.running || !root.loaded
        onTriggered: root.tick()
    }
    Process {
        id: createDirectory
        command: ["mkdir", "-p", "-m", "700", root.stateDirectory]
        running: true
        onExited: function(code, status) {
            root.directoryReady = code === 0;
            if (code !== 0) root.persistenceMessage = "Clock tools are available for this session, but could not be saved.";
            else if (root.loaded) saveDelay.restart();
        }
    }
    Process {
        id: notification
        // Deliver to the existing notification owner; never claim its D-Bus name.
        command: ["notify-send", "--app-name=SwiftShell", "--icon=alarm-symbolic", "--expire-time=0", root.deliverySummary, root.deliveryBody]
        onExited: function(code, status) {
            if (code !== 0) root.notificationMessage = "A clock notification could not be delivered.";
            Qt.callLater(root.deliverNext);
        }
    }
    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        onLoaded: {
            const result = Tools.readState(stateFile.text());
            root.state = result.state;
            root.persisted = JSON.stringify(root.state);
            root.protectedFile = !result.ok;
            root.persistenceMessage = result.ok ? "" : "Clock data could not be read and was left unchanged. Changes will last for this session.";
            root.loaded = true;
            Qt.callLater(root.tick);
        }
        onLoadFailed: function(error) {
            root.protectedFile = error !== FileViewError.FileNotFound;
            if (root.protectedFile) root.persistenceMessage = "Clock data is unavailable and was left unchanged. Changes will last for this session.";
            root.loaded = true;
            root.persisted = JSON.stringify(root.state);
        }
        onSaved: {
            root.persisted = root.inflight;
            root.inflight = "";
            root.writing = false;
            root.persistenceMessage = "";
            if (JSON.stringify(root.state) !== root.persisted) saveDelay.restart();
        }
        onSaveFailed: {
            root.writing = false;
            root.persistenceMessage = "Clock tools could not be saved. Your changes are still active for this session.";
        }
    }
}
