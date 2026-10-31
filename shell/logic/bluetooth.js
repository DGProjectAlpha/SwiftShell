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

function adapterSummary(adapter) {
    if (!adapter)
        return { present: false, enabled: false, name: "" };
    const name = typeof adapter.name === "string" && adapter.name.trim() !== ""
        ? adapter.name.trim()
        : (typeof adapter.adapterId === "string" && adapter.adapterId.trim() !== "" ? adapter.adapterId.trim() : "Adapter");
    return { present: true, enabled: adapter.enabled === true, name: name };
}

function deviceName(device, index) {
    if (device && typeof device.name === "string" && device.name.trim() !== "")
        return device.name.trim();
    if (device && typeof device.deviceName === "string" && device.deviceName.trim() !== "")
        return device.deviceName.trim();
    return "Device " + (index + 1);
}

function deviceKey(device, index) {
    if (device && typeof device.dbusPath === "string" && device.dbusPath !== "")
        return device.dbusPath;
    return deviceName(device, index) + ":" + index;
}

function deviceRows(devices) {
    const source = objectValues(devices);
    const out = [];
    for (let i = 0; i < source.length && out.length < 16; i++) {
        const device = source[i];
        if (!device)
            continue;
        const name = deviceName(device, i);
        out.push({
            key: deviceKey(device, i),
            name: name.length > 48 ? name.slice(0, 45) + "..." : name,
            connected: device.connected === true,
            paired: device.paired === true || device.bonded === true,
            pairing: device.pairing === true,
            battery: device.batteryAvailable === true && typeof device.battery === "number" && Number.isFinite(device.battery)
                ? Math.round(Math.min(1, Math.max(0, device.battery)) * 100)
                : null,
        });
    }
    return out;
}

function deviceCommand(device, action) {
    if (!device || typeof action !== "string")
        return "";
    if (action === "connect" && device.connected !== true)
        return "connect";
    if (action === "disconnect" && device.connected === true)
        return "disconnect";
    if (action === "pair" && device.paired !== true && device.pairing !== true)
        return "pair";
    if (action === "forget" && (device.paired === true || device.bonded === true))
        return "forget";
    if (action === "cancel" && device.pairing === true)
        return "cancel";
    return "";
}

var swiftshellBluetooth = {
    objectValues: objectValues,
    adapterSummary: adapterSummary,
    deviceKey: deviceKey,
    deviceRows: deviceRows,
    deviceCommand: deviceCommand,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellBluetooth;
