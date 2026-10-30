pragma Singleton

import QtQuick

QtObject {
    property string eventSocketPath: ""
    property QtObject workspaces: QtObject { property var values: [] }
    property QtObject monitors: QtObject { property var values: [] }
    property QtObject toplevels: QtObject { property var values: [] }

    function monitorFor(screen) { return null }
    function dispatch(command) {}
    function refreshMonitors() {}
    function refreshWorkspaces() {}
    function refreshToplevels() {}
}
