import QtQuick

QtObject {
    property var window: null
    property int edges: 0
    property int gravity: 0
    property int adjustment: 0
    property QtObject rect: QtObject {
        property real x: 0
        property real y: 0
        property real width: 0
        property real height: 0
    }

    signal anchoring()

    function updateAnchor() {
        anchoring()
    }
}
