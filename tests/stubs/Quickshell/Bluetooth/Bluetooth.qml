pragma Singleton

import QtQuick

QtObject {
    property QtObject defaultAdapter: null
    property QtObject adapters: QtObject { property var values: [] }
    property QtObject devices: QtObject { property var values: [] }
}
