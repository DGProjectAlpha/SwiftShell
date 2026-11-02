import QtQuick
// Load-only contract. Real capture readiness is tested by tests/live/overview.py.
Item {
    property var captureSource:null
    property bool paintCursor:false
    property bool live:false
    property size constraintSize:Qt.size(0,0)
    readonly property bool hasContent:false
    readonly property size sourceSize:Qt.size(0,0)
    signal stopped()
    function captureFrame() {}
}
