import QtQuick
import QtMultimedia
import "../services"

Item {
    id:root
    visible:false
    readonly property bool available:devices.audioOutputs.length>0 && effect.status===SoundEffect.Ready
    readonly property bool playing:effect.playing
    readonly property string reason:devices.audioOutputs.length===0 ? "Connect an audio output to hear notification sounds." : effect.status===SoundEffect.Error ? "The notification sound could not be loaded." : effect.status===SoundEffect.Ready ? "" : "Preparing notification sound…"
    function playNotification() {
        if(!available || effect.playing)return false
        effect.play();return true
    }
    MediaDevices {id:devices}
    SoundEffect {
        id:effect
        source:Qt.resolvedUrl("../assets/sounds/notification.wav")
        audioDevice:devices.defaultAudioOutput
        volume:SettingsStore.notificationSoundVolume
        loops:1
    }
}
