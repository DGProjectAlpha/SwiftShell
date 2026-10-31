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
    const source = asList(ids);
    if (source.length === 0 || source.length > MAX_WORKSPACE_IDS)
        return false;

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

var DEFAULTS = {
    version: 1,
    clock: {
        use24Hour: true,
        showWeekNumbers: false,
        weekStart: "locale",
    },
    bar: {
        targetMonitor: "HDMI-A-1",
        reserveSpace: true,
        showFocusedTitle: true,
        workspaceIds: DEFAULT_WORKSPACE_IDS.slice(),
        workspaceDispatch: "auto",
    },
    appearance: {
        mode: "dark",
        tint: "neutral",
        panelOpacity: 0.92,
        panelBlur: 1,
        radius: 10,
        shadowOpacity: 0.16,
        shadowSoftness: 10,
        motionScale: 1,
        reducedMotion: false,
        panelPadding: 12,
        panelSpacing: 8,
        fontSize: 12,
        fontWeight: "regular",
        iconScale: 1,
        topGradient: false,
    },
    launcher: {
        pinnedIds: [],
    },
};

function pinnedIdValid(value) {
    return typeof value === "string" && value.length > 0 && value.length <= 128 && /^[A-Za-z0-9._+-]+$/.test(value);
}

function pinnedSource(ids) {
    if (Array.isArray(ids))
        return ids;
    if (ids && typeof ids === "object" && typeof ids.length === "number") {
        const out = [];
        for (let i = 0; i < ids.length; i++)
            out.push(ids[i]);
        return out;
    }
    return null;
}

function pinnedIdsValid(ids) {
    const source = pinnedSource(ids);
    if (!source || source.length > 12)
        return false;
    const seen = [];
    for (let i = 0; i < source.length; i++) {
        if (!pinnedIdValid(source[i]) || seen.indexOf(source[i]) !== -1)
            return false;
        seen.push(source[i]);
    }
    return true;
}

function normalizePinnedIds(ids) {
    const source = pinnedSource(ids) || [];
    const out = [];
    for (let i = 0; i < source.length && out.length < 12; i++) {
        if (!pinnedIdValid(source[i]) || out.indexOf(source[i]) !== -1)
            continue;
        out.push(source[i]);
    }
    return out;
}

function isPlainObject(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

function pickBoolean(source, key, fallback, errors, label) {
    if (source[key] === undefined)
        return fallback;
    if (typeof source[key] === "boolean")
        return source[key];
    errors.push(label);
    return fallback;
}

function pickEnum(source, key, allowed, fallback, errors, label) {
    if (source[key] === undefined)
        return fallback;
    if (typeof source[key] === "string" && allowed.indexOf(source[key]) !== -1)
        return source[key];
    errors.push(label);
    return fallback;
}

function pickNumber(source, key, min, max, fallback, errors, label) {
    if (source[key] === undefined)
        return fallback;
    if (typeof source[key] === "number" && Number.isFinite(source[key]) && source[key] >= min && source[key] <= max)
        return source[key];
    errors.push(label);
    return fallback;
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

    const showWeekNumbers = pickBoolean(clock, "showWeekNumbers", DEFAULTS.clock.showWeekNumbers, errors, "clock.showWeekNumbers");
    const weekStart = pickEnum(clock, "weekStart", ["locale", "monday", "sunday"], DEFAULTS.clock.weekStart, errors, "clock.weekStart");

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

    const workspaceDispatch = pickEnum(
        bar,
        "workspaceDispatch",
        ["auto", "lua", "legacy"],
        DEFAULTS.bar.workspaceDispatch,
        errors,
        "bar.workspaceDispatch"
    );

    const appearance = isPlainObject(source.appearance) ? source.appearance : {};
    if (source.appearance !== undefined && !isPlainObject(source.appearance))
        errors.push("appearance");

    const appearanceMode = pickEnum(appearance, "mode", ["dark", "light"], DEFAULTS.appearance.mode, errors, "appearance.mode");
    const appearanceTint = pickEnum(appearance, "tint", ["neutral", "wallpaper"], DEFAULTS.appearance.tint, errors, "appearance.tint");
    const panelOpacity = pickNumber(appearance, "panelOpacity", 0.72, 0.96, DEFAULTS.appearance.panelOpacity, errors, "appearance.panelOpacity");
    const panelBlur = pickNumber(appearance, "panelBlur", 0, 1, DEFAULTS.appearance.panelBlur, errors, "appearance.panelBlur");
    const radius = pickNumber(appearance, "radius", 6, 12, DEFAULTS.appearance.radius, errors, "appearance.radius");
    const shadowOpacity = pickNumber(appearance, "shadowOpacity", 0, 0.4, DEFAULTS.appearance.shadowOpacity, errors, "appearance.shadowOpacity");
    const shadowSoftness = pickNumber(appearance, "shadowSoftness", 0, 24, DEFAULTS.appearance.shadowSoftness, errors, "appearance.shadowSoftness");
    const motionScale = pickNumber(appearance, "motionScale", 0, 1, DEFAULTS.appearance.motionScale, errors, "appearance.motionScale");
    const reducedMotion = pickBoolean(appearance, "reducedMotion", DEFAULTS.appearance.reducedMotion, errors, "appearance.reducedMotion");
    const panelPadding = pickNumber(appearance, "panelPadding", 8, 20, DEFAULTS.appearance.panelPadding, errors, "appearance.panelPadding");
    const panelSpacing = pickNumber(appearance, "panelSpacing", 4, 16, DEFAULTS.appearance.panelSpacing, errors, "appearance.panelSpacing");
    const fontSize = pickNumber(appearance, "fontSize", 11, 16, DEFAULTS.appearance.fontSize, errors, "appearance.fontSize");
    const fontWeight = pickEnum(appearance, "fontWeight", ["regular", "medium"], DEFAULTS.appearance.fontWeight, errors, "appearance.fontWeight");
    const iconScale = pickNumber(appearance, "iconScale", 0.75, 1.5, DEFAULTS.appearance.iconScale, errors, "appearance.iconScale");
    const topGradient = pickBoolean(appearance, "topGradient", DEFAULTS.appearance.topGradient, errors, "appearance.topGradient");

    const launcher = isPlainObject(source.launcher) ? source.launcher : {};
    if (source.launcher !== undefined && !isPlainObject(source.launcher))
        errors.push("launcher");

    let pinnedIds = DEFAULTS.launcher.pinnedIds.slice();
    if (!isPlainObject(source.launcher) || launcher.pinnedIds === undefined) {
        pinnedIds = DEFAULTS.launcher.pinnedIds.slice();
    } else if (pinnedIdsValid(launcher.pinnedIds)) {
        pinnedIds = normalizePinnedIds(launcher.pinnedIds);
    } else {
        errors.push("launcher.pinnedIds");
        pinnedIds = normalizePinnedIds(launcher.pinnedIds);
    }

    return {
        ok: errors.length === 0,
        errors: errors,
        settings: {
            version: DEFAULTS.version,
            clock: {
                use24Hour: use24Hour,
                showWeekNumbers: showWeekNumbers,
                weekStart: weekStart,
            },
            bar: {
                targetMonitor: targetMonitor,
                reserveSpace: reserveSpace,
                showFocusedTitle: showFocusedTitle,
                workspaceIds: workspaceIds,
                workspaceDispatch: workspaceDispatch,
            },
            appearance: {
                mode: appearanceMode,
                tint: appearanceTint,
                panelOpacity: panelOpacity,
                panelBlur: panelBlur,
                radius: radius,
                shadowOpacity: shadowOpacity,
                shadowSoftness: shadowSoftness,
                motionScale: motionScale,
                reducedMotion: reducedMotion,
                panelPadding: panelPadding,
                panelSpacing: panelSpacing,
                fontSize: fontSize,
                fontWeight: fontWeight,
                iconScale: iconScale,
                topGradient: topGradient,
            },
            launcher: {
                pinnedIds: pinnedIds,
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
    normalizePinnedIds: normalizePinnedIds,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSettings;
