import QtQuick
QtObject { property var command: []; property bool running: false; property QtObject stdout; signal exited(int exitCode, int exitStatus) }
