pragma Singleton

import QtQuick

QtObject {
    id: root

    // The property change signal stands in for DesktopEntries.applicationsChanged.
    // Qt rejects a second signal of that name. values starts empty, matching a
    // queued desktop-entry scan before the real signal runs.
    property var applications: ({ values: [] })

    function byId(id) {
        return null;
    }

    function heuristicLookup(name) {
        return null;
    }
}
