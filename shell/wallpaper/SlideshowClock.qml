import QtQuick

Item {
    id: clock

    property bool running: false
    property int intervalMs: 60000
    signal fired()

    // The interval is at least one minute. This is the slideshow schedule, not a frame loop.
    Timer {
        interval: Math.max(60000, clock.intervalMs)
        running: clock.running
        repeat: true
        onTriggered: clock.fired()
    }
}
