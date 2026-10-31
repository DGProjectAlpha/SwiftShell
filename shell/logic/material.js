var BLUR_REASON = "Quickshell 0.2 has no BackgroundEffect. This shell does not change Hyprland blur rules. Surfaces use a translucent scrim.";

function materialReport() {
    return {
        backdropBlur: {
            available: false,
            hardwareVerified: false,
            fallback: "scrim",
            surfaces: ["bar", "popover", "spotlight", "settings"],
            reason: BLUR_REASON,
        },
    };
}

var swiftshellMaterial = {
    BLUR_REASON: BLUR_REASON,
    materialReport: materialReport,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellMaterial;
