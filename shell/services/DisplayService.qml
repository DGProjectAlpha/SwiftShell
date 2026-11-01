pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var outputs: []
    property string state: "idle"
    property string error: ""
    property string message: ""
    property int remaining: 0
    property bool hasSaved: false
    property string activeAction: "snapshot"
    readonly property bool busy: bridge.running
    readonly property bool pending: state === "pending" || state === "applying" || state === "reverting" || state === "recovery-failed"
    readonly property string helper: Quickshell.shellDir + "/helpers/displayctl.py"
    signal refreshed()

    function request(action, layout) {
        if (bridge.running) return false
        activeAction = action
        error = ""
        const args = ["python3", helper, action]
        if (action === "apply") args.push("--outputs", JSON.stringify(layout))
        bridge.command = args
        bridge.running = true
        return true
    }
    function refresh() { request(root.pending ? "status" : "snapshot") }
    function apply(layout) { request("apply", layout) }
    function keep() { request("keep") }
    function revert() { request("revert") }
    function restore() { request("restore") }
    Process {
        id: bridge
        objectName: "displayBridge"
        stdout: StdioCollector { id: reply; waitForEnd: true }
        onExited: function (code, status) {
            try {
                const result = JSON.parse(reply.text)
                if (code !== 0 || !result.ok) throw new Error(result.message || "Display operation failed.")
                root.state = result.state
                root.message = result.message || ""
                root.remaining = result.remaining || 0
                root.hasSaved = result.hasSaved === true
                root.outputs = result.outputs || []
                root.refreshed()
                if (root.pending && root.activeAction === "snapshot") Qt.callLater(function () { root.request("status") })
            } catch (failure) { root.error = failure.message || "Could not reach display settings." }
        }
    }
    // Only polls an active, time-limited confirmation transaction.
    Timer {
        interval: 500
        running: root.pending
        repeat: true
        onTriggered: root.refresh()
    }
    Connections {
        target: HyprlandModel
        function onMonitorSnapshotChanged() { if (!root.pending) root.refresh() }
    }
}
