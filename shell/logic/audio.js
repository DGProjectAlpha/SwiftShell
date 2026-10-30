function clampVolume(value) {
    const number = Number(value);
    if (!Number.isFinite(number))
        return null;
    return Math.min(1, Math.max(0, number));
}

function percent(volume) {
    const value = clampVolume(volume);
    if (value == null)
        return 0;
    return Math.round(value * 100);
}

function volumeCommand(muted, requested) {
    const volume = clampVolume(requested);
    if (volume == null)
        return null;
    return {
        volume: volume,
        muted: volume > 0 ? false : muted === true,
    };
}

function sinkIdentity(id) {
    if (id === undefined || id === null)
        return "";
    const text = String(id).trim();
    if (text === "" || text === "undefined" || text === "null")
        return "";
    if (text.indexOf("/") !== -1 || text.indexOf("\\") !== -1)
        return "";
    return text;
}

function volumeWrite(input) {
    const source = input || {};
    if (source.ready !== true)
        return null;
    const gestureSinkId = sinkIdentity(source.gestureSinkId);
    const currentSinkId = sinkIdentity(source.currentSinkId);
    if (gestureSinkId === "" || gestureSinkId !== currentSinkId)
        return null;
    const command = volumeCommand(source.muted, source.requested);
    if (!command)
        return null;
    return {
        volume: command.volume,
        muted: command.muted,
        sinkId: currentSinkId,
    };
}

function muteWrite(input) {
    const source = input || {};
    if (source.ready !== true)
        return null;
    const sinkId = sinkIdentity(source.sinkId);
    if (sinkId === "")
        return null;
    return {
        muted: source.muted === true,
        sinkId: sinkId,
    };
}

function outputLabel(description) {
    if (typeof description !== "string")
        return "Output";
    const trimmed = description.trim();
    if (trimmed === "" || trimmed.indexOf("/") !== -1 || trimmed.indexOf("\\") !== -1)
        return "Output";
    if (trimmed.length > 48)
        return trimmed.slice(0, 45) + "...";
    return trimmed;
}

var swiftshellAudio = {
    clampVolume: clampVolume,
    percent: percent,
    volumeCommand: volumeCommand,
    sinkIdentity: sinkIdentity,
    volumeWrite: volumeWrite,
    muteWrite: muteWrite,
    outputLabel: outputLabel,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellAudio;
