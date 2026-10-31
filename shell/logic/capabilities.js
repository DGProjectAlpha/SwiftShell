function capabilityReport() {
    return {
        settingsToplevel: {
            available: true,
            mechanism: "Quickshell.FloatingWindow",
            documentedIn: "0.2.0",
            clientMove: false,
            hardwareVerified: false,
            reason: "Quickshell 0.2 documents FloatingWindow as a standard toplevel with a title and a minimum size. Client-started move and resize are not on that page. The compositor can still move the window. This report is not a hardware pass.",
        },
        backdropBlur: {
            available: false,
            hardwareVerified: false,
            reason: "Quickshell 0.2 has no BackgroundEffect. This shell does not change Hyprland blur rules. Surfaces use a translucent scrim.",
        },
    };
}

function reduceSettingsWindow(state, action) {
    const current = state && typeof state === "object"
        ? state
        : { open: false, instances: 0, focused: false, reason: "" };
    if (action === "launch")
        return { open: true, instances: 1, focused: true, reason: "" };
    if (action === "close" || action === "compositor-close")
        return { open: false, instances: 0, focused: false, reason: "" };
    if (action === "load-failed")
        return { open: false, instances: 0, focused: false, reason: "The settings window could not be created" };
    return {
        open: current.open === true,
        instances: current.instances === 1 && current.open === true ? 1 : 0,
        focused: current.focused === true && current.open === true,
        reason: typeof current.reason === "string" ? current.reason : "",
    };
}

var swiftshellCapabilities = {
    capabilityReport: capabilityReport,
    reduceSettingsWindow: reduceSettingsWindow,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellCapabilities;
