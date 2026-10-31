function objectValues(model) {
    if (!model)
        return [];
    if (Array.isArray(model))
        return model;
    const values = model.values;
    if (values && typeof values.length === "number") {
        const out = [];
        for (let i = 0; i < values.length; i++)
            out.push(values[i]);
        return out;
    }
    return [];
}

function menuPoint(x, y) {
    const px = Number(x);
    const py = Number(y);
    return {
        x: Number.isFinite(px) ? Math.round(px) : 0,
        y: Number.isFinite(py) ? Math.round(py) : 0,
    };
}

function trayAction(item) {
    if (!item)
        return "";
    if (item.onlyMenu === true)
        return item.hasMenu === true ? "menu" : "";
    return "activate";
}

function trayRows(items, limit) {
    const source = objectValues(items);
    const cap = typeof limit === "number" && limit > 0 ? limit : source.length;
    const out = [];
    for (let i = 0; i < source.length; i++) {
        const item = source[i];
        const action = trayAction(item);
        if (action === "")
            continue;
        const title = typeof item.title === "string" && item.title.trim() !== ""
            ? item.title.trim()
            : (typeof item.id === "string" && item.id.trim() !== "" ? item.id.trim() : "Tray");
        out.push({
            id: typeof item.id === "string" ? item.id : String(i),
            title: title.length > 48 ? title.slice(0, 45) + "..." : title,
            action: action,
            icon: typeof item.icon === "string" ? item.icon : "",
        });
        if (out.length === cap)
            break;
    }
    return out;
}

function trayOverflow(items, limit) {
    const all = trayRows(items, 0);
    if (typeof limit !== "number" || limit < 1 || all.length <= limit)
        return 0;
    return all.length - limit;
}

var swiftshellTray = {
    objectValues: objectValues,
    trayAction: trayAction,
    menuPoint: menuPoint,
    trayRows: trayRows,
    trayOverflow: trayOverflow,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellTray;
