var BLUR_REASON = "Quickshell 0.2 has no BackgroundEffect. This shell does not change Hyprland blur rules. Surfaces use a translucent scrim.";
var CLIP_REASON = "Qt Quick clips to a rectangle, so this shell does not clip the scrim to the corner radius. The radius is the card shape. It is not a rounded blur mask.";

function materialReport() {
    return {
        backdropBlur: {
            available: false,
            hardwareVerified: false,
            fallback: "scrim",
            surfaces: ["bar", "popover", "spotlight", "settings"],
            reason: BLUR_REASON,
        },
        cornerClip: {
            followsRadius: false,
            reason: CLIP_REASON,
        },
    };
}

var swiftshellMaterial = {
    BLUR_REASON: BLUR_REASON,
    CLIP_REASON: CLIP_REASON,
    materialReport: materialReport,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellMaterial;
