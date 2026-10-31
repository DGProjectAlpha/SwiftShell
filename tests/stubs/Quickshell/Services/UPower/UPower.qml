pragma Singleton

import QtQuick

QtObject {
    property bool onBattery: false
    property QtObject displayDevice: QtObject {
        property bool ready: false
        property real percentage: 0
        property bool isLaptopBattery: false
        property real timeToEmpty: 0
        property real timeToFull: 0
    }
    property QtObject devices: QtObject { property var values: [] }
}
