pragma Singleton

import QtQuick

QtObject {
    readonly property int barHeight: 28
    readonly property int marginH: 10
    readonly property int moduleSpacing: 12
    readonly property int workspaceGap: 2
    readonly property int fontSize: 12
    readonly property string fontFamily: ""
    readonly property color textPrimary: "#F2F2F2"
    readonly property color textMuted: "#A3A3A3"
    readonly property color textHover: "#D4D4D4"
    readonly property color transparent: Qt.rgba(0, 0, 0, 0)
}
