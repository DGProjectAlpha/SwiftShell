function motionDurations(reducedMotion, scale) {
    if (reducedMotion === true)
        return { open: 0, close: 0, hover: 0 };

    let factor = Number(scale);
    if (!Number.isFinite(factor))
        factor = 1;
    factor = Math.min(1, Math.max(0, factor));
    if (factor === 0)
        return { open: 0, close: 0, hover: 0 };

    return {
        open: Math.round(180 * factor),
        close: Math.round(120 * factor),
        hover: Math.round(80 * factor),
    };
}

var swiftshellTheme = {
    motionDurations: motionDurations,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellTheme;
