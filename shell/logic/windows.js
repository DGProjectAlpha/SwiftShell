function focusedTitle(toplevels, monitorName, activeWorkspaceId) {
    if (typeof monitorName !== "string" || monitorName === "" || !Array.isArray(toplevels))
        return "";

    let onWorkspace = "";
    for (let i = 0; i < toplevels.length; i++) {
        const toplevel = toplevels[i];
        if (!toplevel || toplevel.monitorName !== monitorName)
            continue;

        const title = typeof toplevel.title === "string" ? toplevel.title.trim() : "";
        if (title === "")
            continue;

        if (toplevel.activated === true)
            return title;

        if (typeof activeWorkspaceId === "number" && activeWorkspaceId > 0 && toplevel.workspaceId === activeWorkspaceId)
            onWorkspace = title;
    }

    return onWorkspace;
}

var swiftshellWindows = {
    focusedTitle: focusedTitle,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellWindows;
