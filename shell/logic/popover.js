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

function logicalScreen(physicalWidth, physicalHeight, scale) {
    const width = Number(physicalWidth);
    const height = Number(physicalHeight);
    const factor = Number(scale);
    if (!Number.isFinite(width) || !Number.isFinite(height) || !Number.isFinite(factor) || factor <= 0)
        return null;
    if (width <= 0 || height <= 0)
        return null;
    return {
        width: width / factor,
        height: height / factor,
    };
}

function anchorFromItemMap(mapped, options) {
    const source = options || {};
    if (!mapped || typeof mapped !== "object")
        return null;
    const width = Number(mapped.width);
    const height = Number(mapped.height);
    const x = Number(mapped.x);
    const y = Number(mapped.y);
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0)
        return null;
    if (!Number.isFinite(x) || !Number.isFinite(y))
        return null;
    const gap = Math.max(0, finite(source.gap, 0));
    const placed = placePopup({
        anchorX: x,
        anchorY: y + height + gap,
        anchorWidth: width,
        popupWidth: source.popupWidth,
        popupHeight: source.popupHeight,
        screenWidth: source.screenWidth,
        screenHeight: source.screenHeight,
        margin: source.margin,
        align: source.align === "start" ? "start" : "end",
    });
    return {
        x: placed.x,
        y: placed.y,
        width: 1,
        height: 1,
        logicalPixels: true,
    };
}

function panelBlurPolicy() {
    return {
        supported: false,
        protocol: "",
        fallback: "scrim",
    };
}

function popupModel() {
    return {
        phase: "closed",
        panelId: "",
        grab: false,
        interactive: false,
        visible: false,
        opacity: 0,
        offset: 0,
        suppressId: "",
    };
}

function knownPanel(id) {
    return id === "calendar" || id === "control";
}

function clonePopup(state) {
    const source = state && typeof state === "object" ? state : {};
    const phase = source.phase === "opening" || source.phase === "open" || source.phase === "closing"
        ? source.phase
        : "closed";
    return {
        phase: phase,
        panelId: knownPanel(source.panelId) ? source.panelId : "",
        grab: source.grab === true,
        interactive: source.interactive === true,
        visible: source.visible === true,
        opacity: Number(source.opacity) === 1 ? 1 : 0,
        offset: Number(source.offset) === 4 ? 4 : 0,
        suppressId: typeof source.suppressId === "string" ? source.suppressId : "",
    };
}

function near(value, target) {
    const number = Number(value);
    return Number.isFinite(number) && Math.abs(number - target) <= 0.001;
}

function beginOpen(id, instant) {
    return {
        phase: instant ? "open" : "opening",
        panelId: id,
        grab: true,
        interactive: true,
        visible: true,
        opacity: 1,
        offset: 4,
        suppressId: "",
    };
}

function beginClose(current, instant) {
    if (current.phase === "closed")
        return clonePopup(current);
    if (instant)
        return popupModel();
    if (current.phase === "closing")
        return clonePopup(current);
    return {
        phase: "closing",
        panelId: current.panelId,
        grab: false,
        interactive: false,
        visible: true,
        opacity: 0,
        offset: 0,
        suppressId: current.suppressId,
    };
}

function dismissalMotion(visualOpacity, motion) {
    const source = motion || {};
    return {
        instantOpen: source.instantOpen === true,
        instantClose: source.instantClose === true || near(visualOpacity, 0),
    };
}

function reducePopup(state, action, options) {
    const current = clonePopup(state);
    const opts = options || {};
    const type = action && typeof action.type === "string" ? action.type : "";

    if (type === "monitorLost" || type === "anchorLost" || type === "destroy")
        return popupModel();

    if (type === "clearSuppress")
        return clonePopup({
            phase: current.phase,
            panelId: current.panelId,
            grab: current.grab,
            interactive: current.interactive,
            visible: current.visible,
            opacity: current.opacity,
            offset: current.offset,
            suppressId: "",
        });

    if (type === "animationFinished") {
        if (current.phase === "opening" && near(action && action.opacity, 1))
            return clonePopup({
                phase: "open",
                panelId: current.panelId,
                grab: true,
                interactive: true,
                visible: true,
                opacity: 1,
                offset: 4,
                suppressId: current.suppressId,
            });
        if (current.phase === "closing" && near(action && action.opacity, 0))
            return popupModel();
        return current;
    }

    if (type === "escape" || type === "close")
        return beginClose(current, opts.instantClose === true);

    if (type === "outside") {
        if (current.phase === "closed")
            return current;
        const next = beginClose(current, opts.instantClose === true);
        next.suppressId = current.panelId;
        return next;
    }

    if (type === "toggle" || type === "open") {
        const id = action && typeof action.id === "string" ? action.id : "";
        if (!knownPanel(id))
            return current;
        if (current.suppressId === id)
            return clonePopup({
                phase: current.phase,
                panelId: current.panelId,
                grab: current.grab,
                interactive: current.interactive,
                visible: current.visible,
                opacity: current.opacity,
                offset: current.offset,
                suppressId: "",
            });
        const active = current.phase === "opening" || current.phase === "open";
        if (type === "toggle" && active && current.panelId === id)
            return beginClose(current, opts.instantClose === true);
        if (active && current.panelId !== id)
            return clonePopup({
                phase: current.phase,
                panelId: id,
                grab: true,
                interactive: true,
                visible: true,
                opacity: current.opacity === 1 || current.phase === "open" ? 1 : current.opacity,
                offset: current.offset,
                suppressId: "",
            });
        return beginOpen(id, opts.instantOpen === true);
    }

    return current;
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
    logicalScreen: logicalScreen,
    anchorFromItemMap: anchorFromItemMap,
    panelBlurPolicy: panelBlurPolicy,
    popupModel: popupModel,
    dismissalMotion: dismissalMotion,
    reducePopup: reducePopup,
    reducePopover: reducePopover,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPopover;
