var DEFAULT_WORKSPACE_IDS = [4, 5, 6];
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

    if (cleaned.length === 0)
        return DEFAULT_WORKSPACE_IDS.slice();

    return cleaned;
}

function workspaceIdsValid(ids) {
    if (!Array.isArray(ids) || ids.length === 0 || ids.length > MAX_WORKSPACE_IDS)
        return false;

    const seen = [];
    for (let i = 0; i < ids.length; i++) {
        const id = asWorkspaceId(ids[i]);
        if (id == null || id !== ids[i] && String(id) !== String(ids[i]))
            return false;
        if (typeof ids[i] !== "number" || !Number.isInteger(ids[i]))
            return false;
        if (seen.indexOf(id) !== -1)
            return false;
        seen.push(id);
    }

    return true;
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

function buildWorkspaceItems(configuredIds, liveWorkspaces, monitorName) {
    const ids = normalizeWorkspaceIds(configuredIds);
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

function dispatchWorkspaceCommand(id) {
    const workspaceId = asWorkspaceId(id);
    if (workspaceId == null || typeof id !== "number")
        return "";
    return "workspace " + workspaceId;
}

var swiftshellWorkspaces = {
    DEFAULT_WORKSPACE_IDS: DEFAULT_WORKSPACE_IDS,
    MAX_WORKSPACE_IDS: MAX_WORKSPACE_IDS,
    asWorkspaceId: asWorkspaceId,
    normalizeWorkspaceIds: normalizeWorkspaceIds,
    workspaceIdsValid: workspaceIdsValid,
    buildWorkspaceItems: buildWorkspaceItems,
    dispatchWorkspaceCommand: dispatchWorkspaceCommand,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellWorkspaces;
