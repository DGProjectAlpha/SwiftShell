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

function nodeName(node) {
    if (!node)
        return "";
    const props = node.properties && typeof node.properties === "object" ? node.properties : {};
    const candidates = [props["application.name"], node.nickname, node.description, node.name];
    for (let i = 0; i < candidates.length; i++) {
        if (typeof candidates[i] === "string" && candidates[i].trim() !== "")
            return outputLabel(candidates[i]);
    }
    return "Audio";
}

function audioDevices(nodes, role) {
    const source = objectValues(nodes);
    const out = [];
    for (let i = 0; i < source.length; i++) {
        const node = source[i];
        if (!node || !node.audio || node.isStream === true)
            continue;
        const sink = node.isSink === true;
        if (role === "sink" && !sink)
            continue;
        if (role === "source" && sink)
            continue;
        const id = sinkIdentity(node.id);
        if (id === "")
            continue;
        out.push({ id: id, label: nodeName(node) });
        if (out.length === 8)
            break;
    }
    return out;
}

function audioStreams(nodes) {
    const source = objectValues(nodes);
    const out = [];
    for (let i = 0; i < source.length; i++) {
        const node = source[i];
        if (!node || !node.audio || node.isStream !== true)
            continue;
        const id = sinkIdentity(node.id);
        if (id === "")
            continue;
        out.push({
            id: id,
            label: nodeName(node),
            volume: clampVolume(node.audio.volume),
            muted: node.audio.muted === true,
        });
        if (out.length === 6)
            break;
    }
    return out;
}

function selectDefault(input) {
    const source = input || {};
    if (source.ready !== true)
        return null;
    const requested = sinkIdentity(source.requestedId);
    const current = sinkIdentity(source.currentId);
    if (requested === "" || requested === current)
        return null;
    const devices = source.devices || [];
    for (let i = 0; i < devices.length; i++) {
        if (devices[i] && sinkIdentity(devices[i].id) === requested)
            return { id: requested, role: source.role === "source" ? "source" : "sink" };
    }
    return null;
}

var swiftshellAudio = {
    clampVolume: clampVolume,
    percent: percent,
    volumeCommand: volumeCommand,
    sinkIdentity: sinkIdentity,
    volumeWrite: volumeWrite,
    muteWrite: muteWrite,
    outputLabel: outputLabel,
    objectValues: objectValues,
    nodeName: nodeName,
    audioDevices: audioDevices,
    audioStreams: audioStreams,
    selectDefault: selectDefault,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellAudio;
