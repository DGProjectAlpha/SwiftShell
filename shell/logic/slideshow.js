function emptySession() {
    return {
        state: "disabled",
        paths: [],
        order: [],
        index: 0,
        shown: "",
        incoming: "",
        outgoing: "",
        error: "",
        count: 0,
        unreadable: 0,
        transitionMs: 0,
        intervalMinutes: 30,
        mode: "sequential",
    };
}

function copySession(session) {
    var source = session || emptySession();
    return {
        state: source.state,
        paths: (source.paths || []).slice(),
        order: (source.order || []).slice(),
        index: source.index || 0,
        shown: source.shown || "",
        incoming: source.incoming || "",
        outgoing: source.outgoing || "",
        error: source.error || "",
        count: source.count || 0,
        unreadable: source.unreadable || 0,
        transitionMs: source.transitionMs || 0,
        intervalMinutes: source.intervalMinutes || 30,
        mode: source.mode === "shuffle" ? "shuffle" : "sequential",
    };
}

function parseList(text) {
    if (typeof text !== "string" || text.trim() === "")
        return [];
    try {
        var parsed = JSON.parse(text);
        if (!Array.isArray(parsed))
            return [];
        var out = [];
        for (var index = 0; index < parsed.length; index++) {
            if (typeof parsed[index] === "string")
                out.push(parsed[index]);
        }
        return out;
    } catch (error) {
        return [];
    }
}

function filterPaths(paths, resolveSource) {
    var good = [];
    var unreadable = 0;
    var list = paths || [];
    for (var index = 0; index < list.length; index++) {
        var choice = resolveSource(list[index]);
        if (choice && choice.source === "file")
            good.push(choice.path);
        else
            unreadable += 1;
    }
    return { good: good, unreadable: unreadable };
}

function buildOrder(length, mode, shown, paths, random) {
    var order = [];
    var index;
    for (index = 0; index < length; index++)
        order.push(index);
    if (mode !== "shuffle")
        return order;
    var roll = typeof random === "function" ? random : Math.random;
    for (index = length - 1; index > 0; index--) {
        var swap = Math.floor(roll() * (index + 1));
        if (swap < 0 || swap > index)
            swap = index;
        var held = order[index];
        order[index] = order[swap];
        order[swap] = held;
    }
    if (length > 1 && paths[order[0]] === shown) {
        var first = order[0];
        order[0] = order[1];
        order[1] = first;
    }
    return order;
}

function nextIndex(session) {
    if (!session.order || session.order.length === 0)
        return 0;
    var index = (session.index + 1) % session.order.length;
    var guard = 0;
    while (session.paths[session.order[index]] === session.shown && guard < session.order.length) {
        index = (index + 1) % session.order.length;
        guard += 1;
    }
    return index;
}

function indexForPath(session, path) {
    if (!session || !session.order || !session.paths)
        return -1;
    for (var index = 0; index < session.order.length; index++) {
        if (session.paths[session.order[index]] === path)
            return index;
    }
    return -1;
}

function intervalMs(minutes) {
    var value = Number(minutes);
    if (!Number.isFinite(value))
        return 60000;
    return Math.max(60000, Math.round(value) * 60000);
}

function barrierComplete(expected, reports, generation) {
    var outputs = expected || [];
    var values = reports || {};
    if (outputs.length === 0)
        return true;
    for (var index = 0; index < outputs.length; index++) {
        if (values[outputs[index]] !== generation)
            return false;
    }
    return true;
}

function applyTiming(current, action) {
    if (action.transitionMs !== undefined)
        current.transitionMs = Number(action.transitionMs) > 0 ? Math.round(action.transitionMs) : 0;
    if (action.intervalMinutes !== undefined)
        current.intervalMinutes = Number(action.intervalMinutes) > 0 ? Math.round(action.intervalMinutes) : 30;
    if (current.state === "transitioning" && current.transitionMs === 0) {
        current.shown = current.incoming || current.shown;
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
    }
    return current;
}

function applyPaths(current, action, tools) {
    var resolveSource = tools.resolveSource || function () { return { source: "packaged" }; };
    var filtered = filterPaths(action.paths, resolveSource);
    var enabled = action.enabled === true;
    var previousState = current.state;
    var previousShown = current.shown;
    var previousIncoming = current.incoming;
    if (action.transitionMs !== undefined || action.intervalMinutes !== undefined)
        applyTiming(current, action);
    current.mode = action.mode === "shuffle" ? "shuffle" : "sequential";
    current.unreadable = filtered.unreadable;
    if (!enabled) {
        current.state = "disabled";
        current.paths = [];
        current.order = [];
        current.index = 0;
        current.shown = "";
        current.incoming = "";
        current.outgoing = "";
        current.count = 0;
        current.error = "";
        return current;
    }
    if (filtered.good.length === 0) {
        current.state = "error";
        current.paths = [];
        current.order = [];
        current.index = 0;
        current.shown = "";
        current.incoming = "";
        current.outgoing = "";
        current.count = 0;
        current.error = "Add at least one png, jpeg, or webp file.";
        return current;
    }
    current.paths = filtered.good;
    current.count = filtered.good.length;
    current.order = buildOrder(filtered.good.length, current.mode, previousShown, filtered.good, tools.random);
    var shownIndex = indexForPath(current, previousShown);
    if (shownIndex === -1) {
        current.index = 0;
        current.shown = filtered.good[current.order[0]];
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
    } else {
        current.shown = previousShown;
        current.index = shownIndex;
        var incomingIndex = indexForPath(current, previousIncoming);
        if ((previousState === "preloading" || previousState === "transitioning") && incomingIndex !== -1) {
            current.index = incomingIndex;
            current.incoming = previousIncoming;
            current.outgoing = previousState === "transitioning" ? previousShown : "";
            current.state = previousState;
        } else {
            current.incoming = "";
            current.outgoing = "";
            current.state = previousState === "paused" ? "paused" : "waiting";
        }
    }
    current.error = "";
    return current;
}

function reduceSlideshow(session, action, deps) {
    var current = copySession(session);
    var type = action && action.type;
    var tools = deps || {};
    if (type === "scan") {
        current.state = "scanning";
        current.error = "";
        current.incoming = "";
        return current;
    }
    if (type === "scanned" || type === "configure" || type === "updatePaths" || type === "updateMode")
        return applyPaths(current, action, tools);
    if (type === "updateTiming")
        return applyTiming(current, action);
    if (type === "tick") {
        if (current.state !== "waiting" && current.state !== "ready")
            return current;
        if (current.paths.length < 2)
            return current;
        var index = nextIndex(current);
        var incoming = current.paths[current.order[index]];
        if (!incoming || incoming === current.shown)
            return current;
        current.index = index;
        current.incoming = incoming;
        current.state = "preloading";
        current.error = "";
        return current;
    }
    if (type === "loaded") {
        if (current.state !== "preloading")
            return current;
        if (current.transitionMs > 0) {
            current.outgoing = current.shown;
            current.state = "transitioning";
            return current;
        }
        current.shown = current.incoming;
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
        return current;
    }
    if (type === "finish") {
        if (current.state !== "transitioning")
            return current;
        current.shown = current.incoming || current.shown;
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
        return current;
    }
    if (type === "failed") {
        if (current.state !== "preloading" && current.state !== "transitioning")
            return current;
        var failedPath = current.incoming;
        var kept = [];
        for (var failedIndex = 0; failedIndex < current.paths.length; failedIndex++) {
            if (current.paths[failedIndex] !== failedPath)
                kept.push(current.paths[failedIndex]);
        }
        current.paths = kept;
        current.count = kept.length;
        current.order = buildOrder(kept.length, current.mode, current.shown, kept, tools.random);
        current.index = Math.max(0, indexForPath(current, current.shown));
        current.unreadable += 1;
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
        current.error = "An unreadable next image was removed. The current image stays.";
        return current;
    }
    if (type === "shownFailed") {
        if (!current.shown || action.path !== current.shown)
            return current;
        var remaining = [];
        for (var pathIndex = 0; pathIndex < current.paths.length; pathIndex++) {
            if (current.paths[pathIndex] !== current.shown)
                remaining.push(current.paths[pathIndex]);
        }
        current.unreadable += 1;
        current.incoming = "";
        current.outgoing = "";
        if (remaining.length === 0) {
            current.paths = [];
            current.order = [];
            current.index = 0;
            current.shown = "";
            current.count = 0;
            current.state = "error";
            current.error = "No slideshow image could be decoded.";
            return current;
        }
        current.paths = remaining;
        current.count = remaining.length;
        current.order = buildOrder(remaining.length, current.mode, "", remaining, tools.random);
        current.index = 0;
        current.shown = remaining[current.order[0]];
        current.state = "waiting";
        current.error = "An unreadable slideshow image was skipped.";
        return current;
    }
    if (type === "pause") {
        if (current.state !== "waiting" && current.state !== "ready")
            return current;
        current.state = "paused";
        return current;
    }
    if (type === "resume") {
        if (current.state !== "paused")
            return current;
        current.state = "waiting";
        return current;
    }
    return current;
}

var swiftshellSlideshow = {
    emptySession: emptySession,
    parseList: parseList,
    intervalMs: intervalMs,
    barrierComplete: barrierComplete,
    reduceSlideshow: reduceSlideshow,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSlideshow;
