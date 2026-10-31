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

function intervalMs(minutes) {
    var value = Number(minutes);
    if (!Number.isFinite(value))
        return 60000;
    return Math.max(60000, Math.round(value) * 60000);
}

function reduceSlideshow(session, action, deps) {
    var current = copySession(session);
    var type = action && action.type;
    var tools = deps || {};
    var resolveSource = tools.resolveSource;
    if (type === "scan") {
        current.state = "scanning";
        current.error = "";
        current.incoming = "";
        return current;
    }
    if (type === "scanned" || type === "configure") {
        var filtered = filterPaths(action.paths, resolveSource || function () { return { source: "packaged" }; });
        var enabled = action.enabled === true;
        current.transitionMs = Number(action.transitionMs) > 0 ? Math.round(action.transitionMs) : 0;
        current.intervalMinutes = Number(action.intervalMinutes) > 0 ? Math.round(action.intervalMinutes) : 30;
        current.mode = action.mode === "shuffle" ? "shuffle" : "sequential";
        current.unreadable = filtered.unreadable;
        current.incoming = "";
        current.outgoing = "";
        if (!enabled) {
            current.state = "disabled";
            current.paths = [];
            current.order = [];
            current.index = 0;
            current.shown = "";
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
            current.count = 0;
            current.error = "Add at least one png, jpeg, or webp file.";
            return current;
        }
        current.paths = filtered.good;
        current.count = filtered.good.length;
        current.order = buildOrder(filtered.good.length, current.mode, current.shown, filtered.good, tools.random);
        current.index = 0;
        current.shown = filtered.good[current.order[0]];
        current.state = "waiting";
        current.error = "";
        return current;
    }
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
        current.incoming = "";
        current.outgoing = "";
        current.state = "waiting";
        current.error = "The next image could not be decoded. The current image stays.";
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
    reduceSlideshow: reduceSlideshow,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSlideshow;
