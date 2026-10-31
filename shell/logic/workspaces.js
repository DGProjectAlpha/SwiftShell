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

var swiftshellWorkspaces = {
    MAX_WORKSPACE_IDS: MAX_WORKSPACE_IDS,
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
