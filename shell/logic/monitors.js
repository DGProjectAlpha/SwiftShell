function matchesTarget(screenName, hyprlandName, target) {
    if (typeof target !== "string")
        return false;

    const want = target.trim();
    if (want === "")
        return false;

    if (typeof screenName === "string" && screenName === want)
        return true;

    if (typeof hyprlandName === "string" && hyprlandName !== "" && hyprlandName === want)
        return true;

    return false;
}

var swiftshellMonitors = {
    matchesTarget: matchesTarget,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellMonitors;
