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

function focusCommand(address,mode) {
    if(typeof address!=="string" || !/^(?:0x)?[a-fA-F0-9]{1,32}$/.test(address))return "";
    const selector="address:"+(address.indexOf("0x")===0 ? address : "0x"+address);
    return mode==="legacy" ? "focuswindow "+selector : "eval hl.dispatch(hl.dsp.focus({window="+JSON.stringify(selector)+"}))";
}
var swiftshellWindows = {
    focusCommand:focusCommand,
    focusedTitle: focusedTitle,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellWindows;
