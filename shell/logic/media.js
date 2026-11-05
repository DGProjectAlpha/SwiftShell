function objectValues(model) {
    if (!model)
        return [];
    if (Array.isArray(model))
        return model;
    const values = model.values;
    if (values && typeof values.length === "number") {
        const out = [];
        for (let i = 0; i < values.length; i++)
            out.push(values[i]);
        return out;
    }
    return [];
}

function pickPlayer(players) {
    const source = objectValues(players);
    let fallback = null;
    for (let i = 0; i < source.length; i++) {
        const player = source[i];
        if (!player)
            continue;
        if (fallback === null)
            fallback = player;
        if (player.isPlaying === true)
            return player;
    }
    return fallback;
}

function mediaLine(player) {
    if (!player)
        return "";
    const title = typeof player.trackTitle === "string" ? player.trackTitle.trim() : "";
    const artist = typeof player.trackArtist === "string" ? player.trackArtist.trim() : "";
    if (title !== "" && artist !== "")
        return title + " — " + artist;
    if (title !== "")
        return title;
    if (typeof player.identity === "string" && player.identity.trim() !== "")
        return player.identity.trim();
    return "Media";
}

function playerId(player) {
    if(!player)return "";
    if(typeof player.dbusName==="string" && player.dbusName)return player.dbusName;
    return typeof player.identity==="string" ? player.identity : "";
}
function selectPlayer(players,id) {
    const source=objectValues(players);
    if(id) {
        const selected=source.find(function(player){return playerId(player)===id});
        if(selected)return selected;
    }
    return pickPlayer(source);
}
function sourceChoices(players) {
    return [{value:"",label:"Automatic · active player"}].concat(objectValues(players).map(function(player){return {value:playerId(player),label:player.identity || "Media player"}}));
}
function duration(player) {
    return player && player.lengthSupported===true && Number.isFinite(player.length) && player.length>0 ? player.length : 0;
}
function position(player) {
    if(!player || player.positionSupported!==true || !Number.isFinite(player.position))return 0;
    const end=duration(player);
    return Math.max(0,end>0 ? Math.min(end,player.position) : player.position);
}
function trackKey(player) {
    if(!player)return "";
    return playerId(player)+"/"+String(player.uniqueId===undefined ? "" : player.uniqueId);
}
function seekPosition(player,fraction) {
    if(!player || !mediaControls(player).seek || !Number.isFinite(fraction))return null;
    return Math.max(0,Math.min(1,fraction))*duration(player);
}
function timeLabel(seconds) {
    if(!Number.isFinite(seconds) || seconds<0)return "—";
    const whole=Math.floor(seconds),hours=Math.floor(whole/3600),minutes=Math.floor(whole/60)%60,remaining=whole%60;
    return (hours ? hours+":"+String(minutes).padStart(2,"0") : String(minutes))+":"+String(remaining).padStart(2,"0");
}
function artSource(player) {
    const url=player && typeof player.trackArtUrl==="string" ? player.trackArtUrl : "";
    return /^(?:https?:\/\/|file:\/\/|data:image\/(?:png|jpeg|webp);base64,)/i.test(url) ? url : "";
}
function mediaControls(player) {
    if (!player)
        return { toggle: false, next: false, previous: false, playing: false, seek:false, art: "" };
    return {
        toggle: player.canTogglePlaying === true,
        next: player.canGoNext === true,
        previous: player.canGoPrevious === true,
        playing: player.isPlaying === true,
        seek:player.canSeek===true && player.positionSupported===true && duration(player)>0,
        art:artSource(player),
    };
}

var swiftshellMedia = {
    objectValues: objectValues,
    pickPlayer: pickPlayer,
    mediaLine: mediaLine,
    mediaControls: mediaControls,
    playerId:playerId,selectPlayer:selectPlayer,sourceChoices:sourceChoices,
    duration:duration,position:position,trackKey:trackKey,seekPosition:seekPosition,timeLabel:timeLabel,artSource:artSource,
};

if (typeof module !== "undefined" && module && module.exports)
    module.exports = swiftshellMedia;
