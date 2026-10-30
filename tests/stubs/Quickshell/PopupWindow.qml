import QtQuick

Item {
    property color color: "transparent"
    property var mask: null
    property var screen: null
    property Item contentItem: null
    property SurfaceFormat surfaceFormat: SurfaceFormat {}
    property Anchor anchor: Anchor {}

    signal closed()
}
