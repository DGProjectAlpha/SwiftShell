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
        if (typeof ids[i] !== "number" || !Number.isInteger(ids[i]))
            return false;
        const id = asWorkspaceId(ids[i]);
        if (id == null || seen.indexOf(id) !== -1)
            return false;
        seen.push(id);
    }

    return true;
}

var DEFAULTS = {
    version: 1,
    clock: {
        use24Hour: true,
    },
    bar: {
        targetMonitor: "HDMI-A-1",
        reserveSpace: false,
        showFocusedTitle: true,
        workspaceIds: DEFAULT_WORKSPACE_IDS.slice(),
    },
};

function isPlainObject(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

function validateSettings(input) {
    const errors = [];
    const source = isPlainObject(input) ? input : {};

    if (input != null && !isPlainObject(input))
        errors.push("settings");

    if (source.version !== undefined && source.version !== 1)
        errors.push("version");

    const clock = isPlainObject(source.clock) ? source.clock : {};
    if (source.clock !== undefined && !isPlainObject(source.clock))
        errors.push("clock");

    let use24Hour = DEFAULTS.clock.use24Hour;
    if (clock.use24Hour === undefined) {
        use24Hour = DEFAULTS.clock.use24Hour;
    } else if (typeof clock.use24Hour === "boolean") {
        use24Hour = clock.use24Hour;
    } else {
        errors.push("clock.use24Hour");
    }

    const bar = isPlainObject(source.bar) ? source.bar : {};
    if (source.bar !== undefined && !isPlainObject(source.bar))
        errors.push("bar");

    let targetMonitor = DEFAULTS.bar.targetMonitor;
    if (bar.targetMonitor === undefined) {
        targetMonitor = DEFAULTS.bar.targetMonitor;
    } else if (typeof bar.targetMonitor === "string" && bar.targetMonitor.trim() !== "") {
        targetMonitor = bar.targetMonitor.trim();
    } else {
        errors.push("bar.targetMonitor");
    }

    let reserveSpace = DEFAULTS.bar.reserveSpace;
    if (bar.reserveSpace === undefined) {
        reserveSpace = DEFAULTS.bar.reserveSpace;
    } else if (typeof bar.reserveSpace === "boolean") {
        reserveSpace = bar.reserveSpace;
    } else {
        errors.push("bar.reserveSpace");
    }

    let showFocusedTitle = DEFAULTS.bar.showFocusedTitle;
    if (bar.showFocusedTitle === undefined) {
        showFocusedTitle = DEFAULTS.bar.showFocusedTitle;
    } else if (typeof bar.showFocusedTitle === "boolean") {
        showFocusedTitle = bar.showFocusedTitle;
    } else {
        errors.push("bar.showFocusedTitle");
    }

    let workspaceIds = DEFAULTS.bar.workspaceIds.slice();
    if (bar.workspaceIds === undefined) {
        workspaceIds = DEFAULTS.bar.workspaceIds.slice();
    } else if (workspaceIdsValid(bar.workspaceIds)) {
        workspaceIds = normalizeWorkspaceIds(bar.workspaceIds);
    } else {
        errors.push("bar.workspaceIds");
        workspaceIds = normalizeWorkspaceIds(bar.workspaceIds);
    }

    return {
        ok: errors.length === 0,
        errors: errors,
        settings: {
            version: DEFAULTS.version,
            clock: {
                use24Hour: use24Hour,
            },
            bar: {
                targetMonitor: targetMonitor,
                reserveSpace: reserveSpace,
                showFocusedTitle: showFocusedTitle,
                workspaceIds: workspaceIds,
            },
        },
    };
}

function serializeSettings(settings) {
    const validated = validateSettings(settings);
    return JSON.stringify(validated.settings, null, 2) + "\n";
}

var swiftshellSettings = {
    DEFAULTS: DEFAULTS,
    validateSettings: validateSettings,
    serializeSettings: serializeSettings,
    normalizeWorkspaceIds: normalizeWorkspaceIds,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSettings;
