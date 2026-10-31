import QtQuick

Item {
    property string title: ""
    property size minimumSize: Qt.size(0, 0)
    property size maximumSize: Qt.size(16777215, 16777215)
    signal closed()

    function requestActivate() {}
}
