var HISTORY_CAP = 40;
var BANNER_CAP = 4;

function emptyCenter() {
    return { ownership: "off", dnd: false, live: [], history: [], sequence: 1 };
}

function clip(value, max) {
    if (typeof value !== "string")
        return "";
    const text = value.replace(/\0/g, "").trim();
    return text.length > max ? text.slice(0, max - 3) + "..." : text;
}

function urgencyOf(value) {
    return value === "critical" ? "critical" : "normal";
}

function actionNames(actions) {
    const source = Array.isArray(actions) ? actions : [];
    const out = [];
    for (let i = 0; i < source.length && out.length < 4; i++) {
        const item = source[i];
        const text = typeof item === "string" ? item : (item && (item.text || item.identifier));
        const name = clip(text, 32);
        if (name !== "")
            out.push(name);
    }
    return out;
}

function entryFrom(raw, sequence) {
    const source = raw || {};
    return {
        id: typeof source.id === "number" && Number.isFinite(source.id) ? source.id : sequence,
        appName: clip(source.appName, 80) || "Application",
        summary: clip(source.summary, 140) || "Notification",
        body: clip(source.body, 280),
        urgency: urgencyOf(source.urgency),
        desktopEntry: clip(source.desktopEntry, 128),
        actions: actionNames(source.actions),
        preview: source.preview === true,
    };
}

function clone(state) {
    const current = state && Array.isArray(state.live) ? state : emptyCenter();
    return {
        ownership: current.ownership === "on" ? "on" : "off",
        dnd: current.dnd === true,
        live: current.live.slice(),
        history: current.history.slice(),
        sequence: typeof current.sequence === "number" ? current.sequence : 1,
    };
}

function remember(next, item) {
    if (item.preview === true)
        return;
    next.history = [item].concat(next.history).slice(0, HISTORY_CAP);
}

function showBanner(next, item) {
    if (next.dnd === true && item.urgency !== "critical")
        return false;
    return true;
}

function reduceNotifications(state, action) {
    const next = clone(state);
    const type = action && action.type;
    if (type === "configure") {
        const was = next.ownership;
        next.ownership = action.ownership === "on" ? "on" : "off";
        next.dnd = action.dnd === true;
        if (next.ownership !== "on" && was === "on") {
            for (let i = 0; i < next.live.length; i++)
                remember(next, next.live[i]);
            next.live = [];
        }
        return next;
    }
    if (type === "clear-history") {
        next.history = [];
        return next;
    }
    if (next.ownership !== "on")
        return next;
    if (type === "receive" || type === "preview") {
        const item = entryFrom(type === "preview" ? Object.assign({}, action.notification, { preview: true, id: -1 }) : action.notification, next.sequence);
        if (type === "receive")
            next.sequence += 1;
        let index = -1;
        if (item.preview !== true) {
            for (let i = 0; i < next.live.length; i++) {
                if (next.live[i].id === item.id) {
                    index = i;
                    break;
                }
            }
        }
        if (index !== -1)
            next.live[index] = item;
        else if (showBanner(next, item) && next.live.length < BANNER_CAP)
            next.live = next.live.concat([item]);
        else
            remember(next, item);
        return next;
    }
    if (type === "dismiss" || type === "expire") {
        const kept = [];
        for (let i = 0; i < next.live.length; i++) {
            if (next.live[i].id === action.id)
                remember(next, next.live[i]);
            else
                kept.push(next.live[i]);
        }
        next.live = kept;
        return next;
    }
    return next;
}

function shouldTrack(state) {
    return !!(state && state.ownership === "on");
}

var swiftshellNotifications = {
    HISTORY_CAP: HISTORY_CAP,
    BANNER_CAP: BANNER_CAP,
    emptyCenter: emptyCenter,
    reduceNotifications: reduceNotifications,
    shouldTrack: shouldTrack,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellNotifications;
