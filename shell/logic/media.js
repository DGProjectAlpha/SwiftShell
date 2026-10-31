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

function mediaControls(player) {
    if (!player)
        return { toggle: false, next: false, previous: false, playing: false, art: "" };
    return {
        toggle: player.canTogglePlaying === true,
        next: player.canGoNext === true,
        previous: player.canGoPrevious === true,
        playing: player.isPlaying === true,
        art: typeof player.trackArtUrl === "string" ? player.trackArtUrl : "",
    };
}

var swiftshellMedia = {
    objectValues: objectValues,
    pickPlayer: pickPlayer,
    mediaLine: mediaLine,
    mediaControls: mediaControls,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellMedia;
