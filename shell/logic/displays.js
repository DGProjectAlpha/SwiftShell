var APPLY_REASON = "Display changes are not sent. This shell has no verified layout call on this floor, so the diagram is a preview.";

function finite(value, fallback) {
    return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function outputFrom(raw) {
    var source = raw || {};
    var width = Math.max(1, Math.round(finite(source.width, 1)));
    var height = Math.max(1, Math.round(finite(source.height, 1)));
    var scale = finite(source.scale, 1);
    var name = source.name == null ? "" : String(source.name);
    var description = source.description == null ? "" : String(source.description);
    var id = source.id == null || source.id === "" ? (description || name || "output") : String(source.id);
    return {
        id: id,
        name: name,
        description: description,
        x: Math.round(finite(source.x, 0)),
        y: Math.round(finite(source.y, 0)),
        width: width,
        height: height,
        scale: scale > 0 ? scale : 1,
        refresh: Math.max(0, Math.round(finite(source.refresh, 0))),
        enabled: source.enabled !== false,
    };
}

function clone(outputs) {
    var out = [];
    var list = outputs || [];
    for (var index = 0; index < list.length; index++)
        out.push(outputFrom(list[index]));
    return out;
}

function fromScreen(screen, hypr) {
    var monitor = hypr || {};
    var screenName = screen && screen.name ? String(screen.name) : "";
    return outputFrom({
        id: monitor.description || screenName || "output",
        name: monitor.name || screenName,
        description: monitor.description || "",
        x: monitor.x,
        y: monitor.y,
        width: monitor.width || (screen && screen.width),
        height: monitor.height || (screen && screen.height),
        scale: monitor.scale || (screen && screen.devicePixelRatio) || 1,
        refresh: monitor.refreshRate || monitor.refresh || 0,
        enabled: true,
    });
}

function needsRow(outputs) {
    var list = outputs || [];
    if (list.length < 2)
        return false;
    for (var index = 0; index < list.length; index++) {
        if (list[index].x !== 0 || list[index].y !== 0)
            return false;
    }
    return true;
}

function withFallbackRow(outputs) {
    var list = clone(outputs);
    if (!needsRow(list))
        return list;
    var cursor = 0;
    for (var index = 0; index < list.length; index++) {
        list[index].x = cursor;
        list[index].y = 0;
        cursor += list[index].width;
    }
    return list;
}

function liveOf(outputs) {
    var out = [];
    var list = outputs || [];
    for (var index = 0; index < list.length; index++) {
        if (list[index].enabled !== false)
            out.push(list[index]);
    }
    return out;
}

function bounds(outputs) {
    var live = liveOf(outputs);
    if (live.length === 0)
        return { x: 0, y: 0, width: 1, height: 1 };
    var minX = live[0].x;
    var minY = live[0].y;
    var maxX = live[0].x + live[0].width;
    var maxY = live[0].y + live[0].height;
    for (var index = 1; index < live.length; index++) {
        var item = live[index];
        minX = Math.min(minX, item.x);
        minY = Math.min(minY, item.y);
        maxX = Math.max(maxX, item.x + item.width);
        maxY = Math.max(maxY, item.y + item.height);
    }
    return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
}

function canvasScale(outputs, canvasWidth, canvasHeight, margin) {
    var box = bounds(outputs);
    var pad = finite(margin, 0);
    var innerW = Math.max(1, finite(canvasWidth, 1) - pad * 2);
    var innerH = Math.max(1, finite(canvasHeight, 1) - pad * 2);
    return Math.min(innerW / box.width, innerH / box.height);
}

function project(outputs, canvasWidth, canvasHeight, margin) {
    var list = outputs || [];
    var box = bounds(list);
    var pad = finite(margin, 0);
    var scale = canvasScale(list, canvasWidth, canvasHeight, pad);
    var out = [];
    for (var index = 0; index < list.length; index++) {
        var item = list[index];
        if (item.enabled === false)
            continue;
        out.push({
            id: item.id,
            label: item.name || item.id,
            x: Math.round(pad + (item.x - box.x) * scale),
            y: Math.round(pad + (item.y - box.y) * scale),
            width: Math.max(8, Math.round(item.width * scale)),
            height: Math.max(8, Math.round(item.height * scale)),
        });
    }
    return out;
}

function moveBy(outputs, id, dx, dy) {
    var list = clone(outputs);
    var stepX = finite(dx, 0);
    var stepY = finite(dy, 0);
    for (var index = 0; index < list.length; index++) {
        if (list[index].id === id) {
            list[index].x = Math.round(list[index].x + stepX);
            list[index].y = Math.round(list[index].y + stepY);
        }
    }
    return list;
}

function snapEdges(outputs, id, threshold) {
    var list = clone(outputs);
    var current = null;
    var index;
    for (index = 0; index < list.length; index++) {
        if (list[index].id === id)
            current = list[index];
    }
    if (!current)
        return list;
    var limit = finite(threshold, 0);
    var x = current.x;
    var y = current.y;
    var right = current.x + current.width;
    var bottom = current.y + current.height;
    for (index = 0; index < list.length; index++) {
        var other = list[index];
        if (other.id === id || other.enabled === false)
            continue;
        var edgesX = [other.x, other.x + other.width];
        var edgesY = [other.y, other.y + other.height];
        var edge;
        for (edge = 0; edge < edgesX.length; edge++) {
            if (Math.abs(current.x - edgesX[edge]) <= limit)
                x = edgesX[edge];
            if (Math.abs(right - edgesX[edge]) <= limit)
                x = edgesX[edge] - current.width;
        }
        for (edge = 0; edge < edgesY.length; edge++) {
            if (Math.abs(current.y - edgesY[edge]) <= limit)
                y = edgesY[edge];
            if (Math.abs(bottom - edgesY[edge]) <= limit)
                y = edgesY[edge] - current.height;
        }
    }
    return moveBy(list, id, x - current.x, y - current.y);
}

function overlaps(left, right) {
    return left.x < right.x + right.width && left.x + left.width > right.x && left.y < right.y + right.height && left.y + left.height > right.y;
}

function warnings(outputs) {
    var notes = [];
    var live = liveOf(outputs);
    if (live.length === 0)
        notes.push("At least one output has to stay on.");
    for (var i = 0; i < live.length; i++) {
        for (var j = i + 1; j < live.length; j++) {
            if (overlaps(live[i], live[j]))
                notes.push((live[i].name || live[i].id) + " overlaps " + (live[j].name || live[j].id));
        }
    }
    return notes;
}

function setEnabled(outputs, id, enabled) {
    var list = clone(outputs);
    var others = 0;
    var index;
    for (index = 0; index < list.length; index++) {
        if (list[index].id !== id && list[index].enabled !== false)
            others += 1;
    }
    if (enabled === false && others === 0)
        return { outputs: list, error: "The last output stays on." };
    for (index = 0; index < list.length; index++) {
        if (list[index].id === id)
            list[index].enabled = enabled === true;
    }
    return { outputs: list, error: "" };
}

function nudge(outputs, id, direction, step) {
    var amount = finite(step, 0) > 0 ? step : 80;
    if (direction === "left")
        return moveBy(outputs, id, -amount, 0);
    if (direction === "right")
        return moveBy(outputs, id, amount, 0);
    if (direction === "up")
        return moveBy(outputs, id, 0, -amount);
    if (direction === "down")
        return moveBy(outputs, id, 0, amount);
    return clone(outputs);
}

var swiftshellDisplays = {
    APPLY_REASON: APPLY_REASON,
    outputFrom: outputFrom,
    clone: clone,
    fromScreen: fromScreen,
    needsRow: needsRow,
    withFallbackRow: withFallbackRow,
    bounds: bounds,
    canvasScale: canvasScale,
    project: project,
    moveBy: moveBy,
    snapEdges: snapEdges,
    warnings: warnings,
    setEnabled: setEnabled,
    nudge: nudge,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellDisplays;
