pragma Singleton

import QtQuick

QtObject {
    property bool ready: true
    property QtObject preferredDefaultAudioSink: null
    property QtObject preferredDefaultAudioSource: null
    property QtObject defaultAudioSource: null
    property QtObject nodes: QtObject {
        property var values: []
    }
    property QtObject defaultAudioSink: QtObject {
        property string id: "stub-sink"
        property string description: "Stub Output"
        property QtObject audio: QtObject {
            property real volume: 0.4
            property bool muted: false
        }
    }
}
