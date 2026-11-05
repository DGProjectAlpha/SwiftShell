var CONTROLS = [
    {id:"weatherLocation",category:"weather",section:"Location",label:"Weather location",keywords:["weather","forecast","city","address","postal","zip","automatic"]},
    {id:"weatherUnits",category:"weather",section:"Forecast",label:"Weather units",keywords:["weather","temperature","celsius","fahrenheit"]},
    {id:"weatherRefresh",category:"weather",section:"Forecast",label:"Weather updates",keywords:["weather","refresh","interval","forecast"]},
    {id:"accentColor",category:"appearance",section:"Colors",label:"Accent color",keywords:["color","buttons","sliders","accent"]},
    {id:"opaqueWindows",category:"appearance",section:"Application windows",label:"Keep windows opaque",keywords:["opacity","inactive","transparent","video","focus"]},
    {id:"fullscreenBarPeek",category:"bar",section:"Placement",label:"Peek in fullscreen",keywords:["fullscreen","game","edge","peek","reveal"]},

    {id:"notificationQuietHours",category:"notifications",section:"Quiet hours",label:"Scheduled quiet hours",keywords:["schedule","overnight","days","week","quiet","sleep"]},
    {id:"notificationPrivacy",category:"notifications",section:"Privacy",label:"Notification previews",keywords:["privacy","hide","body","preview","messages","content"]},
    {id:"notificationSound",category:"notifications",section:"Sound",label:"Notification sound",keywords:["sound","volume","audio","silent","mute"]},
    {id:"spotlightProviders",category:"spotlight",section:"Search providers",label:"Clipboard and open windows",keywords:["clipboard","clip","history","windows","privacy","providers"]},
    {id:"spotlightScreenshots",category:"spotlight",section:"Screenshots",label:"Screenshots",keywords:["capture","screenshot","image","region"]},
    {id:"notificationDelivery",category:"notifications",section:"Delivery",label:"Notification delivery",keywords:["duration","retention","history","display","banner","timeout","snooze"]},
    {id:"barEdgeScale",category:"bar",section:"Position & scale",label:"Bar edge and scale",keywords:["left","right","top","bottom","display","monitor","scale","position"]},
    {id:"workspaceOverview",category:"workspaces",section:"Overview",label:"Workspace overview",keywords:["alt tab","windows","miniatures","overview"]},
    {id:"windowBorders",category:"appearance",section:"Application windows",label:"Window borders",keywords:["border","active","inactive","windows","outline","disable"]},
    {id:"spotlightDefaultMode",category:"spotlight",section:"Spotlight Search",label:"Default search view",keywords:["spotlight","search","all apps","favorites","recent","launcher"]},
    { id:"defaultApps",category:"defaultApps",section:"Applications",label:"Default applications",keywords:["browser","email","calendar","terminal","files","mime"] },
    { id: "preview", category: "appearance", section: "Preview", label: "Preview", keywords: ["panel", "sample"] },
    { id: "mode", category: "appearance", section: "Theme", label: "Theme", keywords: ["dark", "light", "mode"] },
    { id: "textContrast", category: "appearance", section: "Text", label: "High contrast", keywords: ["contrast", "accessibility", "readable"] },
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
    { id: "workspaceOutputs", category: "workspaces", section: "Monitors", label: "Per-monitor workspaces", keywords: ["workspace", "empty", "named", "automatic", "override"] },
    { id: "barSurface", category: "bar", section: "Background", label: "Bar background", keywords: ["transparent","solid","frosted","blur","opacity","color","monitor"] },
    { id: "barHeight", category: "bar", section: "Size", label: "Bar height", keywords: ["height", "scale", "size"] },
    { id: "reserveSpace", category: "bar", section: "Placement", label: "Reserve space", keywords: ["exclusive", "overlay", "zone"] },
    { id: "barPlacement", category: "bar", section: "Placement", label: "Bar screens", keywords: ["monitor", "focus", "all", "primary"] },
    { id: "targetMonitor", category: "bar", section: "Placement", label: "Monitor", keywords: ["screen", "output", "display"] },
    { id: "showTitle", category: "bar", section: "Modules", label: "Focused title", keywords: ["window", "title", "app"] },
    { id: "searchLabel", category:"bar", section:"Modules", label:"Search label", keywords:["icon","glyph","search","label"] },
    { id: "clockDisplay", category:"bar", section:"Clock", label:"Clock and date", keywords:["seconds","date","format","weekday","time"] },
    { id: "clock24", category: "bar", section: "Modules", label: "24-hour clock", keywords: ["clock", "time", "hour"] },
    { id: "moduleOrder", category: "bar", section: "Widgets", label: "Widget order", keywords: ["module order", "reorder", "hide", "workspaces", "search"] },
    { id: "wallpaperEnabled", category: "wallpaper", section: "Image", label: "Draw wallpaper", keywords: ["background", "hyprpaper", "swww"] },
    { id: "wallpaperFit", category: "wallpaper", section: "Image", label: "Fit", keywords: ["cover", "contain", "crop", "fill"] },
    { id: "wallpaperPath", category: "wallpaper", section: "Image", label: "Image", keywords: ["file", "choose", "path", "default", "crimson"] },
    { id: "wallpaperOutput", category: "wallpaper", section: "Outputs", label: "Per output", keywords: ["monitor", "display", "screen"] },
    { id: "slideshow", category: "wallpaper", section: "Slideshow", label: "Slideshow", keywords: ["folder", "interval", "shuffle", "crossfade"] },
    { id: "automaticText", category: "appearance", section: "Contrast", label: "Automatic text", keywords: ["contrast", "foreground", "readable"] },
    { id: "manualText", category: "appearance", section: "Contrast", label: "Manual text", keywords: ["hex", "color", "foreground"] },
    { id: "displayLayout", category: "displays", section: "Arrangement", label: "Arrangement", keywords: ["monitor", "display", "scale", "preview"] },
    { id: "desktopShortcuts", category: "shortcuts", section: "Keyboard", label: "Desktop shortcuts", keywords: ["shortcut", "hotkeys", "keyboard", "record", "hyprland", "super"] },
    { id: "audioOutput", category: "audio", section: "Audio", label: "Output", keywords: ["volume", "sink", "pipewire", "mute"] },
    { id: "audioInput", category: "audio", section: "Audio", label: "Input", keywords: ["microphone", "source", "input"] },
    { id: "audioStream", category: "audio", section: "Audio", label: "Application streams", keywords: ["stream", "app", "volume"] },
    { id: "mediaPlayer", category: "audio", section: "Media", label: "Player", keywords: ["mpris", "play", "pause", "music"] },
    { id: "trayItems", category: "audio", section: "Tray", label: "Tray", keywords: ["status", "notifier", "icon"] },
    { id: "networkStatus", category: "network", section: "Network", label: "Network", keywords: ["wifi", "ethernet", "vpn"] },
    { id: "brightnessStatus", category: "network", section: "Brightness", label: "Brightness", keywords: ["backlight", "display", "dim"] },
    { id: "bluetoothDevices", category: "network", section: "Bluetooth", label: "Devices", keywords: ["adapter", "pair", "bluez"] },
    { id: "battery", category: "power", section: "Battery", label: "Battery", keywords: ["upower", "charge", "ac"] },
    { id: "powerProfiles", category: "power", section: "Energy", label: "Power mode", keywords: ["performance", "balanced", "saver", "energy", "power"] },
    { id: "notificationOwner", category: "notifications", section: "Owner", label: "Owner", keywords: ["notification", "dbus", "noctalia"] },
    { id: "notificationDnd", category: "notifications", section: "Quiet", label: "Do not disturb", keywords: ["dnd", "quiet", "critical"] },
    { id: "notificationPreview", category: "notifications", section: "Preview", label: "Preview", keywords: ["preview", "banner"] },
    { id: "notificationPolicy", category: "notifications", section: "Applications", label: "Per application", keywords: ["quiet", "hide", "desktop"] },
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
        { id: "spotlight", label: "Spotlight Search" },
        { id: "wallpaper", label: "Wallpaper" },
        { id: "displays", label: "Displays" },
        { id: "workspaces", label: "Workspaces" },
        { id: "shortcuts", label: "Shortcuts" },
        { id: "defaultApps", label: "Default apps" },
        { id: "audio", label: "Audio" },
        { id: "network", label: "Network & Devices" },
        { id: "power", label: "Power" },
        { id: "notifications", label: "Notifications" },
        { id: "weather", label: "Weather" },
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
    // A section taller than the viewport must reveal its heading and first
    // control rather than aligning its bottom and hiding the entry controls.
    if (view > 0 && height >= view)
        return Math.max(0, top);
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
