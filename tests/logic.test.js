const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const clock = require("../shell/logic/clock.js");
const monitors = require("../shell/logic/monitors.js");
const workspaces = require("../shell/logic/workspaces.js");
const windows = require("../shell/logic/windows.js");
const settings = require("../shell/logic/settings.js");

let failed = 0;

function test(name, fn) {
    try {
        fn();
        console.log("ok - " + name);
    } catch (error) {
        failed += 1;
        console.error("not ok - " + name);
        console.error(error && error.stack ? error.stack : error);
    }
}

function at(hours, minutes) {
    return new Date(2026, 9, 30, hours, minutes, 30);
}

test("24-hour clock pads hours and minutes and omits seconds", function () {
    assert.equal(clock.formatTime(at(0, 5), true), "00:05");
    assert.equal(clock.formatTime(at(9, 4), true), "09:04");
    assert.equal(clock.formatTime(at(13, 5), true), "13:05");
    assert.equal(clock.formatTime(at(23, 59), true), "23:59");
});

test("12-hour clock uses a compact suffix", function () {
    assert.equal(clock.formatTime(at(0, 0), false), "12:00 AM");
    assert.equal(clock.formatTime(at(9, 4), false), "9:04 AM");
    assert.equal(clock.formatTime(at(12, 0), false), "12:00 PM");
    assert.equal(clock.formatTime(at(13, 5), false), "1:05 PM");
});

test("invalid clock input is visible as a placeholder", function () {
    assert.equal(clock.formatTime(null, true), "--:--");
    assert.equal(clock.formatTime(undefined, false), "--:--");
    assert.equal(clock.formatTime({}, true), "--:--");
    assert.equal(clock.formatTime(new Date(NaN), true), "--:--");
});

test("monitor matching is exact and accepts either screen or hyprland name", function () {
    assert.equal(monitors.matchesTarget("HDMI-A-1", "", "HDMI-A-1"), true);
    assert.equal(monitors.matchesTarget("DP-1", "HDMI-A-1", "HDMI-A-1"), true);
    assert.equal(monitors.matchesTarget("DP-1", "DP-1", "HDMI-A-1"), false);
    assert.equal(monitors.matchesTarget("hdmi-a-1", "", "HDMI-A-1"), false);
    assert.equal(monitors.matchesTarget("HDMI-A-1", "HDMI-A-1", " HDMI-A-1 "), true);
    assert.equal(monitors.matchesTarget("", "", ""), false);
    assert.equal(monitors.matchesTarget("HDMI-A-1", "HDMI-A-1", null), false);
});

test("workspace ids fall back to 4, 5, and 6", function () {
    assert.deepEqual(workspaces.normalizeWorkspaceIds(undefined), [4, 5, 6]);
    assert.deepEqual(workspaces.normalizeWorkspaceIds([]), [4, 5, 6]);
    assert.deepEqual(workspaces.normalizeWorkspaceIds([0, -1, 4.5, "nope"]), [4, 5, 6]);
});

test("workspace ids drop duplicates and keep order", function () {
    assert.deepEqual(workspaces.normalizeWorkspaceIds([6, 6, "5", 4, 100]), [6, 5, 4]);
    assert.equal(workspaces.normalizeWorkspaceIds([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]).length, 12);
});

test("workspace ids accept array-like lists from QML", function () {
    const qmlList = { 0: 6, 1: 5, 2: 4, length: 3 };
    assert.deepEqual(workspaces.normalizeWorkspaceIds(qmlList), [6, 5, 4]);
    assert.deepEqual(settings.normalizeWorkspaceIds(qmlList), [6, 5, 4]);
});

test("workspace normalizers stay in agreement", function () {
    const samples = [undefined, [], [4, 5, 6], [6, "5", 5, 0, 4], [1, 2, 3]];
    for (const sample of samples) {
        assert.deepEqual(
            workspaces.normalizeWorkspaceIds(sample),
            settings.normalizeWorkspaceIds(sample)
        );
    }
});

test("active workspace highlight follows the bar monitor", function () {
    const live = [
        { id: 4, name: "4", monitorName: "HDMI-A-1", active: true, focused: false, urgent: false },
        { id: 5, name: "5", monitorName: "DP-1", active: true, focused: true, urgent: true },
        { id: 1, name: "1", monitorName: "DP-1", active: false, focused: false, urgent: false },
    ];
    const items = workspaces.buildWorkspaceItems([4, 5, 6], live, "HDMI-A-1");
    assert.deepEqual(items.map(function (item) { return item.id; }), [4, 5, 6]);
    assert.equal(items[0].active, true);
    assert.equal(items[0].onMonitor, true);
    assert.equal(items[1].active, false);
    assert.equal(items[1].onMonitor, false);
    assert.equal(items[1].urgent, true);
    assert.equal(items[2].exists, false);
    assert.equal(items[2].active, false);
});

test("missing monitor name does not mark a foreign workspace active", function () {
    const live = [
        { id: 4, name: "4", monitorName: "DP-1", active: true, focused: true, urgent: false },
    ];
    const items = workspaces.buildWorkspaceItems([4], live, "");
    assert.equal(items[0].active, false);
    assert.equal(items[0].exists, true);
});

test("workspace dispatch is a single ipc command", function () {
    assert.equal(workspaces.dispatchWorkspaceCommand(4), "workspace 4");
    assert.equal(workspaces.dispatchWorkspaceCommand(6), "workspace 6");
    assert.equal(workspaces.dispatchWorkspaceCommand("4"), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(4.2), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(-4), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(4).includes("hyprctl"), false);
});

test("focused title stays on the bar monitor", function () {
    const toplevels = [
        { title: "Editor", activated: true, monitorName: "DP-1", workspaceId: 1 },
        { title: "Browser", activated: false, monitorName: "HDMI-A-1", workspaceId: 4 },
        { title: "  Notes  ", activated: true, monitorName: "HDMI-A-1", workspaceId: 5 },
    ];
    assert.equal(windows.focusedTitle(toplevels, "HDMI-A-1", 4), "Notes");
    assert.equal(windows.focusedTitle([
        { title: "Browser", activated: false, monitorName: "HDMI-A-1", workspaceId: 4 },
        { title: "Other", activated: false, monitorName: "HDMI-A-1", workspaceId: 5 },
    ], "HDMI-A-1", 4), "Browser");
    assert.equal(windows.focusedTitle(toplevels, "DP-2", 4), "");
    assert.equal(windows.focusedTitle(toplevels, "", 4), "");
    assert.equal(windows.focusedTitle([
        { title: "Ghost", activated: false, monitorName: "HDMI-A-1", workspaceId: -1 },
    ], "HDMI-A-1", -1), "");
});

test("empty settings validate to the documented defaults", function () {
    const result = settings.validateSettings({});
    assert.equal(result.ok, true);
    assert.deepEqual(result.settings, settings.DEFAULTS);
    assert.equal(result.settings.bar.targetMonitor, "HDMI-A-1");
    assert.equal(result.settings.bar.reserveSpace, false);
    assert.equal(result.settings.clock.use24Hour, true);
    assert.deepEqual(result.settings.bar.workspaceIds, [4, 5, 6]);
});

test("invalid settings are reported and repaired without accepting the bad value", function () {
    const result = settings.validateSettings({
        version: 2,
        clock: { use24Hour: "yes" },
        bar: {
            targetMonitor: " ",
            reserveSpace: 1,
            showFocusedTitle: "yes",
            workspaceIds: [4, 4, 0],
        },
    });
    assert.equal(result.ok, false);
    assert.deepEqual(result.errors, [
        "version",
        "clock.use24Hour",
        "bar.targetMonitor",
        "bar.reserveSpace",
        "bar.showFocusedTitle",
        "bar.workspaceIds",
    ]);
    assert.equal(result.settings.version, 1);
    assert.equal(result.settings.clock.use24Hour, true);
    assert.equal(result.settings.bar.targetMonitor, "HDMI-A-1");
    assert.equal(result.settings.bar.reserveSpace, false);
    assert.deepEqual(result.settings.bar.workspaceIds, [4]);
});

test("valid custom settings round-trip", function () {
    const result = settings.validateSettings({
        version: 1,
        clock: { use24Hour: false },
        bar: {
            targetMonitor: " HDMI-A-1 ",
            reserveSpace: true,
            showFocusedTitle: false,
            workspaceIds: [4, 5, 6],
        },
    });
    assert.equal(result.ok, true);
    assert.equal(result.settings.clock.use24Hour, false);
    assert.equal(result.settings.bar.targetMonitor, "HDMI-A-1");
    assert.equal(result.settings.bar.reserveSpace, true);
    assert.equal(result.settings.bar.showFocusedTitle, false);
});

test("non-object settings are rejected", function () {
    const result = settings.validateSettings("nope");
    assert.equal(result.ok, false);
    assert.equal(result.errors[0], "settings");
    assert.equal(result.settings.bar.targetMonitor, "HDMI-A-1");
});

test("defaults.json matches the serializer", function () {
    const file = path.join(__dirname, "..", "shell", "config", "defaults.json");
    const text = fs.readFileSync(file, "utf8");
    assert.equal(text, settings.serializeSettings(settings.DEFAULTS));
});

if (failed > 0) {
    console.error(failed + " test(s) failed");
    process.exit(1);
}

console.log("logic tests passed");
