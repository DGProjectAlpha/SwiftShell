var BAR_MODULES = ["workspaces", "title", "search", "clock", "control"];

function clamp01(unit) {
    if (typeof unit !== "number" || !Number.isFinite(unit))
        return 0;
    return Math.min(1, Math.max(0, unit));
}

function barMetrics(height, iconScale) {
    let next = typeof height === "number" && Number.isFinite(height) ? Math.round(height) : 28;
    next = Math.max(22, Math.min(52, next));
    let scale = typeof iconScale === "number" && Number.isFinite(iconScale) ? iconScale : 1;
    scale = Math.min(1.5, Math.max(0.75, scale));
    return {
        height: next,
        font: Math.max(10, Math.min(22, Math.round(next * 0.42))),
        icon: Math.max(12, Math.min(30, Math.round(next * 0.58 * scale))),
        hit: next,
        marginH: Math.max(8, Math.round(next * 0.36)),
        moduleSpacing: Math.max(8, Math.round(next * 0.43)),
        workspaceGap: Math.max(2, Math.round(next * 0.07)),
    };
}

function heightFromUnit(unit) {
    return Math.round(22 + clamp01(unit) * 30);
}

function unitFromHeight(height) {
    if (typeof height !== "number" || !Number.isFinite(height))
        return 0;
    return clamp01((height - 22) / 30);
}

function asModuleList(value) {
    if (Array.isArray(value))
        return value;
    if (value && typeof value === "object" && typeof value.length === "number") {
        const out = [];
        for (let i = 0; i < value.length; i++)
            out.push(value[i]);
        return out;
    }
    return [];
}

function normalizeModuleOrder(order) {
    const source = asModuleList(order);
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
    const source = asModuleList(order);
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
    const source = asModuleList(hidden);
    const out = [];
    for (let i = 0; i < source.length; i++) {
        if (BAR_MODULES.indexOf(source[i]) === -1 || out.indexOf(source[i]) !== -1)
            continue;
        out.push(source[i]);
    }
    return out;
}

function hiddenModulesValid(hidden) {
    const source = asModuleList(hidden);
    return normalizeHiddenModules(source).length === source.length;
}

function visibleModules(order, hidden) {
    const arranged = normalizeModuleOrder(order);
    const hide = normalizeHiddenModules(hidden);
    const out = [];
    for (let i = 0; i < arranged.length; i++) {
        if (hide.indexOf(arranged[i]) === -1)
            out.push(arranged[i]);
    }
    return out;
}

function moveModule(order, id, delta) {
    const next = normalizeModuleOrder(order);
    const index = next.indexOf(id);
    const target = index + (delta < 0 ? -1 : 1);
    if (index < 0 || target < 0 || target >= next.length)
        return next;
    const swap = next[target];
    next[target] = next[index];
    next[index] = swap;
    return next;
}

function toggleHidden(hidden, id) {
    const next = normalizeHiddenModules(hidden);
    if (BAR_MODULES.indexOf(id) === -1)
        return next;
    const index = next.indexOf(id);
    if (index === -1)
        next.push(id);
    else
        next.splice(index, 1);
    return next;
}

function exclusionUpdate(reserveSpace, barHeight, currentZone) {
    if (reserveSpace === true) {
        const height = Number(barHeight);
        if (Number.isFinite(height) && height > 0) {
            const zone = Math.round(height);
            return {
                mode: "normal",
                zone: zone,
                writeZone: currentZone !== zone,
            };
        }
    }

    return { mode: "ignore", zone: null, writeZone: false };
}

function layerForBar() {
    return "top";
}

var swiftshellBar = {
    BAR_MODULES: BAR_MODULES,
    barMetrics: barMetrics,
    heightFromUnit: heightFromUnit,
    unitFromHeight: unitFromHeight,
    normalizeModuleOrder: normalizeModuleOrder,
    moduleOrderValid: moduleOrderValid,
    normalizeHiddenModules: normalizeHiddenModules,
    hiddenModulesValid: hiddenModulesValid,
    visibleModules: visibleModules,
    moveModule: moveModule,
    toggleHidden: toggleHidden,
    exclusionUpdate: exclusionUpdate,
    layerForBar: layerForBar,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellBar;
