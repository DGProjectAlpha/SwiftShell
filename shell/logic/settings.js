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

var BAR_MODULES = ["workspaces", "title", "search", "clock", "control"];

function normalizeModuleOrder(order) {
    const source = asList(order);
    const out = [];
    for (let i = 0; i < source.length; i++) {
        if (BAR_MODULES.indexOf(source[i]) === -1 || out.indexOf(source[i]) !== -1)
            continue;
        out.push(source[i]);
    }
    for (let i = 0; i < BAR_MODULES.length; i++) {
        if (out.indexOf(BAR_MODULES[i]) === -1)
            out.push(BAR_MODULES[i]);
    }
    return out;
}

function moduleOrderValid(order) {
    const source = asList(order);
    if (source.length !== BAR_MODULES.length)
        return false;
    const seen = [];
    for (let i = 0; i < source.length; i++) {
        if (BAR_MODULES.indexOf(source[i]) === -1 || seen.indexOf(source[i]) !== -1)
            return false;
        seen.push(source[i]);
    }
    return seen.length === BAR_MODULES.length;
}

function normalizeHiddenModules(hidden) {
    const source = asList(hidden);
    const out = [];
    for (let i = 0; i < source.length; i++) {
        if (BAR_MODULES.indexOf(source[i]) === -1 || out.indexOf(source[i]) !== -1)
            continue;
        out.push(source[i]);
    }
    return out;
}

function hiddenModulesValid(hidden) {
    const source = asList(hidden);
    return normalizeHiddenModules(source).length === source.length;
}

var DEFAULTS = {
    version: 3,
    clock: {
        use24Hour: true,
        showWeekNumbers: false,
        weekStart: "locale",
    },
    bar: {
        targetMonitor: "",
        reserveSpace: true,
        showFocusedTitle: true,
        workspaceIds: [],
        workspaceDispatch: "auto",
        height: 28,
        moduleOrder: ["workspaces", "title", "search", "clock", "control"],
        hiddenModules: [],
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
        automaticText: false,
        automaticGradient: false,
        manualText: "",
        manualMuted: "",
        manualPanel: "",
        manualGradient: "",
    },
    launcher: {
        pinnedIds: [],
    },
    wallpaper: {
        enabled: true,
        fit: "cover",
        path: "",
        outputsJson: "{}",
        slideshow: false,
        intervalMinutes: 30,
        order: "sequential",
        transitionMs: 400,
        slidesJson: "[]",
    },
    settingsWindow: {
        width: 900,
        height: 620,
        category: "appearance",
    },
    extensionsJson: "{}",
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

    if (source.version !== undefined && source.version !== 1 && source.version !== 2 && source.version !== 3)
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
    } else if (typeof bar.targetMonitor === "string") {
        targetMonitor = bar.targetMonitor.trim();
    } else {
        errors.push("bar.targetMonitor");
        targetMonitor = DEFAULTS.bar.targetMonitor;
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
    const barHeight = pickInt(bar, "height", 22, 52, DEFAULTS.bar.height, errors, "bar.height");
    let moduleOrder = DEFAULTS.bar.moduleOrder.slice();
    if (bar.moduleOrder === undefined) {
        moduleOrder = DEFAULTS.bar.moduleOrder.slice();
    } else if (moduleOrderValid(bar.moduleOrder)) {
        moduleOrder = normalizeModuleOrder(bar.moduleOrder);
    } else {
        errors.push("bar.moduleOrder");
        moduleOrder = normalizeModuleOrder(bar.moduleOrder);
    }
    let hiddenModules = DEFAULTS.bar.hiddenModules.slice();
    if (bar.hiddenModules === undefined) {
        hiddenModules = DEFAULTS.bar.hiddenModules.slice();
    } else if (hiddenModulesValid(bar.hiddenModules)) {
        hiddenModules = normalizeHiddenModules(bar.hiddenModules);
    } else {
        errors.push("bar.hiddenModules");
        hiddenModules = normalizeHiddenModules(bar.hiddenModules);
    }

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
    const automaticText = pickBoolean(appearance, "automaticText", DEFAULTS.appearance.automaticText, errors, "appearance.automaticText");
    const automaticGradient = pickBoolean(appearance, "automaticGradient", DEFAULTS.appearance.automaticGradient, errors, "appearance.automaticGradient");
    const manualText = hexColor(appearance.manualText, errors, "appearance.manualText");
    const manualMuted = hexColor(appearance.manualMuted, errors, "appearance.manualMuted");
    const manualPanel = hexColor(appearance.manualPanel, errors, "appearance.manualPanel");
    const manualGradient = hexColor(appearance.manualGradient, errors, "appearance.manualGradient");

    const launcher = isPlainObject(source.launcher) ? source.launcher : {};
    if (source.launcher !== undefined && !isPlainObject(source.launcher))
        errors.push("launcher");

    const windowSource = isPlainObject(source.settingsWindow) ? source.settingsWindow : {};
    if (source.settingsWindow !== undefined && !isPlainObject(source.settingsWindow))
        errors.push("settingsWindow");
    const settingsWindowWidth = pickInt(windowSource, "width", 640, 1600, DEFAULTS.settingsWindow.width, errors, "settingsWindow.width");
    const settingsWindowHeight = pickInt(windowSource, "height", 440, 1200, DEFAULTS.settingsWindow.height, errors, "settingsWindow.height");
    const settingsWindowCategory = pickEnum(windowSource, "category", ["appearance", "bar", "wallpaper"], DEFAULTS.settingsWindow.category, errors, "settingsWindow.category");

    let pinnedIds = DEFAULTS.launcher.pinnedIds.slice();
    if (!isPlainObject(source.launcher) || launcher.pinnedIds === undefined) {
        pinnedIds = DEFAULTS.launcher.pinnedIds.slice();
    } else if (pinnedIdsValid(launcher.pinnedIds)) {
        pinnedIds = normalizePinnedIds(launcher.pinnedIds);
    } else {
        errors.push("launcher.pinnedIds");
        pinnedIds = normalizePinnedIds(launcher.pinnedIds);
    }

    const wallpaper = isPlainObject(source.wallpaper) ? source.wallpaper : {};
    if (source.wallpaper !== undefined && !isPlainObject(source.wallpaper))
        errors.push("wallpaper");
    const wallpaperEnabled = pickBoolean(wallpaper, "enabled", DEFAULTS.wallpaper.enabled, errors, "wallpaper.enabled");
    const wallpaperFit = pickEnum(wallpaper, "fit", ["cover", "contain"], DEFAULTS.wallpaper.fit, errors, "wallpaper.fit");
    const wallpaperPath = wallpaperPathValue(wallpaper.path, errors);
    const wallpaperOutputs = wallpaperOutputsValue(wallpaper.outputsJson, errors);
    const slideshow = pickBoolean(wallpaper, "slideshow", DEFAULTS.wallpaper.slideshow, errors, "wallpaper.slideshow");
    const intervalMinutes = pickInt(wallpaper, "intervalMinutes", 1, 720, DEFAULTS.wallpaper.intervalMinutes, errors, "wallpaper.intervalMinutes");
    const wallpaperOrder = pickEnum(wallpaper, "order", ["sequential", "shuffle"], DEFAULTS.wallpaper.order, errors, "wallpaper.order");
    const transitionMs = pickInt(wallpaper, "transitionMs", 0, 1000, DEFAULTS.wallpaper.transitionMs, errors, "wallpaper.transitionMs");
    const slidesJson = slidesValue(wallpaper.slidesJson, errors);

    const extensionsJson = extensionsText(source, errors);

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
                height: barHeight,
                moduleOrder: moduleOrder,
                hiddenModules: hiddenModules,
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
                automaticText: automaticText,
                automaticGradient: automaticGradient,
                manualText: manualText,
                manualMuted: manualMuted,
                manualPanel: manualPanel,
                manualGradient: manualGradient,
            },
            launcher: {
                pinnedIds: pinnedIds,
            },
            wallpaper: {
                enabled: wallpaperEnabled,
                fit: wallpaperFit,
                path: wallpaperPath,
                outputsJson: wallpaperOutputs,
                slideshow: slideshow,
                intervalMinutes: intervalMinutes,
                order: wallpaperOrder,
                transitionMs: transitionMs,
                slidesJson: slidesJson,
            },
            settingsWindow: {
                width: settingsWindowWidth,
                height: settingsWindowHeight,
                category: settingsWindowCategory,
            },
            extensionsJson: extensionsJson,
        },
    };
}

function hexColor(value, errors, label) {
    if (value === undefined || value === "")
        return "";
    if (typeof value !== "string" || !/^#[0-9A-Fa-f]{6}$/.test(value.trim())) {
        errors.push(label);
        return "";
    }
    return value.trim().toLowerCase();
}

function slidesValue(text, errors) {
    if (text === undefined || text === "")
        return "[]";
    if (typeof text !== "string") {
        errors.push("wallpaper.slidesJson");
        return "[]";
    }
    try {
        const parsed = JSON.parse(text);
        if (!Array.isArray(parsed)) {
            errors.push("wallpaper.slidesJson");
            return "[]";
        }
        const out = [];
        for (let i = 0; i < parsed.length && out.length < 64; i++) {
            const cleaned = wallpaperPathValue(parsed[i], []);
            if (cleaned !== "")
                out.push(cleaned);
        }
        const encoded = JSON.stringify(out);
        if (encoded.length > 8192) {
            errors.push("wallpaper.slidesJson");
            return "[]";
        }
        return encoded;
    } catch (error) {
        errors.push("wallpaper.slidesJson");
        return "[]";
    }
}

function wallpaperPathValue(path, errors) {
    if (path === undefined || path === "")
        return "";
    if (typeof path !== "string") {
        errors.push("wallpaper.path");
        return "";
    }
    const trimmed = path.trim();
    if (trimmed === "")
        return "";
    if (trimmed.indexOf("\0") !== -1 || trimmed.indexOf("..") !== -1 || !/\.(png|jpe?g|webp)$/i.test(trimmed)) {
        errors.push("wallpaper.path");
        return "";
    }
    return trimmed;
}

function wallpaperOutputsValue(text, errors) {
    if (text === undefined || text === "")
        return "{}";
    if (typeof text !== "string") {
        errors.push("wallpaper.outputsJson");
        return "{}";
    }
    try {
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
            errors.push("wallpaper.outputsJson");
            return "{}";
        }
        const out = {};
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
            if (typeof parsed[keys[i]] !== "string" || keys[i].indexOf("\0") !== -1)
                continue;
            const cleaned = wallpaperPathValue(parsed[keys[i]], []);
            if (cleaned !== "")
                out[keys[i]] = cleaned;
        }
        const encoded = JSON.stringify(out);
        if (encoded.length > 4096) {
            errors.push("wallpaper.outputsJson");
            return "{}";
        }
        return encoded;
    } catch (error) {
        errors.push("wallpaper.outputsJson");
        return "{}";
    }
}

function pickInt(source, key, min, max, fallback, errors, label) {
    if (source[key] === undefined)
        return fallback;
    if (typeof source[key] === "number" && Number.isInteger(source[key]) && source[key] >= min && source[key] <= max)
        return source[key];
    errors.push(label);
    if (typeof source[key] === "number" && Number.isFinite(source[key]))
        return Math.max(min, Math.min(max, Math.round(source[key])));
    return fallback;
}

function jsonSafe(value, depth) {
    if (depth > 6)
        return undefined;
    if (value === null || typeof value === "boolean" || typeof value === "string")
        return value;
    if (typeof value === "number")
        return Number.isFinite(value) ? value : undefined;
    if (Array.isArray(value)) {
        const out = [];
        for (let i = 0; i < value.length; i++) {
            const next = jsonSafe(value[i], depth + 1);
            if (next !== undefined)
                out.push(next);
        }
        return out;
    }
    if (isPlainObject(value)) {
        const out = {};
        const keys = Object.keys(value);
        for (let i = 0; i < keys.length; i++) {
            const next = jsonSafe(value[keys[i]], depth + 1);
            if (next !== undefined)
                out[keys[i]] = next;
        }
        return out;
    }
    return undefined;
}

function extensionsText(source, errors) {
    const known = {
        version: true,
        clock: true,
        bar: true,
        appearance: true,
        launcher: true,
        wallpaper: true,
        settingsWindow: true,
        extensionsJson: true,
    };
    const found = {};
    if (isPlainObject(source)) {
        const keys = Object.keys(source);
        for (let i = 0; i < keys.length; i++) {
            if (known[keys[i]])
                continue;
            const next = jsonSafe(source[keys[i]], 0);
            if (next !== undefined)
                found[keys[i]] = next;
        }
    }

    let existing = {};
    if (isPlainObject(source) && source.extensionsJson !== undefined) {
        if (typeof source.extensionsJson !== "string") {
            errors.push("extensionsJson");
        } else {
            try {
                const parsed = JSON.parse(source.extensionsJson);
                if (isPlainObject(parsed))
                    existing = parsed;
                else
                    errors.push("extensionsJson");
            } catch (error) {
                errors.push("extensionsJson");
            }
        }
    }

    const merged = jsonSafe(Object.assign({}, existing, found), 0) || {};
    const text = JSON.stringify(merged);
    if (text.length > 4096) {
        errors.push("extensionsJson");
        return "{}";
    }
    return text;
}

function migrationDecision(input) {
    if (!isPlainObject(input))
        return { action: "keep", reason: "unreadable", errors: ["settings"] };
    const validated = validateSettings(input);
    if (!validated.ok)
        return { action: "keep", reason: "invalid", errors: validated.errors, settings: validated.settings };
    if (input.version === 3)
        return { action: "keep", reason: "current", errors: [], settings: validated.settings };
    return {
        action: "migrate",
        reason: "version",
        errors: [],
        backupText: JSON.stringify(input, null, 2) + "\n",
        settings: validated.settings,
    };
}

function backupPath(settingsPath) {
    if (typeof settingsPath !== "string" || settingsPath.indexOf("\0") !== -1 || settingsPath === "")
        return "";
    return settingsPath + ".bak-swiftshell";
}

function opacityFromUnit(unit) {
    const t = typeof unit === "number" && Number.isFinite(unit) ? Math.min(1, Math.max(0, unit)) : 0;
    return Math.round((0.72 + t * 0.24) * 1000) / 1000;
}

function unitFromOpacity(opacity) {
    if (typeof opacity !== "number" || !Number.isFinite(opacity))
        return 0;
    return Math.min(1, Math.max(0, (opacity - 0.72) / 0.24));
}

function radiusFromUnit(unit) {
    const t = typeof unit === "number" && Number.isFinite(unit) ? Math.min(1, Math.max(0, unit)) : 0;
    return Math.round(6 + t * 6);
}

function unitFromRadius(radius) {
    if (typeof radius !== "number" || !Number.isFinite(radius))
        return 0;
    return Math.min(1, Math.max(0, (radius - 6) / 6));
}

function copyAppearance(value) {
    return validateSettings({ appearance: value }).settings.appearance;
}

function initialHistory(present) {
    return { past: [], present: copyAppearance(present) };
}

function reduceAppearanceHistory(state, action) {
    const past = state && Array.isArray(state.past) ? state.past.slice() : [];
    const present = state && state.present ? copyAppearance(state.present) : copyAppearance(undefined);
    const type = action && action.type;
    if (type === "replace")
        return { past: [], present: copyAppearance(action.present) };
    if (type === "edit") {
        const next = copyAppearance(action.present);
        if (JSON.stringify(next) === JSON.stringify(present))
            return { past: past, present: present };
        past.push(present);
        if (past.length > 20)
            past.shift();
        return { past: past, present: next };
    }
    if (type === "undo") {
        if (past.length === 0)
            return { past: [], present: present };
        const restored = past.pop();
        return { past: past, present: copyAppearance(restored) };
    }
    if (type === "reset") {
        const next = copyAppearance(DEFAULTS.appearance);
        if (JSON.stringify(next) === JSON.stringify(present))
            return { past: past, present: present };
        past.push(present);
        if (past.length > 20)
            past.shift();
        return { past: past, present: next };
    }
    return { past: past, present: present };
}

function serializeSettings(settings) {
    const validated = validateSettings(settings);
    return JSON.stringify(validated.settings, null, 2) + "\n";
}

var swiftshellSettings = {
    DEFAULTS: DEFAULTS,
    validateSettings: validateSettings,
    serializeSettings: serializeSettings,
    migrationDecision: migrationDecision,
    backupPath: backupPath,
    opacityFromUnit: opacityFromUnit,
    unitFromOpacity: unitFromOpacity,
    radiusFromUnit: radiusFromUnit,
    unitFromRadius: unitFromRadius,
    initialHistory: initialHistory,
    reduceAppearanceHistory: reduceAppearanceHistory,
    normalizeWorkspaceIds: normalizeWorkspaceIds,
    normalizePinnedIds: normalizePinnedIds,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSettings;
