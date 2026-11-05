pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../logic/audio.js" as Audio
Singleton {
    id:root
    readonly property bool connected:Pipewire.ready===true
    readonly property var sink:Pipewire.defaultAudioSink
    readonly property var source:Pipewire.defaultAudioSource
    readonly property var nodes: {
        const result=Audio.objectValues(Pipewire.nodes)
        if(sink && result.indexOf(sink)<0)result.push(sink)
        if(source && result.indexOf(source)<0)result.push(source)
        return result
    }
    readonly property bool outputReady:nodeReady(sink)
    readonly property bool inputReady:nodeReady(source)
    readonly property var outputs:Audio.audioDevices(nodes,"sink")
    readonly property var inputs:Audio.audioDevices(nodes,"source")
    readonly property var streams:Audio.audioStreams(nodes)
    property string error:""
    PwObjectTracker {
        // audio exists before binding; channel volumes and mute do not.
        objects:root.nodes.filter(function(node){return !!node && !!node.audio})
    }
    function nodeReady(node){return connected && !!node && !!node.audio && node.ready===true}
    function nodeById(id) {
        const key=Audio.sinkIdentity(id)
        return nodes.find(function(node){return node && Audio.sinkIdentity(node.id)===key}) || null
    }
    function defaultNode(role){return role==="source" ? source : sink}
    function idFor(role){const node=defaultNode(role);return node ? Audio.sinkIdentity(node.id) : ""}
    function setVolume(id,value) {
        const node=nodeById(id),command=Audio.volumeWrite({ready:nodeReady(node),gestureSinkId:id,currentSinkId:node ? node.id : null,muted:nodeReady(node) && node.audio.muted===true,requested:value})
        if(!command)return false
        try {node.audio.volume=command.volume;node.audio.muted=command.muted;error="";return true}
        catch(failure){error="The audio volume could not be changed.";return false}
    }
    function setDefaultVolume(role,gestureId,value) {
        if(idFor(role)!==Audio.sinkIdentity(gestureId))return false
        return setVolume(gestureId,value)
    }
    function setMuted(id,value) {
        const node=nodeById(id),command=Audio.muteWrite({ready:nodeReady(node),sinkId:id,muted:value})
        if(!command)return false
        try {node.audio.muted=command.muted;error="";return true}
        catch(failure){error="The audio mute state could not be changed.";return false}
    }
    function chooseDefault(id,role) {
        if(role!=="source" && role!=="sink")return false
        const command=Audio.selectDefault({ready:connected,requestedId:id,currentId:idFor(role),devices:role==="source" ? inputs : outputs,role:role})
        if(!command)return false
        const node=nodeById(command.id)
        if(!nodeReady(node))return false
        try {
            if(role==="source")Pipewire.preferredDefaultAudioSource=node
            else Pipewire.preferredDefaultAudioSink=node
            error="";return true
        } catch(failure){error="The audio device could not be selected.";return false}
    }
    function diagnostics(){return {connected:connected,outputReady:outputReady,inputReady:inputReady,outputs:outputs.length,inputs:inputs.length,streams:streams.length,outputId:idFor("sink"),inputId:idFor("source"),outputVolume:outputReady ? sink.audio.volume : null,inputVolume:inputReady ? source.audio.volume : null}}
}
