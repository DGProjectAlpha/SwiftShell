import QtQuick
QtObject {
    property var command: []
    property bool running: false
    property bool stdinEnabled: false
    property QtObject stdout
    signal started()
    signal exited(int exitCode, int exitStatus)
    function write(data) {}
}
