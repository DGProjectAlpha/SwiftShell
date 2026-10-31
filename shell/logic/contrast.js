var LIGHT_TEXT = { r: 242, g: 242, b: 242 };
var DARK_TEXT = { r: 26, g: 26, b: 26 };
var LIGHT_MUTED = { r: 82, g: 82, b: 82 };
var DARK_MUTED = { r: 163, g: 163, b: 163 };
var LIGHT_PANEL = { r: 246, g: 246, b: 246 };
var DARK_PANEL = { r: 16, g: 16, b: 16 };

function channel(value) {
    var scaled = Number(value) / 255;
    if (!Number.isFinite(scaled))
        return 0;
    if (scaled <= 0.04045)
        return scaled / 12.92;
    return Math.pow((scaled + 0.055) / 1.055, 2.4);
}

function luminance(rgb) {
    var source = rgb || {};
    return 0.2126 * channel(source.r) + 0.7152 * channel(source.g) + 0.0722 * channel(source.b);
}

function contrastRatio(foreground, background) {
    var left = luminance(foreground);
    var right = luminance(background);
    var lighter = Math.max(left, right);
    var darker = Math.min(left, right);
    return (lighter + 0.05) / (darker + 0.05);
}

function chooseForeground(background, previous) {
    var lightContrast = contrastRatio(LIGHT_TEXT, background);
    var darkContrast = contrastRatio(DARK_TEXT, background);
    var foreground = lightContrast >= darkContrast ? "light" : "dark";
    if (previous === "light" && lightContrast >= 3.5)
        foreground = "light";
    else if (previous === "dark" && darkContrast >= 3.5)
        foreground = "dark";
    var chosen = foreground === "light" ? lightContrast : darkContrast;
    return {
        foreground: foreground,
        contrast: chosen,
        scrim: chosen < 4.5,
    };
}

function desaturate(rgb) {
    var red = Number(rgb && rgb.r);
    var green = Number(rgb && rgb.g);
    var blue = Number(rgb && rgb.b);
    if (![red, green, blue].every(function (value) { return Number.isFinite(value); }))
        return { r: 128, g: 128, b: 128 };
    for (var step = 0; step < 8; step++) {
        var max = Math.max(red, green, blue);
        var min = Math.min(red, green, blue);
        if (max - min <= 28)
            break;
        var average = (red + green + blue) / 3;
        red = red + (average - red) * 0.5;
        green = green + (average - green) * 0.5;
        blue = blue + (average - blue) * 0.5;
    }
    return { r: Math.round(red), g: Math.round(green), b: Math.round(blue) };
}

function analyzeBands(bands, previous) {
    var prior = previous || {};
    if (!bands || !bands.ok) {
        return {
            available: false,
            reason: bands && bands.reason ? bands.reason : "No wallpaper sample.",
            foreground: "",
            scrim: false,
            left: "",
            center: "",
            right: "",
            accent: { r: 128, g: 128, b: 128 },
            confidence: "none",
        };
    }
    var left = chooseForeground(bands.left, prior.left);
    var center = chooseForeground(bands.center, prior.center);
    var right = chooseForeground(bands.right, prior.right);
    var mixed = bands.mixed === true || left.foreground !== right.foreground;
    var scrim = mixed || left.scrim || center.scrim || right.scrim;
    var accentSource = {
        r: Math.round((bands.left.r + bands.center.r + bands.right.r) / 3),
        g: Math.round((bands.left.g + bands.center.g + bands.right.g) / 3),
        b: Math.round((bands.left.b + bands.center.b + bands.right.b) / 3),
    };
    return {
        available: true,
        reason: scrim ? "The top edge needs a fade so the text stays readable." : "",
        foreground: center.foreground,
        scrim: scrim,
        left: left.foreground,
        center: center.foreground,
        right: right.foreground,
        accent: desaturate(accentSource),
        confidence: scrim ? "low" : "high",
    };
}

function parseHex(text) {
    if (text == null)
        return null;
    var value = String(text).trim();
    var match = /^#([0-9a-fA-F]{6})$/.exec(value);
    if (!match)
        return null;
    return {
        r: parseInt(match[1].slice(0, 2), 16),
        g: parseInt(match[1].slice(2, 4), 16),
        b: parseInt(match[1].slice(4, 6), 16),
    };
}

function surfaceColors(options) {
    var input = options || {};
    var light = input.mode === "light";
    var analysis = input.analysis || {};
    var manualText = parseHex(input.manualText);
    var manualMuted = parseHex(input.manualMuted);
    var manualPanel = parseHex(input.manualPanel);
    var manualGradient = parseHex(input.manualGradient);
    var text = manualText || (light ? DARK_TEXT : LIGHT_TEXT);
    var reason = "";
    if (input.automaticText) {
        if (analysis.available && !analysis.scrim)
            text = analysis.foreground === "dark" ? DARK_TEXT : LIGHT_TEXT;
        else if (!(analysis.available && analysis.scrim))
            reason = analysis.reason || "Automatic contrast has no sample.";
    }
    var panel = manualPanel || (light ? LIGHT_PANEL : DARK_PANEL);
    var gradient = manualGradient || (light ? { r: 255, g: 255, b: 255 } : { r: 0, g: 0, b: 0 });
    var gradientAlpha = light ? 0.55 : 0.34;
    if (input.automaticGradient && analysis.available) {
        if (!manualGradient)
            gradient = desaturate(analysis.accent || gradient);
        if (analysis.scrim)
            gradientAlpha = Math.min(0.72, gradientAlpha + 0.2);
    }
    var warning = contrastRatio(text, panel) < 4.5 ? "Text contrast is below 4.5 against the panel." : "";
    return {
        text: text,
        muted: manualMuted || (light ? LIGHT_MUTED : DARK_MUTED),
        panel: panel,
        gradient: gradient,
        gradientAlpha: gradientAlpha,
        scrim: input.automaticGradient === true && analysis.scrim === true,
        reason: reason,
        warning: warning,
    };
}

var swiftshellContrast = {
    LIGHT_TEXT: LIGHT_TEXT,
    DARK_TEXT: DARK_TEXT,
    luminance: luminance,
    contrastRatio: contrastRatio,
    chooseForeground: chooseForeground,
    desaturate: desaturate,
    analyzeBands: analyzeBands,
    parseHex: parseHex,
    surfaceColors: surfaceColors,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellContrast;
