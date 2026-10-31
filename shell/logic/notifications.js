var HISTORY_CAP = 40;
var BANNER_CAP = 4;

function emptyCenter() {
    return { ownership: "off", dnd: false, policies: {}, live: [], history: [], sequence: 1 };
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

function actionRecords(actions) {
    const source = Array.isArray(actions) ? actions : [];
    const out = [];
    for (let i = 0; i < source.length && out.length < 4; i++) {
        const item = source[i];
        const text = typeof item === "string" ? item : (item && (item.text || item.identifier));
        const identifier = item && typeof item.identifier === "string" ? item.identifier : "";
        const name = clip(text, 32);
        if (name !== "")
            out.push({ text: name, identifier: identifier });
    }
    return out;
}

function expireMs(timeoutSeconds) {
    const value = Number(timeoutSeconds);
    if (value === 0)
        return 0;
    if (!Number.isFinite(value) || value < 0)
        return 5000;
    return Math.max(1000, Math.round(value * 1000));
}

function nativeClose(native, kind) {
    if (!native)
        return "missing";
    if (kind === "expire" && typeof native.expire === "function") {
        native.expire();
        return "expire";
    }
    if (typeof native.dismiss === "function") {
        native.dismiss();
        return "dismiss";
    }
    return "missing";
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
        actions: actionRecords(source.actions),
        expireMs: expireMs(source.expireTimeout),
        preview: source.preview === true,
    };
}

function clone(state) {
    const current = state && Array.isArray(state.live) ? state : emptyCenter();
    return {
        ownership: current.ownership === "on" ? "on" : "off",
        dnd: current.dnd === true,
        policies: current.policies && typeof current.policies === "object" ? current.policies : {},
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

function parsePolicies(text) {
    if (typeof text !== "string" || text.trim() === "")
        return {};
    try {
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return {};
        const out = {};
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
            if (parsed[keys[i]] === "quiet" || parsed[keys[i]] === "hide" || parsed[keys[i]] === "show")
                out[keys[i]] = parsed[keys[i]];
        }
        return out;
    } catch (error) {
        return {};
    }
}

function policyFor(policies, desktopEntry) {
    const key = typeof desktopEntry === "string" ? desktopEntry : "";
    const value = policies && policies[key];
    if (value === "quiet" || value === "hide")
        return value;
    return "show";
}

function placement(next, item) {
    const policy = policyFor(next.policies, item.desktopEntry);
    if (policy === "hide")
        return "drop";
    if (item.urgency === "critical" || (policy === "show" && !(next.dnd === true)))
        return "banner";
    return "history";
}

function policyRows(text) {
    const policies = parsePolicies(text);
    const keys = Object.keys(policies);
    const out = [];
    for (let i = 0; i < keys.length; i++)
        out.push({ id: keys[i], value: policies[keys[i]] });
    return out;
}

function groupHistory(history) {
    const source = Array.isArray(history) ? history : [];
    const groups = [];
    for (let i = 0; i < source.length; i++) {
        const item = source[i];
        const app = item && item.appName ? item.appName : "Application";
        let group = null;
        for (let g = 0; g < groups.length; g++) {
            if (groups[g].app === app) {
                group = groups[g];
                break;
            }
        }
        if (!group) {
            group = { app: app, items: [] };
            groups.push(group);
        }
        group.items.push(item);
    }
    return groups;
}

function reduceNotifications(state, action) {
    const next = clone(state);
    const type = action && action.type;
    if (type === "configure") {
        const was = next.ownership;
        next.ownership = action.ownership === "on" ? "on" : "off";
        next.dnd = action.dnd === true;
        if (action.policies !== undefined)
            next.policies = parsePolicies(typeof action.policies === "string" ? action.policies : JSON.stringify(action.policies));
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
        const place = placement(next, item);
        if (place === "drop")
            return next;
        if (index !== -1) {
            if (place === "banner")
                next.live[index] = item;
            else {
                const kept = [];
                for (let i = 0; i < next.live.length; i++) {
                    if (i !== index)
                        kept.push(next.live[i]);
                }
                next.live = kept;
                remember(next, item);
            }
        } else if (place === "banner" && next.live.length < BANNER_CAP)
            next.live = next.live.concat([item]);
        else
            remember(next, item);
        return next;
    }
    if (type === "dismiss" || type === "expire" || type === "closed") {
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
    parsePolicies: parsePolicies,
    policyFor: policyFor,
    groupHistory: groupHistory,
    policyRows: policyRows,
    expireMs: expireMs,
    nativeClose: nativeClose,
    actionRecords: actionRecords,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellNotifications;
