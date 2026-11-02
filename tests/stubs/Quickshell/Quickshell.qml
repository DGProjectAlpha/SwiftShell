pragma Singleton

import QtQuick

QtObject {
    property var screens: []
    property string clipboardText:""

    function execDetached(options) {
    }

    function iconPath(icon, check) {
        if (check === true)
            return "";
        return "";
    }
}
