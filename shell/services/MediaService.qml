pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../logic/media.js" as Media
Singleton {
    id:root
    property string selectedId:""
    property string error:""
    readonly property var players:Media.objectValues(Mpris.players)
    readonly property var player:Media.selectPlayer(Mpris.players,selectedId)
    readonly property var controls:Media.mediaControls(player)
    readonly property var sourceChoices:Media.sourceChoices(players)
    readonly property real duration:Media.duration(player)
    readonly property real position:Media.position(player)
    readonly property string trackKey:Media.trackKey(player)
    function selectSource(id) {
        if(id!=="" && !players.some(function(item){return Media.playerId(item)===id}))return false
        selectedId=id;error="";return true
    }
    function act(action) {
        const target=player,allowed=Media.mediaControls(target)
        if(!target || !({toggle:allowed.toggle,next:allowed.next,previous:allowed.previous})[action])return false
        try {
            if(action==="toggle")target.togglePlaying()
            else if(action==="next")target.next()
            else if(action==="previous")target.previous()
            else return false
            error="";return true
        } catch(failure){error="The player could not perform that action.";return false}
    }
    function seek(target,key,fraction) {
        if(target!==player || key!==Media.trackKey(target) || !Media.mediaControls(target).seek)return false
        const seconds=Media.seekPosition(target,fraction)
        if(seconds===null)return false
        try {target.position=seconds;error="";return true}
        catch(failure){error="The player could not change playback position.";return false}
    }
    function refreshPosition() {
        if(player && controls.playing && player.positionSupported===true && typeof player.positionChanged==="function")player.positionChanged()
    }
    onPlayersChanged: {
        if(selectedId!=="" && !players.some(function(item){return Media.playerId(item)===root.selectedId}))selectedId=""
    }
    onPlayerChanged:error=""
}
