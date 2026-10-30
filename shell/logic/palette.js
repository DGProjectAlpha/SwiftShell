var DARK = {
    text: { r: 242, g: 242, b: 242 },
    muted: { r: 163, g: 163, b: 163 },
    hover: { r: 212, g: 212, b: 212 },
    panel: { r: 16, g: 16, b: 16 },
    scrim: { r: 16, g: 16, b: 16 },
};

var LIGHT = {
    text: { r: 26, g: 26, b: 26 },
    muted: { r: 82, g: 82, b: 82 },
    hover: { r: 46, g: 46, b: 46 },
    panel: { r: 246, g: 246, b: 246 },
    scrim: { r: 246, g: 246, b: 246 },
};

function byteToUnit(value) {
    const number = Number(value);
    if (!Number.isFinite(number))
        return 0;
    return Math.min(255, Math.max(0, number)) / 255;
}

function unitAlpha(value) {
    const number = Number(value);
    if (!Number.isFinite(number))
        return 0;
    return Math.min(1, Math.max(0, number));
}

function colorUnits(rgb, alpha) {
    const source = rgb && typeof rgb === "object" ? rgb : {};
    return {
        r: byteToUnit(source.r),
        g: byteToUnit(source.g),
        b: byteToUnit(source.b),
        a: unitAlpha(alpha === undefined ? 1 : alpha),
    };
}

function gradientUnits(appearance) {
    if (appearance === "light")
        return { r: 1, g: 1, b: 1, a: 0.55 };
    return { r: 0, g: 0, b: 0, a: 0.34 };
}

function channel(value) {
    const scaled = value / 255;
    if (scaled <= 0.03928)
        return scaled / 12.92;
    return Math.pow((scaled + 0.055) / 1.055, 2.4);
}

function luminance(rgb) {
    return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b);
}

function contrastRatio(foreground, background) {
    const left = luminance(foreground);
    const right = luminance(background);
    const lighter = Math.max(left, right);
    const darker = Math.min(left, right);
    return (lighter + 0.05) / (darker + 0.05);
}

function composite(panel, opacity, behind) {
    const alpha = opacity;
    return {
        r: panel.r * alpha + behind.r * (1 - alpha),
        g: panel.g * alpha + behind.g * (1 - alpha),
        b: panel.b * alpha + behind.b * (1 - alpha),
    };
}

function resolvePalette(mode, tint) {
    const appearance = mode === "light" ? "light" : "dark";
    const base = appearance === "light" ? LIGHT : DARK;
    const wallpaperRequested = tint === "wallpaper";
    return {
        appearance: appearance,
        tint: wallpaperRequested ? "wallpaper" : "neutral",
        adaptive: false,
        adaptiveReason: wallpaperRequested ? "Wallpaper tint is not sampled yet." : "",
        text: base.text,
        muted: base.muted,
        hover: base.hover,
        panel: base.panel,
        scrim: base.scrim,
    };
}

function readableOnExtremes(mode, opacity) {
    const palette = resolvePalette(mode, "neutral");
    const white = { r: 255, g: 255, b: 255 };
    const black = { r: 0, g: 0, b: 0 };
    const overWhite = contrastRatio(palette.text, composite(palette.panel, opacity, white));
    const overBlack = contrastRatio(palette.text, composite(palette.panel, opacity, black));
    return {
        overWhite: overWhite,
        overBlack: overBlack,
        ok: overWhite >= 4.5 && overBlack >= 4.5,
    };
}

var swiftshellPalette = {
    byteToUnit: byteToUnit,
    unitAlpha: unitAlpha,
    colorUnits: colorUnits,
    gradientUnits: gradientUnits,
    resolvePalette: resolvePalette,
    contrastRatio: contrastRatio,
    composite: composite,
    readableOnExtremes: readableOnExtremes,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPalette;
