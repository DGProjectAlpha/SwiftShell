function formatMinutes(seconds) {
    if (typeof seconds !== "number" || !Number.isFinite(seconds) || seconds <= 0)
        return "";
    const minutes = Math.round(seconds / 60);
    if (minutes < 1)
        return "";
    if (minutes < 60)
        return minutes + " min";
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest === 0 ? hours + " h" : hours + " h " + rest + " min";
}

function batteryReport(device, onBattery) {
    if (!device || device.ready !== true || typeof device.percentage !== "number" || !Number.isFinite(device.percentage)) {
        return {
            available: false,
            text: "Unavailable",
            detail: "UPower has no ready display device.",
        };
    }
    const percent = Math.round(Math.min(100, Math.max(0, device.percentage)));
    const charging = onBattery !== true;
    let detail = charging ? "On AC" : "On battery";
    const estimate = formatMinutes(charging ? device.timeToFull : device.timeToEmpty);
    if (estimate !== "")
        detail = detail + ", " + estimate + (charging ? " to full" : " left");
    return { available: true, text: percent + "%", detail: detail };
}

var swiftshellPower = {
    formatMinutes: formatMinutes,
    batteryReport: batteryReport,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPower;
