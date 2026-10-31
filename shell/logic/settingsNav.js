var CONTROLS = [
    { id: "preview", category: "appearance", section: "Preview", label: "Preview", keywords: ["panel", "sample"] },
    { id: "mode", category: "appearance", section: "Theme", label: "Theme", keywords: ["dark", "light", "mode"] },
    { id: "fontSize", category: "appearance", section: "Text", label: "Text size", keywords: ["font", "size", "type"] },
    { id: "fontWeight", category: "appearance", section: "Text", label: "Text weight", keywords: ["font", "medium", "regular"] },
    { id: "density", category: "appearance", section: "Text", label: "Density", keywords: ["padding", "spacing", "compact"] },
    { id: "panelOpacity", category: "appearance", section: "Surface", label: "Panel opacity", keywords: ["alpha", "scrim", "transparency"] },
    { id: "radius", category: "appearance", section: "Surface", label: "Corner radius", keywords: ["round", "corner"] },
    { id: "shadowOpacity", category: "appearance", section: "Surface", label: "Shadow opacity", keywords: ["shadow", "elevation"] },
    { id: "shadowSoftness", category: "appearance", section: "Surface", label: "Shadow softness", keywords: ["shadow", "softness"] },
    { id: "iconScale", category: "appearance", section: "Text", label: "Icon scale", keywords: ["icon", "glyph"] },
    { id: "motionScale", category: "appearance", section: "Motion", label: "Motion scale", keywords: ["animation", "duration", "speed"] },
    { id: "reducedMotion", category: "appearance", section: "Motion", label: "Reduced motion", keywords: ["animation", "motion"] },
    { id: "topGradient", category: "appearance", section: "Surface", label: "Top edge gradient", keywords: ["gradient", "bar", "fade"] },
    { id: "wallpaperTint", category: "appearance", section: "Limits", label: "Wallpaper tint", keywords: ["tint", "wallpaper", "adaptive"] },
    { id: "backdropBlur", category: "appearance", section: "Limits", label: "Backdrop blur", keywords: ["blur", "frost", "material"] },
    { id: "barHeight", category: "bar", section: "Size", label: "Bar height", keywords: ["height", "scale", "size"] },
    { id: "reserveSpace", category: "bar", section: "Placement", label: "Reserve space", keywords: ["exclusive", "overlay", "zone"] },
    { id: "targetMonitor", category: "bar", section: "Placement", label: "Monitor", keywords: ["screen", "output", "display"] },
    { id: "showTitle", category: "bar", section: "Modules", label: "Focused title", keywords: ["window", "title", "app"] },
    { id: "clock24", category: "bar", section: "Modules", label: "24-hour clock", keywords: ["clock", "time", "hour"] },
    { id: "moduleOrder", category: "bar", section: "Modules", label: "Module order", keywords: ["reorder", "hide", "workspaces", "search"] },
    { id: "wallpaperEnabled", category: "wallpaper", section: "Image", label: "Draw wallpaper", keywords: ["background", "hyprpaper", "swww"] },
    { id: "wallpaperFit", category: "wallpaper", section: "Image", label: "Fit", keywords: ["cover", "contain", "crop", "fill"] },
    { id: "wallpaperPath", category: "wallpaper", section: "Image", label: "Image", keywords: ["file", "choose", "path", "default", "crimson"] },
    { id: "wallpaperOutput", category: "wallpaper", section: "Outputs", label: "Per output", keywords: ["monitor", "display", "screen"] },
    { id: "slideshow", category: "wallpaper", section: "Slideshow", label: "Slideshow", keywords: ["folder", "interval", "shuffle", "crossfade"] },
    { id: "automaticText", category: "wallpaper", section: "Contrast", label: "Automatic text", keywords: ["contrast", "foreground", "readable"] },
    { id: "manualText", category: "wallpaper", section: "Contrast", label: "Manual text", keywords: ["hex", "color", "foreground"] },
];

function clamp01(unit) {
    if (typeof unit !== "number" || !Number.isFinite(unit))
        return 0;
    return Math.min(1, Math.max(0, unit));
}

function haystack(item) {
    return (item.label + " " + item.section + " " + item.keywords.join(" ")).toLowerCase();
}

function filterControls(query) {
    const text = String(query == null ? "" : query).trim().toLowerCase();
    if (text === "")
        return CONTROLS.slice();
    const found = [];
    for (let i = 0; i < CONTROLS.length; i++) {
        if (haystack(CONTROLS[i]).indexOf(text) !== -1)
            found.push(CONTROLS[i]);
    }
    return found;
}

function controlVisible(query, id) {
    const rows = filterControls(query);
    for (let i = 0; i < rows.length; i++) {
        if (rows[i].id === id)
            return true;
    }
    return false;
}

function categoryFor(id) {
    for (let i = 0; i < CONTROLS.length; i++) {
        if (CONTROLS[i].id === id)
            return CONTROLS[i].category;
    }
    return "";
}

function firstControlId(query) {
    const rows = filterControls(query);
    return rows.length > 0 ? rows[0].id : "";
}

function moveSelection(query, currentId, delta) {
    const rows = filterControls(query);
    if (rows.length === 0)
        return "";
    let index = 0;
    for (let i = 0; i < rows.length; i++) {
        if (rows[i].id === currentId) {
            index = i;
            break;
        }
    }
    const step = delta < 0 ? -1 : 1;
    const next = index + step;
    if (next < 0)
        return rows[0].id;
    if (next >= rows.length)
        return rows[rows.length - 1].id;
    return rows[next].id;
}

function categories() {
    return [
        { id: "appearance", label: "Appearance" },
        { id: "bar", label: "Top bar" },
        { id: "wallpaper", label: "Wallpaper" },
    ];
}

function navigationLayout(width) {
    return typeof width === "number" && Number.isFinite(width) && width < 720 ? "stacked" : "columns";
}

function densityFromUnit(unit) {
    const t = clamp01(unit);
    return {
        panelPadding: Math.round(8 + t * 12),
        panelSpacing: Math.round(4 + t * 12),
    };
}

function unitFromDensity(padding) {
    if (typeof padding !== "number" || !Number.isFinite(padding))
        return 0;
    return clamp01((padding - 8) / 12);
}

function fontSizeFromUnit(unit) {
    return Math.round(11 + clamp01(unit) * 5);
}

function unitFromFontSize(size) {
    if (typeof size !== "number" || !Number.isFinite(size))
        return 0;
    return clamp01((size - 11) / 5);
}

function shadowOpacityFromUnit(unit) {
    return Math.round(clamp01(unit) * 0.4 * 1000) / 1000;
}

function unitFromShadowOpacity(opacity) {
    if (typeof opacity !== "number" || !Number.isFinite(opacity))
        return 0;
    return clamp01(opacity / 0.4);
}

function shadowSoftnessFromUnit(unit) {
    return Math.round(clamp01(unit) * 24);
}

function unitFromShadowSoftness(softness) {
    if (typeof softness !== "number" || !Number.isFinite(softness))
        return 0;
    return clamp01(softness / 24);
}

function iconScaleFromUnit(unit) {
    return Math.round((0.75 + clamp01(unit) * 0.75) * 1000) / 1000;
}

function unitFromIconScale(scale) {
    if (typeof scale !== "number" || !Number.isFinite(scale))
        return 0;
    return clamp01((scale - 0.75) / 0.75);
}

function scrollTarget(contentY, viewport, itemY, itemHeight) {
    const y = typeof contentY === "number" && Number.isFinite(contentY) ? contentY : 0;
    const view = typeof viewport === "number" && Number.isFinite(viewport) ? viewport : 0;
    const top = typeof itemY === "number" && Number.isFinite(itemY) ? itemY : 0;
    const height = typeof itemHeight === "number" && Number.isFinite(itemHeight) ? itemHeight : 0;
    if (top < y)
        return Math.max(0, top);
    if (view > 0 && top + height > y + view)
        return Math.max(0, top + height - view);
    return Math.max(0, y);
}

var swiftshellSettingsNav = {
    CONTROLS: CONTROLS,
    categories: categories,
    filterControls: filterControls,
    controlVisible: controlVisible,
    categoryFor: categoryFor,
    firstControlId: firstControlId,
    moveSelection: moveSelection,
    navigationLayout: navigationLayout,
    densityFromUnit: densityFromUnit,
    unitFromDensity: unitFromDensity,
    fontSizeFromUnit: fontSizeFromUnit,
    unitFromFontSize: unitFromFontSize,
    shadowOpacityFromUnit: shadowOpacityFromUnit,
    unitFromShadowOpacity: unitFromShadowOpacity,
    shadowSoftnessFromUnit: shadowSoftnessFromUnit,
    unitFromShadowSoftness: unitFromShadowSoftness,
    iconScaleFromUnit: iconScaleFromUnit,
    unitFromIconScale: unitFromIconScale,
    scrollTarget: scrollTarget,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellSettingsNav;
