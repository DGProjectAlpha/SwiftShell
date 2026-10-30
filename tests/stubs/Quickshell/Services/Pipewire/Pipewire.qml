pragma Singleton

import QtQuick

QtObject {
    property QtObject defaultAudioSink: QtObject {
        property string id: "stub-sink"
        property string description: "Stub Output"
        property QtObject audio: QtObject {
            property real volume: 0.4
            property bool muted: false
        }
    }
}
