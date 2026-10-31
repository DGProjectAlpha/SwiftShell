var ACTIONS = [
    { id: "spotlight", label: "Spotlight", detail: "Opens from the bar and from the request script." },
    { id: "settings", label: "Settings", detail: "Opens from Spotlight and the control center." },
    { id: "control", label: "Control center", detail: "Opens from the bar module." },
];

var MODIFIERS = ["alt", "ctrl", "shift", "super"];

function emptyRecorder() {
    return { phase: "idle", id: "", modifiers: [], key: "", error: "" };
}

function normalizeChord(modifiers, key) {
    var source = modifiers || [];
    var mods = [];
    var index;
    for (index = 0; index < MODIFIERS.length; index++) {
        if (source.indexOf(MODIFIERS[index]) !== -1)
            mods.push(MODIFIERS[index]);
    }
    var token = String(key == null ? "" : key).trim();
    if (token === "Escape")
        return null;
    if (!/^[A-Za-z0-9]{1,8}$/.test(token) && token !== "Space" && token !== "Return" && token !== "Tab")
        return null;
    return { modifiers: mods, key: token.length === 1 ? token.toUpperCase() : token };
}

function chordText(chord) {
    if (!chord || !chord.key)
        return "Not set";
    var names = { alt: "Alt", ctrl: "Ctrl", shift: "Shift", super: "Super" };
    var parts = [];
    for (var index = 0; index < MODIFIERS.length; index++) {
        if (chord.modifiers && chord.modifiers.indexOf(MODIFIERS[index]) !== -1)
            parts.push(names[MODIFIERS[index]]);
    }
    parts.push(chord.key);
    return parts.join("+");
}

function sameChord(left, right) {
    if (!left || !right || left.key !== right.key)
        return false;
    var a = left.modifiers || [];
    var b = right.modifiers || [];
    if (a.length !== b.length)
        return false;
    for (var index = 0; index < a.length; index++) {
        if (a[index] !== b[index])
            return false;
    }
    return true;
}

function parseMap(text) {
    if (typeof text !== "string" || text.trim() === "")
        return {};
    try {
        var parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return {};
        return parsed;
    } catch (error) {
        return {};
    }
}

function conflict(map, id, chord) {
    var keys = Object.keys(map || {});
    for (var index = 0; index < keys.length; index++) {
        if (keys[index] === id)
            continue;
        if (sameChord(map[keys[index]], chord))
            return keys[index];
    }
    return "";
}

function reduceRecorder(state, action) {
    var current = state && state.phase ? state : emptyRecorder();
    var type = action && action.type;
    if (type === "start")
        return { phase: "recording", id: action.id, modifiers: [], key: "", error: "" };
    if (type === "cancel" || (type === "key" && action.key === "Escape"))
        return emptyRecorder();
    if (current.phase !== "recording")
        return current;
    if (type === "key") {
        var chord = normalizeChord(action.modifiers, action.key);
        if (!chord)
            return { phase: "recording", id: current.id, modifiers: [], key: "", error: "That key is not stored." };
        var other = conflict(action.map || {}, current.id, chord);
        if (other)
            return { phase: "recording", id: current.id, modifiers: chord.modifiers, key: chord.key, error: "Already used by " + other + "." };
        return { phase: "recording", id: current.id, modifiers: chord.modifiers, key: chord.key, error: "" };
    }
    if (type === "confirm") {
        if (!current.key)
            return { phase: "recording", id: current.id, modifiers: current.modifiers, key: "", error: "Press a key first." };
        return {
            phase: "idle",
            id: "",
            modifiers: [],
            key: "",
            error: "",
            saved: { id: current.id, modifiers: current.modifiers.slice(), key: current.key },
        };
    }
    return current;
}

var swiftshellShortcuts = {
    ACTIONS: ACTIONS,
    chordText: chordText,
    normalizeChord: normalizeChord,
    parseMap: parseMap,
    conflict: conflict,
    emptyRecorder: emptyRecorder,
    reduceRecorder: reduceRecorder,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellShortcuts;
