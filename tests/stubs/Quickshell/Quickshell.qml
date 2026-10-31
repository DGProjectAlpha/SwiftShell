pragma Singleton

import QtQuick

QtObject {
    property var screens: []

    function execDetached(options) {
    }

    function iconPath(icon, check) {
        if (check === true)
            return "";
        return "";
    }
}
