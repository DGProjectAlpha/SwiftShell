function finite(value, fallback) {
    const number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}

function clamp(value, min, max) {
    if (max < min)
        return min;
    return Math.min(max, Math.max(min, value));
}

function placePopup(input) {
    const source = input || {};
    const margin = Math.max(0, finite(source.margin, 0));
    const popupWidth = Math.max(1, finite(source.popupWidth, 1));
    const popupHeight = Math.max(1, finite(source.popupHeight, 1));
    const anchorX = finite(source.anchorX, margin);
    const anchorY = finite(source.anchorY, margin);
    const anchorWidth = Math.max(0, finite(source.anchorWidth, 0));
    const screenWidth = finite(source.screenWidth, 0);
    const screenHeight = finite(source.screenHeight, 0);
    let x = source.align === "start" ? anchorX : anchorX + anchorWidth - popupWidth;
    let y = anchorY;

    if (screenWidth > 0)
        x = clamp(x, margin, Math.max(margin, screenWidth - popupWidth - margin));
    if (screenHeight > 0)
        y = clamp(y, margin, Math.max(margin, screenHeight - popupHeight - margin));

    return {
        x: x,
        y: y,
        width: popupWidth,
        height: popupHeight,
        logicalPixels: true,
    };
}

function reducePopover(openId, action) {
    const current = typeof openId === "string" ? openId : "";
    if (!action || typeof action.type !== "string")
        return { openId: current, changed: false };

    if (action.type === "close")
        return { openId: "", changed: current !== "" };

    if (action.type === "open" || action.type === "toggle") {
        const nextId = typeof action.id === "string" ? action.id : "";
        if (nextId === "")
            return { openId: current, changed: false };
        if (action.type === "toggle" && current === nextId)
            return { openId: "", changed: true };
        return { openId: nextId, changed: current !== nextId };
    }

    return { openId: current, changed: false };
}

var swiftshellPopover = {
    placePopup: placePopup,
    reducePopover: reducePopover,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPopover;
