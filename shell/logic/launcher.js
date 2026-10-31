var MAX_PINS = 12;
var MAX_RECENT = 8;
var GRID_CAP = 12;

var POWER = [
    { id: "lock", label: "Lock", argv: ["loginctl", "lock-session"] },
    { id: "suspend", label: "Suspend", argv: ["loginctl", "suspend"] },
    { id: "reboot", label: "Restart", argv: ["loginctl", "reboot"] },
    { id: "poweroff", label: "Shut down", argv: ["loginctl", "poweroff"] },
];

function asText(value) {
    return typeof value === "string" ? value : "";
}

function asStringList(value) {
    if (Array.isArray(value)) {
        return value.filter(function (item) { return typeof item === "string"; });
    }
    if (value && typeof value === "object" && typeof value.length === "number") {
        const out = [];
        for (let i = 0; i < value.length; i++) {
            if (typeof value[i] === "string")
                out.push(value[i]);
        }
        return out;
    }
    if (typeof value === "string" && value.trim() !== "")
        return value.split(";").map(function (item) { return item.trim(); }).filter(Boolean);
    return [];
}

function desktopIdValid(value) {
    return typeof value === "string" && value.length > 0 && value.length <= 128 && /^[A-Za-z0-9._+-]+$/.test(value);
}

function normalizeIdList(value, max) {
    const source = asStringList(value);
    const out = [];
    for (let i = 0; i < source.length && out.length < max; i++) {
        if (!desktopIdValid(source[i]) || out.indexOf(source[i]) !== -1)
            continue;
        out.push(source[i]);
    }
    return out;
}

function idListValid(value, max) {
    if (!value || typeof value !== "object" || typeof value.length !== "number")
        return false;
    const source = asStringList(value);
    if (source.length !== value.length || source.length > max)
        return false;
    const seen = [];
    for (let i = 0; i < source.length; i++) {
        if (!desktopIdValid(source[i]) || seen.indexOf(source[i]) !== -1)
            return false;
        seen.push(source[i]);
    }
    return true;
}

function applyFieldCode(token, entry) {
    if (token.indexOf("%") === -1)
        return [token];

    let out = "";
    const extra = [];
    for (let i = 0; i < token.length; i++) {
        if (token[i] !== "%" || i + 1 >= token.length) {
            out += token[i];
            continue;
        }
        const code = token[i + 1];
        i++;
        if (code === "%") {
            out += "%";
            continue;
        }
        if (code === "i") {
            const icon = asText(entry && entry.icon).trim();
            if (icon !== "" && icon.indexOf(" ") === -1 && icon.indexOf("\n") === -1 && icon.indexOf("%") === -1)
                extra.push("--icon", icon);
            continue;
        }
        if (code === "c") {
            const name = asText(entry && entry.name).replace(/\n/g, " ").trim();
            if (name !== "")
                extra.push(name);
            continue;
        }
        // %f %F %u %U %d %D %n %N %v %m and unknown codes need a chosen file or URL.
        // The search box does not supply one, so the code is removed.
    }
    const result = [];
    if (out !== "")
        result.push(out);
    return result.concat(extra);
}

function commandFromExec(exec, entry) {
    const source = asText(exec);
    if (source.trim() === "")
        return [];

    const tokens = [];
    let current = "";
    let quote = false;
    for (let i = 0; i < source.length; i++) {
        const char = source[i];
        if (quote) {
            if (char === "\\") {
                current += i + 1 < source.length ? source[i + 1] : "";
                i++;
                continue;
            }
            if (char === '"') {
                quote = false;
                continue;
            }
            current += char;
            continue;
        }
        if (char === '"') {
            quote = true;
            continue;
        }
        if (char === " " || char === "\t" || char === "\n") {
            if (current !== "")
                tokens.push(current);
            current = "";
            continue;
        }
        if (char === "\\") {
            current += i + 1 < source.length ? source[i + 1] : "";
            i++;
            continue;
        }
        current += char;
    }
    if (current !== "")
        tokens.push(current);
    if (quote)
        return [];

    const argv = [];
    for (let i = 0; i < tokens.length; i++) {
        const expanded = applyFieldCode(tokens[i], entry);
        for (let j = 0; j < expanded.length; j++)
            argv.push(expanded[j]);
    }
    return argv;
}

function parseDesktopEntry(text, sourceId) {
    const lines = asText(text).split(/\r?\n/);
    let section = "";
    const fields = {};
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.trim() === "" || line[0] === "#")
            continue;
        if (line[0] === "[") {
            section = line.trim();
            continue;
        }
        if (section !== "[Desktop Entry]")
            continue;
        const split = line.indexOf("=");
        if (split <= 0)
            continue;
        const key = line.slice(0, split).trim();
        const locale = key.indexOf("[");
        if (locale !== -1)
            continue;
        fields[key] = line.slice(split + 1);
    }

    const name = asText(fields.Name).trim();
    const id = asText(sourceId).trim();
    return {
        id: id,
        type: asText(fields.Type).trim(),
        name: name,
        genericName: asText(fields.GenericName).trim(),
        comment: asText(fields.Comment).trim(),
        icon: asText(fields.Icon).trim(),
        categories: asStringList(fields.Categories),
        keywords: asStringList(fields.Keywords),
        hidden: asText(fields.Hidden).trim().toLowerCase() === "true",
        noDisplay: asText(fields.NoDisplay).trim().toLowerCase() === "true",
        onlyShowIn: asStringList(fields.OnlyShowIn),
        notShowIn: asStringList(fields.NotShowIn),
        terminal: asText(fields.Terminal).trim().toLowerCase() === "true",
        command: commandFromExec(fields.Exec, { name: name, icon: asText(fields.Icon).trim() }),
    };
}

function entryVisible(entry, desktops) {
    if (!entry || entry.hidden === true || entry.noDisplay === true)
        return false;
    if (entry.type && entry.type !== "Application")
        return false;
    if (!entry.name || entry.command.length === 0)
        return false;
    const current = asStringList(desktops);
    if (current.length === 0)
        return true;
    if (entry.onlyShowIn && entry.onlyShowIn.length > 0) {
        let shown = false;
        for (let i = 0; i < entry.onlyShowIn.length; i++) {
            if (current.indexOf(entry.onlyShowIn[i]) !== -1)
                shown = true;
        }
        if (!shown)
            return false;
    }
    if (entry.notShowIn) {
        for (let i = 0; i < entry.notShowIn.length; i++) {
            if (current.indexOf(entry.notShowIn[i]) !== -1)
                return false;
        }
    }
    return true;
}

function dedupeApplications(apps) {
    const source = Array.isArray(apps) ? apps : [];
    const seen = {};
    const out = [];
    for (let i = 0; i < source.length; i++) {
        const app = source[i];
        const id = app && typeof app.id === "string" ? app.id : "";
        if (id === "" || seen[id])
            continue;
        seen[id] = true;
        out.push(app);
    }
    return out;
}

function fuzzy(text, query) {
    if (query.length < 2)
        return false;
    let from = 0;
    let first = -1;
    let last = -1;
    for (let i = 0; i < query.length; i++) {
        const at = text.indexOf(query[i], from);
        if (at < 0)
            return false;
        if (first < 0)
            first = at;
        last = at;
        from = at + 1;
    }
    return last - first <= query.length + 6;
}

function fieldScore(field, query, base) {
    const text = asText(field).toLowerCase();
    if (text === "")
        return 0;
    if (text === query)
        return base + 400;
    if (text.indexOf(query) === 0)
        return base + 300;
    const words = text.split(/\s+/);
    for (let i = 0; i < words.length; i++) {
        if (words[i].indexOf(query) === 0)
            return base + 200;
    }
    if (text.indexOf(query) !== -1)
        return base + 100;
    if (fuzzy(text, query))
        return base + 40;
    return 0;
}

function bestScore(app, query) {
    const chunks = [
        fieldScore(app.name, query, 1000),
        fieldScore(app.id, query, 800),
        fieldScore(app.genericName, query, 500),
        fieldScore(app.comment, query, 300),
        fieldScore(asStringList(app.keywords).join(" "), query, 200),
        fieldScore(asStringList(app.categories).join(" "), query, 100),
    ];
    let best = 0;
    for (let i = 0; i < chunks.length; i++) {
        if (chunks[i] > best)
            best = chunks[i];
    }
    return best;
}

function byName(left, right) {
    const a = asText(left && left.name).toLowerCase();
    const b = asText(right && right.name).toLowerCase();
    if (a < b)
        return -1;
    if (a > b)
        return 1;
    const ida = asText(left && left.id);
    const idb = asText(right && right.id);
    if (ida < idb)
        return -1;
    if (ida > idb)
        return 1;
    return 0;
}

function rank(apps, query) {
    const q = asText(query).trim().toLowerCase();
    if (q === "")
        return [];
    const unique = dedupeApplications(apps);
    const scored = [];
    for (let i = 0; i < unique.length; i++) {
        const app = unique[i];
        const score = bestScore(app, q);
        if (score <= 0)
            continue;
        scored.push({ app: app, score: score, index: i });
    }
    scored.sort(function (left, right) {
        if (left.score !== right.score)
            return right.score - left.score;
        const name = byName(left.app, right.app);
        if (name !== 0)
            return name;
        return left.index - right.index;
    });
    return scored.map(function (item) { return item.app; });
}

function findById(apps, id) {
    const unique = dedupeApplications(apps);
    for (let i = 0; i < unique.length; i++) {
        if (unique[i].id === id)
            return unique[i];
    }
    return null;
}

function appRow(app, section) {
    return {
        kind: "application",
        id: app.id,
        name: asText(app.name),
        detail: asText(app.genericName) || asText(app.comment),
        icon: asText(app.icon),
        section: section,
    };
}

function viewRows(apps, query, pinnedIds, recentIds) {
    const unique = dedupeApplications(apps);
    const rows = [];
    const q = asText(query).trim();
    if (q === "") {
        const used = {};
        const pins = normalizeIdList(pinnedIds, MAX_PINS);
        for (let i = 0; i < pins.length; i++) {
            const app = findById(unique, pins[i]);
            if (!app)
                continue;
            used[app.id] = true;
            rows.push(appRow(app, "Pinned"));
        }
        const recent = normalizeIdList(recentIds, MAX_RECENT);
        for (let i = 0; i < recent.length; i++) {
            if (used[recent[i]])
                continue;
            const app = findById(unique, recent[i]);
            if (!app)
                continue;
            used[app.id] = true;
            rows.push(appRow(app, "Recent"));
        }
        const rest = unique.filter(function (app) { return !used[app.id]; }).sort(byName);
        const grid = rest.slice(0, GRID_CAP);
        for (let i = 0; i < grid.length; i++)
            rows.push(appRow(grid[i], "Applications"));
    } else {
        const found = rank(unique, q);
        for (let i = 0; i < found.length; i++)
            rows.push(appRow(found[i], "Results"));
    }
    rows.push({ kind: "settings", id: "settings", name: "Settings", detail: "Control center", icon: "", section: "Session" });
    for (let i = 0; i < POWER.length; i++) {
        rows.push({
            kind: "power",
            id: POWER[i].id,
            name: POWER[i].label,
            detail: "",
            icon: "",
            section: "Power",
        });
    }
    return rows;
}

function moveSelection(index, count, delta) {
    if (!count || count < 1)
        return 0;
    const current = typeof index === "number" && index >= 0 ? index : 0;
    const step = delta < 0 ? -1 : 1;
    let next = current + step;
    if (next < 0)
        next = count - 1;
    if (next >= count)
        next = 0;
    return next;
}

function powerArgv(id) {
    for (let i = 0; i < POWER.length; i++) {
        if (POWER[i].id === id)
            return POWER[i].argv.slice();
    }
    return null;
}

function powerStep(confirmId, id) {
    const argv = powerArgv(id);
    if (!argv)
        return { confirmId: "", run: false, argv: null };
    if (confirmId === id)
        return { confirmId: "", run: true, argv: argv };
    return { confirmId: id, run: false, argv: null };
}

function pushRecent(ids, id) {
    if (!desktopIdValid(id))
        return normalizeIdList(ids, MAX_RECENT);
    const next = [id];
    const current = normalizeIdList(ids, MAX_RECENT);
    for (let i = 0; i < current.length; i++) {
        if (current[i] !== id)
            next.push(current[i]);
    }
    return next.slice(0, MAX_RECENT);
}

function monogram(name) {
    const text = asText(name).trim();
    if (text === "")
        return "?";
    return text[0].toUpperCase();
}

function iconPath(icon) {
    const text = asText(icon).trim();
    if (text[0] !== "/" || text.indexOf("\n") !== -1 || text.indexOf("\0") !== -1)
        return "";
    return text;
}

function readList(value) {
    if (Array.isArray(value))
        return value.slice();
    if (value && typeof value === "object" && typeof value.length === "number" && value.length >= 0) {
        const out = [];
        for (let i = 0; i < value.length; i++)
            out.push(value[i]);
        return out;
    }
    return null;
}

// DesktopEntries.applications is an ObjectModel. Its values list is what
// search must copy. A QML list is array-like and Array.isArray is false.
function readApplicationModel(model) {
    if (model == null)
        return { available: false, entries: [] };
    if (typeof model === "object" && model.values !== undefined) {
        const nested = readList(model.values);
        if (nested == null)
            return { available: false, entries: [] };
        return { available: true, entries: nested };
    }
    const entries = readList(model);
    if (entries == null)
        return { available: false, entries: [] };
    return { available: true, entries: entries };
}

function entryField(entry, key) {
    if (!entry || typeof entry !== "object")
        return "";
    return typeof entry[key] === "string" ? entry[key].trim() : "";
}

function snapshotApplications(entries) {
    const source = readList(entries) || [];
    const applications = [];
    const seen = {};
    let skipped = 0;
    for (let i = 0; i < source.length; i++) {
        const entry = source[i];
        const id = entryField(entry, "id");
        const name = entryField(entry, "name");
        if (id === "" || name === "" || !entry || entry.noDisplay === true || entry.hidden === true || seen[id]) {
            skipped++;
            continue;
        }
        seen[id] = true;
        const command = [];
        const rawCommand = readList(entry.command) || [];
        for (let j = 0; j < rawCommand.length; j++) {
            if (typeof rawCommand[j] === "string" && rawCommand[j] !== "")
                command.push(rawCommand[j]);
        }
        applications.push({
            id: id,
            name: name,
            genericName: entryField(entry, "genericName"),
            comment: entryField(entry, "comment"),
            icon: entryField(entry, "icon"),
            categories: asStringList(entry.categories),
            keywords: asStringList(entry.keywords),
            terminal: entry.runInTerminal === true || entry.terminal === true,
            command: command,
        });
    }
    return { applications: applications, skipped: skipped };
}

var iconCache = {};

function cachedIconSource(icon, lookup) {
    const key = asText(icon).trim();
    if (Object.prototype.hasOwnProperty.call(iconCache, key))
        return iconCache[key];
    const resolved = iconSource(key, lookup);
    iconCache[key] = resolved;
    return resolved;
}

function iconSource(icon, lookup) {
    const text = asText(icon).trim();
    if (text === "" || text.indexOf("\n") !== -1 || text.indexOf("\0") !== -1)
        return "";
    if (text[0] === "/")
        return text;
    if (typeof lookup !== "function")
        return "";
    let resolved = "";
    try {
        resolved = lookup(text);
    } catch (error) {
        return "";
    }
    if (typeof resolved !== "string" || resolved === "" || resolved.indexOf("\n") !== -1 || resolved.indexOf("\0") !== -1)
        return "";
    return resolved;
}

var POWER_VERBS = {
    "lock-session": true,
    suspend: true,
    reboot: true,
    poweroff: true,
};

function powerInvocation(confirmId, id) {
    const step = powerStep(confirmId, id);
    if (!step.run)
        return { run: false, confirmId: step.confirmId, argv: null, error: "" };
    const argv = step.argv ? step.argv.slice() : null;
    const verb = argv && argv.length === 2 ? argv[1] : "";
    if (!argv || argv[0] !== "loginctl" || POWER_VERBS[verb] !== true)
        return { run: false, confirmId: "", argv: null, error: "Power action is not available" };
    return { run: true, confirmId: "", argv: argv, error: "" };
}

var SPOTLIGHT_MAX_WIDTH = 480;
var SPOTLIGHT_MARGIN = 24;

function finite(value) {
    const number = Number(value);
    return Number.isFinite(number) ? number : 0;
}

function spotlightContentHeight(rowCount, statusCount, metrics) {
    const spec = metrics && typeof metrics === "object" ? metrics : {};
    const field = finite(spec.field) || 28;
    const row = finite(spec.row) || 28;
    const status = finite(spec.status) || 16;
    const pad = finite(spec.pad) || 12;
    const gap = spec.gap === undefined ? 2 : finite(spec.gap);
    const rows = Math.max(0, Math.floor(finite(rowCount)));
    const statuses = Math.max(0, Math.floor(finite(statusCount)));
    let height = pad * 2 + field;
    if (statuses > 0)
        height += gap + statuses * status + Math.max(0, statuses - 1) * gap;
    if (rows > 0)
        height += gap + rows * row + Math.max(0, rows - 1) * gap;
    return height;
}

function spotlightFrame(screenWidth, screenHeight, contentHeight) {
    const sw = Math.max(0, finite(screenWidth));
    const sh = Math.max(0, finite(screenHeight));
    const content = Math.max(0, finite(contentHeight));
    const width = Math.max(0, Math.min(SPOTLIGHT_MAX_WIDTH, sw - SPOTLIGHT_MARGIN * 2));
    const maxHeight = Math.max(0, sh - SPOTLIGHT_MARGIN * 2);
    const height = Math.max(0, Math.min(content, maxHeight));
    return {
        x: sw > width ? Math.round((sw - width) / 2) : 0,
        y: sh > height ? Math.round((sh - height) / 2) : 0,
        width: width,
        height: height,
        maxWidth: SPOTLIGHT_MAX_WIDTH,
    };
}

function requestAction(open, token, seen, ready) {
    const next = typeof token === "string" ? token : "";
    if (ready !== true)
        return { action: "ignore", seen: next, ready: true };
    if (next === "" || next === seen)
        return { action: "ignore", seen: seen, ready: true };
    if (open === true)
        return { action: "close", seen: next, ready: true };
    return { action: "open", seen: next, ready: true };
}

function inputPlan(open, hasScreen) {
    const show = open === true && hasScreen === true;
    return {
        visible: show,
        grab: show,
        keyboard: show ? "exclusive" : "none",
        focusField: show,
        dismiss: open === true && hasScreen !== true,
    };
}

function revealOffset(contentY, viewport, rowY, rowHeight) {
    const top = Number(contentY);
    const view = Number(viewport);
    const y = Number(rowY);
    const height = Number(rowHeight);
    if (!Number.isFinite(top) || !Number.isFinite(view) || !Number.isFinite(y) || !Number.isFinite(height))
        return 0;
    if (y < top)
        return Math.max(0, y);
    const bottom = y + height;
    if (bottom > top + view)
        return Math.max(0, bottom - view);
    return Math.max(0, top);
}

var swiftshellLauncher = {
    MAX_PINS: MAX_PINS,
    MAX_RECENT: MAX_RECENT,
    POWER: POWER,
    desktopIdValid: desktopIdValid,
    normalizeIdList: normalizeIdList,
    idListValid: idListValid,
    commandFromExec: commandFromExec,
    parseDesktopEntry: parseDesktopEntry,
    entryVisible: entryVisible,
    dedupeApplications: dedupeApplications,
    rank: rank,
    viewRows: viewRows,
    moveSelection: moveSelection,
    powerArgv: powerArgv,
    powerStep: powerStep,
    pushRecent: pushRecent,
    monogram: monogram,
    iconPath: iconPath,
    readApplicationModel: readApplicationModel,
    snapshotApplications: snapshotApplications,
    iconSource: iconSource,
    cachedIconSource: cachedIconSource,
    powerInvocation: powerInvocation,
    SPOTLIGHT_MAX_WIDTH: SPOTLIGHT_MAX_WIDTH,
    spotlightContentHeight: spotlightContentHeight,
    spotlightFrame: spotlightFrame,
    requestAction: requestAction,
    inputPlan: inputPlan,
    revealOffset: revealOffset,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellLauncher;
