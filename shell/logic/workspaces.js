var MAX_WORKSPACE_IDS = 12;

function asWorkspaceId(value) {
    if (typeof value === "number" && Number.isInteger(value))
        return value >= 1 && value <= 99 ? value : null;

    if (typeof value === "string" && /^[1-9][0-9]?$/.test(value))
        return Number(value);

    return null;
}

function asList(ids) {
    if (Array.isArray(ids))
        return ids;
    if (ids && typeof ids === "object" && typeof ids.length === "number") {
        const out = [];
        for (let i = 0; i < ids.length; i++)
            out.push(ids[i]);
        return out;
    }
    return [];
}

function normalizeWorkspaceIds(ids) {
    const source = asList(ids);
    const cleaned = [];

    for (let i = 0; i < source.length && cleaned.length < MAX_WORKSPACE_IDS; i++) {
        const id = asWorkspaceId(source[i]);
        if (id == null || cleaned.indexOf(id) !== -1)
            continue;
        cleaned.push(id);
    }

    return cleaned;
}

function workspaceIdsValid(ids) {
    const source = asList(ids);
    if (source.length > MAX_WORKSPACE_IDS)
        return false;
    if (ids && typeof ids === "object" && typeof ids.length === "number" && source.length !== ids.length)
        return false;
    if (source.length === 0)
        return true;

    const seen = [];
    for (let i = 0; i < source.length; i++) {
        if (typeof source[i] !== "number" || !Number.isInteger(source[i]))
            return false;
        const id = asWorkspaceId(source[i]);
        if (id == null || seen.indexOf(id) !== -1)
            return false;
        seen.push(id);
    }

    return true;
}

// Hyprland's Lua config evaluates IPC as `return hl.dispatch(<request>)`.
// `workspace 5` is a syntax error there (`')' expected near '5'`).
// The dispatcher table is what the wiki and a confirmed click test accept:
// `hl.dsp.focus({ workspace = <id> })`. The id is an integer, never a string.
function resolveDispatchMode(configured, usingLua) {
    if (configured === "lua" || configured === "legacy")
        return configured;
    if (usingLua === true)
        return "lua";
    if (usingLua === false)
        return "legacy";
    return "lua";
}

function dispatchWorkspaceCommand(id, mode, usingLua) {
    const workspaceId = asWorkspaceId(id);
    if (workspaceId == null || typeof id !== "number" || !Number.isInteger(id))
        return "";

    if (resolveDispatchMode(mode, usingLua) === "legacy")
        return "workspace " + workspaceId;

    return "hl.dsp.focus({ workspace = " + workspaceId + " })";
}

function findWorkspace(liveWorkspaces, id, monitorName) {
    let fallback = null;
    const live = Array.isArray(liveWorkspaces) ? liveWorkspaces : [];

    for (let i = 0; i < live.length; i++) {
        const workspace = live[i];
        if (!workspace || Number(workspace.id) !== id)
            continue;
        if (workspace.monitorName === monitorName)
            return workspace;
        if (fallback == null)
            fallback = workspace;
    }

    return fallback;
}

function liveIndicatorIds(liveWorkspaces, monitorName) {
    const live = Array.isArray(liveWorkspaces) ? liveWorkspaces : [];
    const monitor = typeof monitorName === "string" ? monitorName : "";
    if (monitor === "")
        return [];

    const ids = [];
    for (let i = 0; i < live.length; i++) {
        const workspace = live[i];
        if (!workspace || typeof workspace.id !== "number" || !Number.isInteger(workspace.id))
            continue;
        const id = asWorkspaceId(workspace.id);
        if (id == null || workspace.monitorName !== monitor || ids.indexOf(id) !== -1)
            continue;
        ids.push(id);
    }
    ids.sort(function (left, right) { return left - right; });
    if (ids.length > MAX_WORKSPACE_IDS)
        return ids.slice(0, MAX_WORKSPACE_IDS);
    return ids;
}

function itemsForIds(ids, liveWorkspaces, monitorName) {
    const live = Array.isArray(liveWorkspaces) ? liveWorkspaces : [];
    const monitor = typeof monitorName === "string" ? monitorName : "";

    return ids.map(function (id) {
        const match = findWorkspace(live, id, monitor);
        const onMonitor = !!(match && match.monitorName === monitor && monitor !== "");
        let urgent = false;
        for (let i = 0; i < live.length; i++) {
            if (live[i] && Number(live[i].id) === id && live[i].urgent === true)
                urgent = true;
        }

        return {
            id: id,
            name: match && match.name ? String(match.name) : String(id),
            exists: !!match,
            onMonitor: onMonitor,
            active: !!(onMonitor && match.active === true),
            focused: !!(onMonitor && match.focused === true),
            urgent: urgent,
        };
    });
}

function buildWorkspaceItems(configuredIds, liveWorkspaces, monitorName) {
    return itemsForIds(normalizeWorkspaceIds(configuredIds), liveWorkspaces, monitorName);
}

function indicatorItems(configuredIds, liveWorkspaces, monitorName) {
    const explicit = normalizeWorkspaceIds(configuredIds);
    const ids = explicit.length > 0 ? explicit : liveIndicatorIds(liveWorkspaces, monitorName);
    return itemsForIds(ids, liveWorkspaces, monitorName);
}

// Hyprland 0.57 uses string addresses, including named workspaces without ids.
function workspaceKey(value) {
    if (typeof value === "number")
        return Number.isInteger(value) && value > 0 ? String(value) : "";
    if (typeof value !== "string") return "";
    const key = value.trim().replace(/^name:/, "");
    return key.length > 0 && key.length <= 128 && !/[\x00-\x1f,]/.test(key)
        && key.indexOf("special:") !== 0 ? key : "";
}

function parseOverrides(text) {
    try {
        const source = JSON.parse(text || "{}");
        if (!source || Array.isArray(source) || typeof source !== "object") return null;
        const out = {};
        for (const monitor of Object.keys(source)) {
            const value = source[monitor];
            if (!monitor.trim() || monitor.length > 256) return null;
            if (value === null) { out[monitor] = null; continue; }
            if (!Array.isArray(value) || value.length > 32) return null;
            const keys = value.map(workspaceKey);
            if (keys.some(function (key) { return !key; }) || new Set(keys).size !== keys.length) return null;
            out[monitor] = keys;
        }
        return out;
    } catch (error) { return null; }
}

function snapshotItems(monitors, workspaces, rules) {
    const out = [];
    function add(key, monitorName, name, exists, windows) {
        if (!key || !monitorName) return;
        const monitor = monitors.find(function (m) { return m.name === monitorName; });
        const active = monitor && monitor.activeWorkspace;
        const activeKey = active ? workspaceKey(active.address || active.id || active.name) : "";
        const previous = out.find(function (w) { return w.key === key && w.monitorName === monitorName; });
        if (previous) return;
        out.push({ key: key, id: /^[1-9][0-9]*$/.test(key) ? Number(key) : -1,
            name: name || key, monitorName: monitorName, exists: exists,
            windows: windows || 0, active: activeKey === key,
            focused: activeKey === key && !!monitor && !!monitor.focused, urgent: false });
    }
    for (const w of workspaces) {
        if (w.type && w.type !== "normal") continue;
        add(workspaceKey(w.address || (w.id > 0 ? w.id : w.name)), w.monitor, w.name, true, w.windows);
    }
    for (const rule of rules) {
        if (rule.enabled === false) continue;
        // Only literal assignments; selectors and ranges are not workspace names.
        const value = String(rule.workspaceString || "");
        if (!/^[1-9][0-9]*$/.test(value) && value.indexOf("name:") !== 0) continue;
        const key = workspaceKey(value);
        if (!out.some(function (w) { return w.key === key; })) add(key, rule.monitor, key, false, 0);
    }
    for (const m of monitors) {
        const a = m.activeWorkspace;
        if (a) add(workspaceKey(a.address || a.id || a.name), m.name, a.name, true, 0);
    }
    return out.sort(function (a, b) {
        if (a.id > 0 && b.id > 0) return a.id - b.id;
        if (a.id > 0) return -1;
        if (b.id > 0) return 1;
        return a.name.localeCompare(b.name);
    });
}

function perMonitorItems(overridesJson, legacyIds, legacyTarget, live, monitorName) {
    const overrides = parseOverrides(overridesJson) || {};
    let keys = Object.prototype.hasOwnProperty.call(overrides, monitorName) ? overrides[monitorName] : null;
    if (keys === null && !Object.prototype.hasOwnProperty.call(overrides, monitorName) && legacyIds && legacyIds.length) {
        keys = normalizeWorkspaceIds(legacyIds).map(String).filter(function (key) {
            const match = live.find(function (w) { return w.key === key; });
            return match ? match.monitorName === monitorName : legacyTarget === monitorName;
        });
        if (keys.length === 0 || (legacyTarget && legacyTarget !== monitorName))
            return live.filter(function (w) { return w.monitorName === monitorName; });
        // Preserve legacy numeric selection, but never lose a live named workspace.
        keys = keys.concat(live.filter(function (w) { return w.monitorName === monitorName && w.id < 0; }).map(function (w) { return w.key; }));
    }
    if (keys === null) return live.filter(function (w) { return w.monitorName === monitorName; });
    return keys.map(function (key) {
        const match = live.find(function (w) { return w.key === key; });
        const onMonitor = match && match.monitorName === monitorName;
        return { key: key, id: /^[1-9][0-9]*$/.test(key) ? Number(key) : -1,
            name: match ? match.name : key, exists: !!match && match.exists,
            monitorName: monitorName, active: !!onMonitor && match.active,
            focused: !!onMonitor && match.focused, urgent: !!match && match.urgent,
            windows: match ? match.windows : 0, elsewhere: !!match && !onMonitor };
    });
}

function dispatchMonitorCommand(name, mode, usingLua) {
    if (typeof name !== "string" || !/^[A-Za-z0-9_.:-]+$/.test(name)) return "";
    return resolveDispatchMode(mode, usingLua) === "legacy" ? "focusmonitor " + name
        : "hl.dsp.focus({ monitor = " + JSON.stringify(name) + " })";
}

function dispatchAddressCommand(value, mode, usingLua) {
    const key = workspaceKey(value);
    if (!key) return "";
    const numeric = /^[1-9][0-9]*$/.test(key);
    if (resolveDispatchMode(mode, usingLua) === "legacy")
        return "workspace " + (numeric ? key : "name:" + key);
    // JSON quoting is also valid Lua for these strings; escape controls were rejected above.
    return "hl.dsp.focus({ workspace = " + (numeric ? key : JSON.stringify("name:" + key)) + " })";
}

var swiftshellWorkspaces = {
    MAX_WORKSPACE_IDS: MAX_WORKSPACE_IDS,
    workspaceKey: workspaceKey, parseOverrides: parseOverrides, snapshotItems: snapshotItems,
    perMonitorItems: perMonitorItems, dispatchMonitorCommand: dispatchMonitorCommand, dispatchAddressCommand: dispatchAddressCommand,
    asWorkspaceId: asWorkspaceId,
    normalizeWorkspaceIds: normalizeWorkspaceIds,
    workspaceIdsValid: workspaceIdsValid,
    resolveDispatchMode: resolveDispatchMode,
    buildWorkspaceItems: buildWorkspaceItems,
    indicatorItems: indicatorItems,
    dispatchWorkspaceCommand: dispatchWorkspaceCommand,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellWorkspaces;
