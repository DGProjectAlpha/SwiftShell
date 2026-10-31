function asText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function matchesTarget(screenName, hyprlandName, target) {
    const want = asText(target);
    if (want === "")
        return false;

    if (typeof screenName === "string" && screenName === want)
        return true;

    if (typeof hyprlandName === "string" && hyprlandName !== "" && hyprlandName === want)
        return true;

    return false;
}

function describeScreen(screen, hyprlandName, description) {
    return {
        name: screen && typeof screen.name === "string" ? screen.name : "",
        hyprlandName: asText(hyprlandName),
        description: asText(description),
        screen: screen || null,
    };
}

function labelOf(record) {
    if (!record)
        return "";
    if (record.hyprlandName)
        return record.hyprlandName;
    if (record.name)
        return record.name;
    if (record.description)
        return record.description;
    return "";
}

function recordList(records) {
    if (!Array.isArray(records))
        return [];
    const out = [];
    for (let i = 0; i < records.length; i++) {
        if (records[i] && records[i].screen)
            out.push(records[i]);
    }
    return out;
}

function recordMatches(record, target) {
    const want = asText(target);
    if (!record || want === "")
        return false;
    if (record.name === want)
        return true;
    if (record.hyprlandName !== "" && record.hyprlandName === want)
        return true;
    if (record.description !== "" && record.description === want)
        return true;
    return false;
}

function matchFocused(records, focused) {
    if (!focused || typeof focused !== "object")
        return null;
    const name = asText(focused.name);
    const description = asText(focused.description);
    if (name === "" && description === "")
        return null;

    for (let i = 0; i < records.length; i++) {
        const record = records[i];
        if (name !== "" && (record.hyprlandName === name || record.name === name))
            return record;
        if (description !== "" && record.description === description)
            return record;
    }
    return null;
}

function selectBarPlacement(records, preference, focused) {
    const list = recordList(records);
    if (list.length === 0)
        return { mode: "missing", screen: null, label: "" };

    const pref = asText(preference);
    if (pref !== "") {
        for (let i = 0; i < list.length; i++) {
            if (recordMatches(list[i], pref))
                return { mode: "preference", screen: list[i].screen, label: labelOf(list[i]) };
        }
    }

    const focusedRecord = matchFocused(list, focused);
    if (focusedRecord) {
        return {
            mode: pref === "" ? "focused" : "fallback",
            screen: focusedRecord.screen,
            label: labelOf(focusedRecord),
        };
    }

    return { mode: "fallback", screen: list[0].screen, label: labelOf(list[0]) };
}

function resolveLauncherScreen(records, focused, lastScreen) {
    const list = recordList(records);
    const focusedRecord = matchFocused(list, focused);
    if (focusedRecord)
        return { mode: "focused", screen: focusedRecord.screen, label: labelOf(focusedRecord) };
    if (list.length > 0)
        return { mode: "fallback", screen: list[0].screen, label: labelOf(list[0]) };
    if (lastScreen)
        return { mode: "last", screen: lastScreen, label: "" };
    return { mode: "missing", screen: null, label: "" };
}

function screenListed(screen, screens) {
    if (!screen)
        return false;
    const list = Array.isArray(screens) ? screens : [];
    if (!Array.isArray(screens) && screens && typeof screens.length === "number") {
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] === screen)
                return true;
        }
        return false;
    }
    for (let i = 0; i < list.length; i++) {
        if (list[i] === screen)
            return true;
    }
    return false;
}

var swiftshellMonitors = {
    matchesTarget: matchesTarget,
    describeScreen: describeScreen,
    selectBarPlacement: selectBarPlacement,
    resolveLauncherScreen: resolveLauncherScreen,
    screenListed: screenListed,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellMonitors;
