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
    exclusionUpdate: exclusionUpdate,
    layerForBar: layerForBar,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellBar;
