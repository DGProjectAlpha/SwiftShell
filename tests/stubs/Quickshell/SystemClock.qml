import QtQuick

QtObject {
    enum Precision {
        Seconds,
        Minutes
    }

    property int precision: Precision.Seconds
    property var date: new Date()
}
