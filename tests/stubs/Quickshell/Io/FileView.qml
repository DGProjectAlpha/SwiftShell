import QtQuick

QtObject {
    default property QtObject adapter
    property string path: ""
    property bool watchChanges: false
    property bool atomicWrites: false

    signal fileChanged()
    signal adapterUpdated()
    signal saved()
    signal saveFailed(var reason)
    signal loaded()
    signal loadFailed(var reason)

    property string storedText: ""

    function text() {
        return storedText
    }

    function setText(value) {
        storedText = value
        saved()
    }

    function reload() {}
    function writeAdapter() {}
}
