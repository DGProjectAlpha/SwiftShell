function exclusionUpdate(reserveSpace, barHeight) {
    if (reserveSpace === true) {
        const height = Number(barHeight);
        if (Number.isFinite(height) && height > 0)
            return { property: "exclusiveZone", value: Math.round(height) };
    }

    return { property: "exclusionMode", value: "ignore" };
}

function layerForBar() {
    return "top";
}

var swiftshellBar = {
    exclusionUpdate: exclusionUpdate,
    layerForBar: layerForBar,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellBar;
