const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const clock = require("../shell/logic/clock.js");
const monitors = require("../shell/logic/monitors.js");
const workspaces = require("../shell/logic/workspaces.js");
const windows = require("../shell/logic/windows.js");
const settings = require("../shell/logic/settings.js");
const palette = require("../shell/logic/palette.js");
const theme = require("../shell/logic/theme.js");
const calendar = require("../shell/logic/calendar.js");
const popover = require("../shell/logic/popover.js");
const audio = require("../shell/logic/audio.js");
const bar = require("../shell/logic/bar.js");
const launcher = require("../shell/logic/launcher.js");

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

test("moving a window onto the bar monitor updates the active workspace", function () {
    const before = workspaces.buildWorkspaceItems([4, 5, 6], [
        { id: 4, name: "4", monitorName: "HDMI-A-1", active: true, focused: true, urgent: false },
        { id: 5, name: "5", monitorName: "HDMI-A-1", active: false, focused: false, urgent: false },
    ], "HDMI-A-1");
    assert.equal(before[0].active, true);
    assert.equal(before[1].active, false);
    const after = workspaces.buildWorkspaceItems([4, 5, 6], [
        { id: 4, name: "4", monitorName: "HDMI-A-1", active: false, focused: false, urgent: false },
        { id: 5, name: "5", monitorName: "HDMI-A-1", active: true, focused: true, urgent: false },
    ], "HDMI-A-1");
    assert.equal(after[0].active, false);
    assert.equal(after[1].active, true);
    assert.equal(after[1].onMonitor, true);
    assert.equal(after[2].exists, false);
});

test("workspace dispatch uses the lua expression unless legacy is selected", function () {
    assert.equal(workspaces.dispatchWorkspaceCommand(4), "hl.dsp.focus({ workspace = 4 })");
    assert.equal(workspaces.dispatchWorkspaceCommand(6), "hl.dsp.focus({ workspace = 6 })");
    assert.equal(workspaces.dispatchWorkspaceCommand(5, "auto", true), "hl.dsp.focus({ workspace = 5 })");
    assert.equal(workspaces.dispatchWorkspaceCommand(5, "auto", null), "hl.dsp.focus({ workspace = 5 })");
    assert.equal(workspaces.dispatchWorkspaceCommand(5, "lua", false), "hl.dsp.focus({ workspace = 5 })");
    assert.equal(workspaces.dispatchWorkspaceCommand(5, "legacy", true), "workspace 5");
    assert.equal(workspaces.dispatchWorkspaceCommand(5, "auto", false), "workspace 5");
    assert.equal(workspaces.dispatchWorkspaceCommand(5).includes("on_current_monitor"), false);
    assert.equal(workspaces.dispatchWorkspaceCommand(5).indexOf("workspace 5"), -1);
    assert.equal(workspaces.dispatchWorkspaceCommand("4"), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(4.2), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(-4), "");
    assert.equal(workspaces.dispatchWorkspaceCommand("5);"), "");
    assert.equal(workspaces.dispatchWorkspaceCommand(5).includes("hyprctl"), false);
    assert.equal(workspaces.resolveDispatchMode("auto", true), "lua");
    assert.equal(workspaces.resolveDispatchMode("auto", false), "legacy");
    assert.equal(workspaces.resolveDispatchMode("auto", null), "lua");
    assert.equal(workspaces.resolveDispatchMode("legacy", true), "legacy");
    assert.equal(workspaces.workspaceIdsValid({ length: 3, 0: 4, 1: 5, 2: 6 }), true);
    assert.equal(workspaces.workspaceIdsValid({ length: 3, 0: 4, 1: 5, 2: "6" }), false);
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
    assert.equal(result.settings.bar.workspaceDispatch, "auto");
});

test("qml list workspace ids validate without a warning", function () {
    const qmlList = { length: 3, 0: 4, 1: 5, 2: 6 };
    const result = settings.validateSettings({
        bar: { workspaceIds: qmlList, workspaceDispatch: "lua" },
    });
    assert.equal(result.ok, true);
    assert.equal(Array.isArray(qmlList), false);
    assert.deepEqual(result.settings.bar.workspaceIds, [4, 5, 6]);
    assert.equal(result.settings.bar.workspaceDispatch, "lua");

    const strings = settings.validateSettings({
        bar: { workspaceIds: { length: 3, 0: 4, 1: 5, 2: "6" } },
    });
    assert.equal(strings.ok, false);
    assert.ok(strings.errors.indexOf("bar.workspaceIds") !== -1);

    const mode = settings.validateSettings({
        bar: { workspaceIds: [4, 5, 6], workspaceDispatch: "workspace 5" },
    });
    assert.equal(mode.ok, false);
    assert.ok(mode.errors.indexOf("bar.workspaceDispatch") !== -1);
    assert.equal(mode.settings.bar.workspaceDispatch, "auto");
});

test("non-object settings are rejected", function () {
    const result = settings.validateSettings("nope");
    assert.equal(result.ok, false);
    assert.equal(result.errors[0], "settings");
    assert.equal(result.settings.bar.targetMonitor, "HDMI-A-1");
});

test("theme defaults stay readable on black and white", function () {
    const opacity = settings.DEFAULTS.appearance.panelOpacity;
    assert.equal(palette.readableOnExtremes("dark", opacity).ok, true);
    assert.equal(palette.readableOnExtremes("light", opacity).ok, true);
    const sampled = palette.resolvePalette("dark", "wallpaper");
    assert.equal(sampled.adaptive, false);
    assert.equal(sampled.adaptiveReason, "Wallpaper tint is not sampled yet.");
    assert.deepEqual(sampled.panel, palette.resolvePalette("dark", "neutral").panel);
});

test("motion defaults sit inside the restrained ranges", function () {
    assert.deepEqual(theme.motionDurations(false, 1), { open: 180, close: 120, hover: 80 });
    assert.deepEqual(theme.motionDurations(true, 1), { open: 0, close: 0, hover: 0 });
    assert.deepEqual(theme.motionDurations(false, 0), { open: 0, close: 0, hover: 0 });
    assert.equal(theme.motionDurations(false, 2).open, 180);
});

test("calendar month grid and iso weeks", function () {
    assert.equal(calendar.isoWeekNumber(2005, 0, 1), 53);
    assert.equal(calendar.isoWeekNumber(2005, 0, 3), 1);
    assert.equal(calendar.weekStartIndex("sunday", 1, 7), 0);
    assert.equal(calendar.weekStartIndex("monday", 7, 7), 1);
    assert.equal(calendar.weekStartIndex("locale", 7, 7), 0);
    assert.equal(calendar.weekStartIndex("locale", 1, 7), 1);
    assert.deepEqual(calendar.shiftMonth(2026, 0, -1), { year: 2025, month: 11 });

    const october = calendar.buildMonth(2026, 9, 1, 2026, 9, 30);
    assert.equal(october.weeks[0].days[3].day, 1);
    assert.equal(october.weeks[0].days[3].inMonth, true);
    const today = october.weeks.flatMap(function (week) { return week.days; }).find(function (day) {
        return day.inMonth && day.day === 30;
    });
    assert.equal(today.isToday, true);
    assert.equal(new Date(2026, 9, 30).getDay(), 5);
});

test("popup placement stays inside logical screen bounds", function () {
    const logicalWidth = 1920 / 1.5;
    const placed = popover.placePopup({
        anchorX: 1200,
        anchorY: 28,
        anchorWidth: 40,
        popupWidth: 280,
        popupHeight: 320,
        screenWidth: logicalWidth,
        screenHeight: 1080 / 1.5,
        margin: 8,
        align: "end",
        devicePixelRatio: 1.5,
    });
    assert.equal(placed.logicalPixels, true);
    assert.equal(placed.x, 960);
    assert.equal(placed.y, 28);
    assert.ok(placed.x >= 8);
    assert.ok(placed.x + placed.width <= logicalWidth - 8);

    const clamped = popover.placePopup({
        anchorX: 4,
        anchorY: 900,
        anchorWidth: 20,
        popupWidth: 280,
        popupHeight: 320,
        screenWidth: logicalWidth,
        screenHeight: 720,
        margin: 8,
        align: "end",
    });
    assert.equal(clamped.x, 8);
    assert.equal(clamped.y, 720 - 320 - 8);
});

test("one popover id is open at a time", function () {
    assert.deepEqual(popover.reducePopover("", { type: "toggle", id: "calendar" }), { openId: "calendar", changed: true });
    assert.deepEqual(popover.reducePopover("calendar", { type: "toggle", id: "calendar" }), { openId: "", changed: true });
    assert.deepEqual(popover.reducePopover("calendar", { type: "toggle", id: "control" }), { openId: "control", changed: true });
    assert.deepEqual(popover.reducePopover("control", { type: "close" }), { openId: "", changed: true });
    assert.deepEqual(popover.reducePopover("", { type: "close" }), { openId: "", changed: false });
});

test("audio commands clamp and unmute on an audible volume", function () {
    assert.equal(audio.clampVolume(-1), 0);
    assert.equal(audio.clampVolume(1.4), 1);
    assert.equal(audio.clampVolume("nope"), null);
    assert.equal(audio.percent(0.126), 13);
    assert.deepEqual(audio.volumeCommand(true, 0.4), { volume: 0.4, muted: false });
    assert.deepEqual(audio.volumeCommand(true, 0), { volume: 0, muted: true });
    assert.deepEqual(audio.volumeCommand(false, 0), { volume: 0, muted: false });
    assert.equal(audio.outputLabel(""), "Output");
    assert.equal(audio.outputLabel("/home/secret/sink"), "Output");
    assert.equal(audio.outputLabel("Speakers"), "Speakers");
});

test("settings without appearance keep the new defaults", function () {
    const result = settings.validateSettings({
        version: 1,
        clock: { use24Hour: false },
        bar: {
            targetMonitor: "HDMI-A-1",
            reserveSpace: false,
            showFocusedTitle: true,
            workspaceIds: [4, 5, 6],
        },
    });
    assert.equal(result.ok, true);
    assert.equal(result.settings.clock.use24Hour, false);
    assert.equal(result.settings.clock.showWeekNumbers, false);
    assert.equal(result.settings.clock.weekStart, "locale");
    assert.equal(result.settings.appearance.mode, "dark");
    assert.equal(result.settings.appearance.topGradient, false);
    assert.equal(result.settings.appearance.panelBlur, 1);
});

test("invalid appearance values fall back to the defaults", function () {
    const result = settings.validateSettings({
        appearance: {
            mode: "blue",
            tint: "wallpaper",
            panelOpacity: 0.2,
            topGradient: "yes",
        },
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.indexOf("appearance.mode") !== -1);
    assert.ok(result.errors.indexOf("appearance.panelOpacity") !== -1);
    assert.ok(result.errors.indexOf("appearance.topGradient") !== -1);
    assert.equal(result.settings.appearance.mode, "dark");
    assert.equal(result.settings.appearance.tint, "wallpaper");
    assert.equal(result.settings.appearance.panelOpacity, settings.DEFAULTS.appearance.panelOpacity);
});

test("palette bytes become Qt unit channels and alpha stays a unit", function () {
    assert.equal(palette.byteToUnit(0), 0);
    assert.equal(palette.byteToUnit(255), 1);
    assert.equal(palette.byteToUnit(128), 128 / 255);
    assert.equal(palette.byteToUnit(1), 1 / 255);
    assert.equal(palette.byteToUnit(-20), 0);
    assert.equal(palette.byteToUnit(300), 1);
    assert.equal(palette.byteToUnit("nope"), 0);
    assert.equal(palette.unitAlpha(0.55), 0.55);
    assert.equal(palette.unitAlpha(1.4), 1);
    assert.equal(palette.unitAlpha(-0.2), 0);
    assert.equal(palette.unitAlpha("nope"), 0);

    const light = palette.resolvePalette("light", "neutral");
    const units = palette.colorUnits(light.panel, 0.92);
    assert.equal(units.a, 0.92);
    assert.ok(Math.abs(units.r - (246 / 255)) < 1e-12);
    assert.ok(Math.abs(units.g - (246 / 255)) < 1e-12);
    assert.ok(Math.abs(units.b - (246 / 255)) < 1e-12);
    assert.ok(units.r <= 1 && units.g <= 1 && units.b <= 1);

    const gradient = palette.gradientUnits("light");
    assert.deepEqual(gradient, { r: 1, g: 1, b: 1, a: 0.55 });
    assert.notEqual(gradient.r, 255);
    assert.deepEqual(palette.gradientUnits("dark"), { r: 0, g: 0, b: 0, a: 0.34 });
    assert.equal(palette.colorUnits({ r: 242, g: 242, b: 242 }, undefined).a, 1);
});

test("calendar width stays in logical pixels", function () {
    assert.equal(theme.calendarWidth(28, 22, false), 196);
    assert.equal(theme.calendarWidth(28, 22, true), 218);
    assert.equal(theme.calendarWidth(28, 22, false), 28 * 7);
});

test("calendar handles leap years, year wrap, and a single today", function () {
    assert.equal(clock.formatTime(at(0, 0), true), "00:00");
    assert.equal(clock.formatTime(at(0, 0), false), "12:00 AM");

    const leap = calendar.buildMonth(2024, 1, 1, 2024, 1, 29);
    const leapDays = leap.weeks.flatMap(function (week) { return week.days; }).filter(function (day) {
        return day.inMonth;
    });
    assert.equal(leapDays.length, 29);
    assert.equal(leapDays[28].day, 29);
    assert.equal(leapDays.filter(function (day) { return day.isToday; }).length, 1);
    assert.equal(calendar.isoWeekNumber(2024, 1, 29), 9);

    const common = calendar.buildMonth(2023, 1, 1, 2023, 1, 28);
    const commonDays = common.weeks.flatMap(function (week) { return week.days; }).filter(function (day) {
        return day.inMonth && day.day === 29;
    });
    assert.equal(commonDays.length, 0);
    assert.equal(new Date(2023, 2, 0).getDate(), 28);

    assert.deepEqual(calendar.shiftMonth(2026, 11, 1), { year: 2027, month: 0 });
    assert.deepEqual(calendar.shiftMonth(2024, 0, -1), { year: 2023, month: 11 });
    const january = calendar.buildMonth(2027, 0, 1, 2026, 9, 30);
    assert.equal(january.month, 0);
    assert.equal(january.weeks.flatMap(function (week) { return week.days; }).some(function (day) {
        return day.isToday;
    }), false);

    const october = calendar.buildMonth(2026, 9, 0, 2026, 9, 30);
    assert.equal(october.weeks[0].days[4].day, 1);
    assert.equal(october.weeks[0].days[4].inMonth, true);
    const todays = october.weeks.flatMap(function (week) { return week.days; }).filter(function (day) {
        return day.isToday;
    });
    assert.equal(todays.length, 1);
    assert.equal(todays[0].day, 30);
    assert.equal(todays[0].inMonth, true);

    const midnight = new Date(2026, 9, 31, 0, 0, 0);
    const rolled = calendar.buildMonth(2026, 9, 1, midnight.getFullYear(), midnight.getMonth(), midnight.getDate());
    const rolledToday = rolled.weeks.flatMap(function (week) { return week.days; }).filter(function (day) {
        return day.isToday && day.inMonth;
    });
    assert.equal(rolledToday.length, 1);
    assert.equal(rolledToday[0].day, 31);
});

test("popup anchors use logical pixels on both reference screens", function () {
    const hdmi = popover.logicalScreen(1920, 1080, 1.5);
    const dp = popover.logicalScreen(2560, 1440, 1);
    assert.deepEqual(hdmi, { width: 1280, height: 720 });
    assert.deepEqual(dp, { width: 2560, height: 1440 });
    assert.equal(popover.logicalScreen(1920, 1080, 0), null);

    const hdmiAnchor = popover.anchorFromItemMap(
        { x: 1210, y: 0, width: 48, height: 28 },
        {
            popupWidth: 280,
            popupHeight: 320,
            screenWidth: hdmi.width,
            screenHeight: hdmi.height,
            margin: 8,
            gap: 6,
            align: "end",
            devicePixelRatio: 1.5,
        }
    );
    assert.deepEqual(hdmiAnchor, { x: 978, y: 34, width: 1, height: 1, logicalPixels: true });
    assert.ok(hdmiAnchor.x + 280 <= hdmi.width - 8);
    assert.notEqual(hdmiAnchor.x, 978 * 1.5);

    const dpAnchor = popover.anchorFromItemMap(
        { x: 2460, y: 0, width: 64, height: 28 },
        {
            popupWidth: 280,
            popupHeight: 320,
            screenWidth: dp.width,
            screenHeight: dp.height,
            margin: 8,
            gap: 6,
            align: "end",
            devicePixelRatio: 1,
        }
    );
    assert.deepEqual(dpAnchor, { x: 2244, y: 34, width: 1, height: 1, logicalPixels: true });

    const clamped = popover.anchorFromItemMap(
        { x: 10, y: 0, width: 20, height: 28 },
        {
            popupWidth: 280,
            popupHeight: 700,
            screenWidth: hdmi.width,
            screenHeight: hdmi.height,
            margin: 8,
            gap: 6,
            align: "end",
        }
    );
    assert.equal(clamped.x, 8);
    assert.equal(clamped.y, 12);
    assert.equal(popover.anchorFromItemMap({ x: 1210, y: 0, width: 0, height: 0 }, {
        popupWidth: 280,
        popupHeight: 320,
        screenWidth: hdmi.width,
        screenHeight: hdmi.height,
        margin: 8,
        gap: 6,
    }), null);
});

test("popup phases release input and survive interruption", function () {
    const motion = { instantOpen: false, instantClose: false };
    let state = popover.popupModel();

    state = popover.reducePopup(state, { type: "toggle", id: "calendar" }, motion);
    assert.equal(state.phase, "opening");
    assert.equal(state.grab, true);
    assert.equal(state.interactive, true);
    assert.equal(state.visible, true);

    state = popover.reducePopup(state, { type: "escape" }, motion);
    assert.equal(state.phase, "closing");
    assert.equal(state.grab, false);
    assert.equal(state.interactive, false);
    assert.equal(state.visible, true);
    assert.equal(state.opacity, 0);

    state = popover.reducePopup(state, { type: "animationFinished", opacity: 0 }, motion);
    assert.deepEqual(popover.reducePopup(popover.popupModel(), { type: "close" }, motion).phase, "closed");
    assert.equal(state.phase, "closed");
    assert.equal(state.visible, false);
    assert.equal(state.grab, false);

    state = popover.reducePopup(state, { type: "toggle", id: "calendar" }, motion);
    state = popover.reducePopup(state, { type: "animationFinished", opacity: 1 }, motion);
    assert.equal(state.phase, "open");
    const outside = popover.reducePopup(state, { type: "outside" }, motion);
    assert.equal(outside.phase, "closing");
    assert.equal(outside.suppressId, "calendar");
    assert.equal(outside.grab, false);
    const swallowed = popover.reducePopup(outside, { type: "toggle", id: "calendar" }, motion);
    assert.equal(swallowed.phase, "closing");
    assert.equal(swallowed.suppressId, "");

    state = popover.reducePopup(state, { type: "toggle", id: "calendar" }, motion);
    assert.equal(state.phase, "closing");
    state = popover.reducePopup(state, { type: "animationFinished", opacity: 0 }, motion);
    state = popover.reducePopup(state, { type: "toggle", id: "calendar" }, motion);
    state = popover.reducePopup(state, { type: "animationFinished", opacity: 1 }, motion);
    assert.equal(state.panelId, "calendar");

    state = popover.reducePopup(state, { type: "toggle", id: "control" }, motion);
    assert.equal(state.phase, "open");
    assert.equal(state.panelId, "control");
    state = popover.reducePopup(state, { type: "toggle", id: "calendar" }, motion);
    assert.equal(state.phase, "open");
    assert.equal(state.panelId, "calendar");
    assert.equal(state.grab, true);

    state = popover.reducePopup(popover.popupModel(), { type: "toggle", id: "calendar" }, motion);
    state = popover.reducePopup(state, { type: "close" }, motion);
    const staleOpen = popover.reducePopup(state, { type: "animationFinished", opacity: 1 }, motion);
    assert.equal(staleOpen.phase, "closing");
    assert.equal(staleOpen.interactive, false);
    state = popover.reducePopup(staleOpen, { type: "animationFinished", opacity: 0 }, motion);
    assert.equal(state.phase, "closed");

    state = popover.reducePopup(popover.popupModel(), { type: "toggle", id: "control" }, motion);
    state = popover.reducePopup(state, { type: "animationFinished", opacity: 1 }, motion);
    state = popover.reducePopup(state, { type: "close" }, motion);
    state = popover.reducePopup(state, { type: "toggle", id: "control" }, motion);
    assert.equal(state.phase, "opening");
    assert.equal(state.grab, true);
    assert.equal(state.interactive, true);
    const staleClose = popover.reducePopup(state, { type: "animationFinished", opacity: 0 }, motion);
    assert.equal(staleClose.phase, "opening");
    state = popover.reducePopup(staleClose, { type: "animationFinished", opacity: 1 }, motion);
    assert.equal(state.phase, "open");

    const resized = popover.reducePopup(state, { type: "geometry" }, motion);
    assert.equal(resized.phase, "open");
    assert.equal(resized.panelId, "control");

    const disconnected = popover.reducePopup(state, { type: "monitorLost" }, motion);
    assert.equal(disconnected.phase, "closed");
    assert.equal(disconnected.visible, false);
    assert.equal(disconnected.grab, false);
    assert.equal(disconnected.interactive, false);

    const stopped = popover.reducePopup(
        popover.reducePopup(popover.popupModel(), { type: "toggle", id: "calendar" }, motion),
        { type: "destroy" },
        motion
    );
    assert.equal(stopped.grab, false);
    assert.equal(stopped.visible, false);
    assert.equal(stopped.interactive, false);

    const instant = popover.reducePopup(popover.popupModel(), { type: "toggle", id: "calendar" }, {
        instantOpen: true,
        instantClose: false,
    });
    assert.equal(instant.phase, "open");
    assert.equal(popover.reducePopup(instant, { type: "escape" }, { instantClose: true }).phase, "closed");
    assert.equal(popover.reducePopup(instant, { type: "toggle", id: "launcher" }, motion).panelId, "calendar");

    const hidden = popover.dismissalMotion(0, { instantOpen: false, instantClose: false });
    assert.equal(hidden.instantClose, true);
    assert.equal(popover.dismissalMotion(1, { instantOpen: false, instantClose: false }).instantClose, false);
    const aborted = popover.reducePopup(
        popover.reducePopup(popover.popupModel(), { type: "toggle", id: "calendar" }, motion),
        { type: "close" },
        hidden
    );
    assert.equal(aborted.phase, "closed");
    assert.equal(aborted.visible, false);
    assert.equal(aborted.grab, false);
    assert.equal(aborted.interactive, false);
});

test("audio writes stay on the captured sink", function () {
    assert.equal(audio.sinkIdentity(null), "");
    assert.equal(audio.sinkIdentity(undefined), "");
    assert.equal(audio.sinkIdentity("/tmp/secret"), "");
    assert.equal(audio.sinkIdentity(7), "7");
    assert.equal(audio.volumeWrite({
        ready: false,
        gestureSinkId: "7",
        currentSinkId: "7",
        muted: true,
        requested: 0.4,
    }), null);
    assert.equal(audio.volumeWrite({
        ready: true,
        gestureSinkId: "7",
        currentSinkId: "",
        muted: false,
        requested: 0.4,
    }), null);
    assert.equal(audio.volumeWrite({
        ready: true,
        gestureSinkId: "7",
        currentSinkId: "8",
        muted: false,
        requested: 0.4,
    }), null);
    assert.deepEqual(audio.volumeWrite({
        ready: true,
        gestureSinkId: "7",
        currentSinkId: "7",
        muted: true,
        requested: 1.8,
    }), { volume: 1, muted: false, sinkId: "7" });
    assert.deepEqual(audio.volumeWrite({
        ready: true,
        gestureSinkId: "7",
        currentSinkId: "7",
        muted: true,
        requested: 0,
    }), { volume: 0, muted: true, sinkId: "7" });
    assert.equal(audio.muteWrite({ ready: true, sinkId: "", muted: true }), null);
    assert.deepEqual(audio.muteWrite({ ready: true, sinkId: "7", muted: false }), { muted: false, sinkId: "7" });
    assert.equal(audio.muteWrite({ ready: false, sinkId: "7", muted: true }), null);
});

test("stored blur preference does not enable a background effect", function () {
    assert.deepEqual(popover.panelBlurPolicy(), { supported: false, protocol: "", fallback: "scrim" });
    const stored = settings.validateSettings({ appearance: { panelBlur: 0 } });
    assert.equal(stored.ok, true);
    assert.equal(stored.settings.appearance.panelBlur, 0);
    assert.equal(popover.panelBlurPolicy().supported, false);
    assert.equal(popover.panelBlurPolicy().fallback, "scrim");
});

test("bar exclusion writes one property and popup focus clears before the grab", function () {
    const reserved = bar.exclusionUpdate(true, 28);
    assert.deepEqual(reserved, { property: "exclusiveZone", value: 28 });
    assert.equal(Object.prototype.hasOwnProperty.call(reserved, "exclusionMode"), false);
    const overlay = bar.exclusionUpdate(false, 28);
    assert.deepEqual(overlay, { property: "exclusionMode", value: "ignore" });
    assert.equal(Object.prototype.hasOwnProperty.call(overlay, "exclusiveZone"), false);
    assert.deepEqual(bar.exclusionUpdate(true, 0), { property: "exclusionMode", value: "ignore" });
    assert.equal(bar.exclusionUpdate(true, 28).value, 28);
    assert.equal(bar.layerForBar(), "top");

    const open = popover.reducePopup(popover.popupModel(), { type: "open", id: "calendar" }, { instantOpen: true });
    const entering = popover.focusTransition(popover.popupModel(), open);
    assert.equal(entering.clearFocusBeforeGrab, false);
    assert.equal(entering.grab, true);
    assert.equal(entering.takeFocus, true);
    const leaving = popover.focusTransition(open, popover.reducePopup(open, { type: "close" }, { instantClose: true }));
    assert.equal(leaving.clearFocusBeforeGrab, true);
    assert.equal(leaving.grab, false);
    assert.equal(leaving.takeFocus, false);
    const outside = popover.focusTransition(open, popover.reducePopup(open, { type: "outside" }, { instantClose: false }));
    assert.equal(outside.clearFocusBeforeGrab, true);
    assert.equal(outside.grab, false);
});

test("defaults.json matches the serializer", function () {
    const file = path.join(__dirname, "..", "shell", "config", "defaults.json");
    const text = fs.readFileSync(file, "utf8");
    assert.equal(text, settings.serializeSettings(settings.DEFAULTS));
});

test("desktop entries keep visibility and do not build a shell command", function () {
    const firefox = launcher.parseDesktopEntry([
        "[Desktop Entry]",
        "Type=Application",
        "Name=Firefox",
        "GenericName=Web Browser",
        "Comment=Browse the web",
        "Exec=firefox %u",
        "Icon=firefox",
        "Categories=Network;WebBrowser;",
    ].join("\n"), "firefox.desktop");
    assert.equal(launcher.entryVisible(firefox, ["Hyprland"]), true);
    assert.deepEqual(firefox.command, ["firefox"]);
    assert.equal(firefox.command.indexOf("%u"), -1);

    const quoted = launcher.commandFromExec('kitty -e "foo bar"', { name: "Kitty", icon: "kitty" });
    assert.deepEqual(quoted, ["kitty", "-e", "foo bar"]);
    assert.deepEqual(launcher.commandFromExec("app %%", {}), ["app", "%"]);
    assert.deepEqual(launcher.commandFromExec("app %i", { icon: "firefox" }), ["app", "--icon", "firefox"]);
    assert.deepEqual(launcher.commandFromExec('broken "quote', {}), []);

    const hidden = launcher.parseDesktopEntry("[Desktop Entry]\nType=Application\nName=Secret\nExec=secret\nNoDisplay=true\n", "secret.desktop");
    assert.equal(launcher.entryVisible(hidden, []), false);
    const gnome = launcher.parseDesktopEntry("[Desktop Entry]\nType=Application\nName=Gnome\nExec=gnome\nOnlyShowIn=GNOME;\n", "gnome.desktop");
    assert.equal(launcher.entryVisible(gnome, ["Hyprland"]), false);
    assert.equal(launcher.entryVisible(gnome, []), true);

    const dupes = launcher.dedupeApplications([
        { id: "firefox.desktop", name: "First" },
        { id: "firefox.desktop", name: "Second" },
    ]);
    assert.equal(dupes.length, 1);
    assert.equal(dupes[0].name, "First");
    assert.equal(launcher.iconPath("/usr/share/icons/firefox.png"), "/usr/share/icons/firefox.png");
    assert.equal(launcher.iconPath("firefox"), "");
    assert.equal(launcher.iconPath("/tmp/a\nb"), "");
    assert.equal(launcher.monogram("firefox"), "F");
});

test("launcher ranking is stable and ignores the query as a command", function () {
    const apps = [
        { id: "notes.desktop", name: "Notes", genericName: "", comment: "Editor", categories: [], keywords: [] },
        { id: "editor.desktop", name: "Editor", genericName: "", comment: "Text", categories: ["Utility"], keywords: [] },
        { id: "firefox.desktop", name: "Firefox", genericName: "Web Browser", comment: "", categories: ["Network"], keywords: ["web"] },
        { id: "files.desktop", name: "Files", genericName: "", comment: "", categories: [], keywords: [] },
    ];
    assert.deepEqual(launcher.rank(apps, "editor").map(function (app) { return app.id; }), ["editor.desktop", "notes.desktop"]);
    assert.deepEqual(launcher.rank(apps, "fi").map(function (app) { return app.id; }), ["files.desktop", "firefox.desktop"]);
    assert.deepEqual(launcher.rank(apps, "firefox").map(function (app) { return app.id; }), ["firefox.desktop"]);
    assert.deepEqual(launcher.rank(apps, "ffx").map(function (app) { return app.id; }), ["firefox.desktop"]);
    assert.deepEqual(launcher.rank(apps, "web").map(function (app) { return app.id; })[0], "firefox.desktop");
    assert.deepEqual(launcher.rank(apps, "$(reboot)"), []);
    const plan = launcher.commandFromExec("firefox %u", { name: "Firefox", icon: "firefox" });
    assert.equal(plan.join(" ").indexOf("$(reboot)"), -1);
    assert.equal(plan.indexOf("sh"), -1);

    const rows = launcher.viewRows(apps, "", ["firefox.desktop"], ["notes.desktop"]);
    assert.equal(rows[0].id, "firefox.desktop");
    assert.equal(rows[0].section, "Pinned");
    assert.equal(rows[1].id, "notes.desktop");
    assert.equal(rows[1].section, "Recent");
    assert.equal(rows[rows.length - 1].kind, "power");
    assert.equal(rows.some(function (row) { return row.argv; }), false);

    const armed = launcher.powerStep("", "poweroff");
    assert.equal(armed.run, false);
    assert.equal(armed.argv, null);
    const confirmed = launcher.powerStep("poweroff", "poweroff");
    assert.equal(confirmed.run, true);
    assert.deepEqual(confirmed.argv, ["loginctl", "poweroff"]);
    assert.equal(launcher.powerStep("", "custom").run, false);
    assert.equal(launcher.moveSelection(0, 4, -1), 3);
    assert.equal(launcher.moveSelection(3, 4, 1), 0);

    const recent = launcher.pushRecent(["a.desktop", "b.desktop"], "a.desktop");
    assert.deepEqual(recent, ["a.desktop", "b.desktop"]);
    assert.equal(launcher.pushRecent(["1.desktop", "2.desktop", "3.desktop", "4.desktop", "5.desktop", "6.desktop", "7.desktop", "8.desktop"], "9.desktop").length, 8);

    const pins = settings.validateSettings({ launcher: { pinnedIds: { length: 1, 0: "firefox.desktop" } } });
    assert.equal(pins.ok, true);
    assert.deepEqual(pins.settings.launcher.pinnedIds, ["firefox.desktop"]);
    const badPins = settings.validateSettings({ launcher: { pinnedIds: ["../x", "firefox.desktop"] } });
    assert.equal(badPins.ok, false);
    assert.ok(badPins.errors.indexOf("launcher.pinnedIds") !== -1);
    assert.deepEqual(badPins.settings.launcher.pinnedIds, ["firefox.desktop"]);

    const many = [];
    for (let i = 0; i < 400; i++) {
        many.push({
            id: "app" + i + ".desktop",
            name: "Application " + i,
            genericName: "",
            comment: "Tool number " + i,
            categories: ["Utility"],
            keywords: [],
        });
    }
    const started = process.hrtime.bigint();
    const ranked = launcher.rank(many, "application 12");
    const elapsed = Number(process.hrtime.bigint() - started) / 1e6;
    console.log("launcher rank 400 apps: " + elapsed.toFixed(2) + " ms");
    assert.equal(ranked[0].id, "app12.desktop");
    assert.ok(elapsed < 50, "rank took " + elapsed + " ms");
});

if (failed > 0) {
    console.error(failed + " test(s) failed");
    process.exit(1);
}

console.log("logic tests passed");
