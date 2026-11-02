import QtQuick
QtObject {
    property bool enabled:false
    property var window:null
    readonly property bool active:enabled && window!==null
    signal cancelled()
}
