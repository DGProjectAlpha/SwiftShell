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
    outputLabel: outputLabel,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellAudio;
