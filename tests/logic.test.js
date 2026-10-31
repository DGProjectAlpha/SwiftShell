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
const capabilities = require("../shell/logic/capabilities.js");
const material = require("../shell/logic/material.js");
const settingsNav = require("../shell/logic/settingsNav.js");
const wallpaper = require("../shell/logic/wallpaper.js");
const inflate = require("../shell/logic/inflate.js");
const png = require("../shell/logic/png.js");
const contrast = require("../shell/logic/contrast.js");
const slideshow = require("../shell/logic/slideshow.js");
const zlib = require("node:zlib");

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

test("empty workspace ids stay empty for automatic indicators", function () {
    assert.deepEqual(workspaces.normalizeWorkspaceIds(undefined), []);
    assert.deepEqual(workspaces.normalizeWorkspaceIds([]), []);
    assert.deepEqual(workspaces.normalizeWorkspaceIds([0, -1, 4.5, "nope"]), []);
    assert.equal(workspaces.workspaceIdsValid([]), true);
    assert.equal(workspaces.workspaceIdsValid(undefined), true);
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
    assert.equal(result.settings.bar.targetMonitor, "");
    assert.equal(result.settings.bar.reserveSpace, true);
    assert.equal(result.settings.clock.use24Hour, true);
    assert.deepEqual(result.settings.bar.workspaceIds, []);
});

test("invalid settings are reported and repaired without accepting the bad value", function () {
    const result = settings.validateSettings({
        version: 4,
        clock: { use24Hour: "yes" },
        bar: {
            targetMonitor: false,
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
    assert.equal(result.settings.version, 3);
    assert.equal(result.settings.clock.use24Hour, true);
    assert.equal(result.settings.bar.targetMonitor, "");
    assert.equal(result.settings.bar.reserveSpace, true);
    assert.deepEqual(result.settings.bar.workspaceIds, [4]);
});

test("version 1 settings migrate and unknown keys stay in the extension bag", function () {
    const migrated = settings.migrationDecision({
        version: 1,
        bar: { targetMonitor: "HDMI-A-1", workspaceIds: [4, 5, 6] },
        extra: { kept: true },
    });
    assert.equal(migrated.action, "migrate");
    assert.equal(migrated.settings.version, 3);
    assert.equal(migrated.settings.bar.targetMonitor, "HDMI-A-1");
    assert.deepEqual(migrated.settings.bar.workspaceIds, [4, 5, 6]);
    assert.equal(JSON.parse(migrated.settings.extensionsJson).extra.kept, true);
    assert.ok(migrated.backupText.indexOf('"version": 1') !== -1);
    assert.equal(settings.migrationDecision(settings.DEFAULTS).action, "keep");
    assert.equal(settings.migrationDecision({ version: 3, clock: { use24Hour: false } }).action, "keep");
    assert.equal(settings.migrationDecision({ version: 2, clock: { use24Hour: false } }).action, "migrate");
    const missing = settings.migrationDecision({ clock: { use24Hour: false } });
    assert.equal(missing.action, "migrate");
    assert.equal(missing.settings.version, 3);
    assert.equal(missing.settings.clock.use24Hour, false);
    assert.equal(settings.migrationDecision({ version: 3 }).action, "keep");
    assert.equal(settings.migrationDecision("broken").action, "keep");
    assert.equal(settings.migrationDecision({ version: 1, clock: { use24Hour: "yes" } }).action, "keep");
    assert.equal(settings.backupPath("/tmp/settings.json"), "/tmp/settings.json.bak-swiftshell");
    assert.equal(settings.backupPath(""), "");
    const sized = settings.validateSettings({
        settingsWindow: { width: 10, height: 5000, category: "displays" },
    }).settings.settingsWindow;
    assert.deepEqual(sized, { width: 640, height: 1200, category: "appearance" });
    assert.equal(settings.opacityFromUnit(0), 0.72);
    assert.equal(settings.opacityFromUnit(1), 0.96);
    assert.equal(settings.unitFromOpacity(0.92), (0.92 - 0.72) / 0.24);
    assert.equal(settings.radiusFromUnit(0), 6);
    assert.equal(settings.radiusFromUnit(1), 12);
    assert.equal(settings.radiusFromUnit(settings.unitFromRadius(10)), 10);
    const brokenBag = settings.validateSettings({ extensionsJson: "nope" });
    assert.equal(brokenBag.ok, false);
    assert.equal(brokenBag.settings.extensionsJson, "{}");
});

test("settings window stays one instance and blur is not available", function () {
    const report = capabilities.capabilityReport();
    assert.equal(report.settingsToplevel.available, true);
    assert.equal(report.settingsToplevel.hardwareVerified, false);
    assert.equal(report.settingsToplevel.clientMove, false);
    assert.equal(report.backdropBlur.available, false);
    assert.equal(report.backdropBlur.hardwareVerified, false);
    const surface = material.materialReport().backdropBlur;
    assert.equal(surface.available, false);
    assert.equal(surface.fallback, "scrim");
    assert.equal(surface.hardwareVerified, false);
    assert.equal(surface.reason, material.BLUR_REASON);
    assert.equal(report.backdropBlur.reason, material.BLUR_REASON);
    assert.ok(surface.surfaces.indexOf("bar") !== -1);
    assert.ok(surface.surfaces.indexOf("settings") !== -1);
    let session = capabilities.reduceSettingsWindow(undefined, "launch");
    session = capabilities.reduceSettingsWindow(session, "launch");
    assert.equal(session.open, true);
    assert.equal(session.instances, 1);
    assert.equal(session.focused, true);
    session = capabilities.reduceSettingsWindow(session, "close");
    assert.equal(session.open, false);
    assert.equal(session.instances, 0);
    assert.equal(session.focused, false);
    session = capabilities.reduceSettingsWindow(session, "load-failed");
    assert.equal(session.open, false);
    assert.equal(session.reason, "The settings window could not be created");
    session = capabilities.reduceSettingsWindow({ open: true, instances: 1, focused: true, reason: "" }, "compositor-close");
    assert.equal(session.instances, 0);
});

test("settings search, density, and undo stay on real appearance fields", function () {
    assert.equal(settingsNav.navigationLayout(719), "stacked");
    assert.equal(settingsNav.navigationLayout(720), "columns");
    assert.equal(settingsNav.categories().length, 3);
    assert.equal(settingsNav.categories()[0].id, "appearance");
    assert.equal(settingsNav.categories()[1].id, "bar");
    assert.equal(settingsNav.categories()[2].id, "wallpaper");
    assert.equal(settingsNav.categoryFor(settingsNav.firstControlId("cover")), "wallpaper");
    assert.equal(settingsNav.filterControls("").length, settingsNav.CONTROLS.length);
    assert.equal(settingsNav.filterControls("not-a-setting").length, 0);
    const opacity = settingsNav.filterControls("opacity").map(function (item) { return item.id; });
    assert.ok(opacity.indexOf("panelOpacity") !== -1);
    assert.ok(opacity.indexOf("wallpaperTint") === -1);
    assert.equal(settingsNav.firstControlId("radius"), "radius");
    assert.equal(settingsNav.moveSelection("radius", "radius", 1), "radius");
    assert.equal(settingsNav.controlVisible("theme", "mode"), true);
    assert.equal(settingsNav.controlVisible("theme", "backdropBlur"), false);
    const density = settingsNav.densityFromUnit(settingsNav.unitFromDensity(12));
    assert.equal(density.panelPadding, 12);
    assert.equal(density.panelSpacing, 8);
    assert.equal(settingsNav.fontSizeFromUnit(settingsNav.unitFromFontSize(12)), 12);
    assert.equal(settingsNav.shadowOpacityFromUnit(settingsNav.unitFromShadowOpacity(0.16)), 0.16);
    assert.equal(settingsNav.shadowSoftnessFromUnit(settingsNav.unitFromShadowSoftness(10)), 10);
    assert.equal(settingsNav.iconScaleFromUnit(settingsNav.unitFromIconScale(1)), 1);
    assert.equal(settingsNav.scrollTarget(100, 80, 40, 20), 40);
    assert.equal(settingsNav.scrollTarget(0, 80, 90, 20), 30);
    assert.equal(settingsNav.scrollTarget(10, 80, 20, 20), 10);
    let history = settings.initialHistory(settings.DEFAULTS.appearance);
    history = settings.reduceAppearanceHistory(history, {
        type: "edit",
        present: Object.assign({}, history.present, { mode: "light", fontSize: 16 }),
    });
    assert.equal(history.present.mode, "light");
    assert.equal(history.present.fontSize, 16);
    assert.equal(history.past.length, 1);
    assert.equal(history.past[0].mode, "dark");
    history = settings.reduceAppearanceHistory(history, { type: "undo" });
    assert.equal(history.present.mode, "dark");
    assert.equal(history.present.fontSize, 12);
    assert.equal(history.past.length, 0);
    history = settings.reduceAppearanceHistory(history, { type: "undo" });
    assert.equal(history.present.mode, "dark");
    history = settings.reduceAppearanceHistory(history, {
        type: "edit",
        present: Object.assign({}, history.present, { radius: 12 }),
    });
    history = settings.reduceAppearanceHistory(history, { type: "reset" });
    assert.equal(history.present.radius, settings.DEFAULTS.appearance.radius);
    assert.equal(history.past.length, 2);
    assert.equal(history.past[1].radius, 12);
});

test("wallpaper source, crop, and per-output paths", function () {
    assert.equal(wallpaper.resolveSource("").source, "packaged");
    assert.equal(wallpaper.resolveSource("default").reason, "");
    assert.equal(wallpaper.resolveSource("../secret.png").source, "packaged");
    assert.ok(wallpaper.resolveSource("notes.txt").reason.length > 0);
    assert.equal(wallpaper.resolveSource("/tmp/photo.JPEG").source, "file");
    assert.equal(wallpaper.fileUrl("/tmp/my photo.png"), "file:///tmp/my%20photo.png");
    assert.equal(wallpaper.fileUrl("file:///tmp/a.png"), "file:///tmp/a.png");
    const specific = wallpaper.sourceForOutput("HDMI-A-1", "/tmp/a.png", JSON.stringify({ "HDMI-A-1": "/tmp/b.jpg" }));
    assert.equal(specific.path, "/tmp/b.jpg");
    assert.equal(wallpaper.sourceForOutput("DP-1", "/tmp/a.png", "{}").path, "/tmp/a.png");
    assert.equal(wallpaper.sourceForOutput("DP-1", "/tmp/a.png", "nope").source, "file");
    const cover = wallpaper.cropRect(2560, 1440, 1920, 1080, "cover");
    assert.equal(cover.width, 1920);
    assert.equal(cover.height, 1080);
    assert.equal(cover.x, 0);
    assert.equal(cover.y, 0);
    const wide = wallpaper.cropRect(2000, 1000, 1000, 1000, "cover");
    assert.equal(wide.x, -500);
    assert.equal(wide.width, 2000);
    assert.equal(wide.y, 0);
    const contained = wallpaper.cropRect(2000, 1000, 1000, 1000, "contain");
    assert.equal(contained.width, 1000);
    assert.equal(contained.height, 500);
    assert.equal(contained.y, 250);
    const portrait = wallpaper.cropRect(1000, 2000, 1920, 1080, "cover");
    assert.equal(portrait.width, 1920);
    assert.ok(portrait.height > 1080);
    assert.ok(portrait.y < 0);
    assert.deepEqual(wallpaper.cropRect(0, 10, 10, 10, "cover"), { x: 0, y: 0, width: 0, height: 0 });
    assert.deepEqual(wallpaper.decodeLimit(8000, 2000), { width: 3840, height: 960 });
    assert.deepEqual(wallpaper.decodeLimit(100, 50), { width: 100, height: 50 });
    assert.equal(fs.existsSync(path.join(__dirname, "..", "shell", "assets", "wallpapers", "swiftshell-default-crimson.png")), true);
    const rejected = settings.validateSettings({
        version: 3,
        wallpaper: { path: "../secret.png", fit: "stretch", outputsJson: "[]", enabled: "yes" },
    });
    assert.equal(rejected.ok, false);
    assert.equal(rejected.settings.wallpaper.enabled, true);
    assert.equal(rejected.settings.wallpaper.path, "");
    assert.equal(rejected.settings.wallpaper.fit, "cover");
    assert.equal(rejected.settings.wallpaper.outputsJson, "{}");
    const accepted = settings.validateSettings({
        version: 3,
        wallpaper: {
            enabled: false,
            fit: "contain",
            path: "/tmp/a.webp",
            outputsJson: JSON.stringify({ "DP-1": "/tmp/b.png", bad: "nope.txt" }),
        },
    });
    assert.equal(accepted.ok, true);
    assert.equal(accepted.settings.wallpaper.enabled, false);
    assert.equal(accepted.settings.wallpaper.path, "/tmp/a.webp");
    assert.equal(JSON.parse(accepted.settings.wallpaper.outputsJson)["DP-1"], "/tmp/b.png");
    assert.equal(JSON.parse(accepted.settings.wallpaper.outputsJson).bad, undefined);
    const slides = settings.validateSettings({
        version: 3,
        wallpaper: {
            slideshow: true,
            intervalMinutes: 1,
            order: "shuffle",
            transitionMs: 0,
            slidesJson: JSON.stringify(["/tmp/a.png", "notes.txt", "../x.png"]),
        },
        appearance: { manualText: "#ABCDEF", manualPanel: "red" },
    });
    assert.equal(slides.ok, false);
    assert.equal(slides.settings.appearance.manualText, "#abcdef");
    assert.equal(slides.settings.appearance.manualPanel, "");
    assert.deepEqual(JSON.parse(slides.settings.wallpaper.slidesJson), ["/tmp/a.png"]);
    assert.equal(slides.settings.wallpaper.transitionMs, 0);
});

test("slideshow and wallpaper contrast are deterministic", function () {
    png.bindInflate(inflate.inflateZlib);
    const resolve = wallpaper.resolveSource;
    let session = slideshow.reduceSlideshow(slideshow.emptySession(), { type: "scan" });
    assert.equal(session.state, "scanning");
    session = slideshow.reduceSlideshow(session, {
        type: "scanned",
        enabled: true,
        paths: ["/a.png", "/b.png", "notes.txt"],
        mode: "sequential",
        transitionMs: 400,
        intervalMinutes: 30,
    }, { resolveSource: resolve });
    assert.equal(session.state, "waiting");
    assert.equal(session.count, 2);
    assert.equal(session.unreadable, 1);
    assert.equal(session.shown, "/a.png");
    session = slideshow.reduceSlideshow(session, { type: "tick" });
    assert.equal(session.state, "preloading");
    assert.equal(session.incoming, "/b.png");
    assert.equal(session.shown, "/a.png");
    const during = slideshow.reduceSlideshow(session, { type: "tick" });
    assert.equal(during.state, "preloading");
    session = slideshow.reduceSlideshow(session, { type: "loaded" });
    assert.equal(session.state, "transitioning");
    assert.equal(session.outgoing, "/a.png");
    session = slideshow.reduceSlideshow(session, { type: "finish" });
    assert.equal(session.state, "waiting");
    assert.equal(session.shown, "/b.png");
    assert.equal(session.incoming, "");
    const one = slideshow.reduceSlideshow(null, {
        type: "scanned",
        enabled: true,
        paths: ["/a.png"],
        mode: "sequential",
        transitionMs: 0,
        intervalMinutes: 1,
    }, { resolveSource: resolve });
    assert.equal(slideshow.reduceSlideshow(one, { type: "tick" }).shown, "/a.png");
    const fast = slideshow.reduceSlideshow(slideshow.reduceSlideshow(null, {
        type: "scanned",
        enabled: true,
        paths: ["/a.png", "/b.png"],
        mode: "sequential",
        transitionMs: 0,
        intervalMinutes: 5,
    }, { resolveSource: resolve }), { type: "tick" });
    assert.equal(slideshow.reduceSlideshow(fast, { type: "loaded" }).state, "waiting");
    assert.equal(slideshow.reduceSlideshow(fast, { type: "failed" }).state, "error");
    assert.equal(slideshow.reduceSlideshow(fast, { type: "failed" }).shown, "/a.png");
    const empty = slideshow.reduceSlideshow(null, {
        type: "scanned",
        enabled: true,
        paths: [],
        mode: "sequential",
        transitionMs: 400,
        intervalMinutes: 30,
    }, { resolveSource: resolve });
    assert.equal(empty.state, "error");
    const shuffled = slideshow.reduceSlideshow({ shown: "/a.png" }, {
        type: "scanned",
        enabled: true,
        paths: ["/a.png", "/b.png"],
        mode: "shuffle",
        transitionMs: 0,
        intervalMinutes: 30,
    }, { resolveSource: resolve, random: function () { return 0; } });
    assert.equal(shuffled.shown, "/b.png");
    assert.equal(slideshow.reduceSlideshow(shuffled, { type: "pause" }).state, "paused");
    assert.equal(slideshow.reduceSlideshow(slideshow.reduceSlideshow(shuffled, { type: "pause" }), { type: "tick" }).state, "paused");
    assert.equal(slideshow.intervalMs(1), 60000);
    assert.equal(slideshow.intervalMs(30), 1800000);
    assert.equal(contrast.chooseForeground({ r: 0, g: 0, b: 0 }, "").foreground, "light");
    assert.equal(contrast.chooseForeground({ r: 255, g: 255, b: 255 }, "light").foreground, "dark");
    assert.equal(contrast.chooseForeground({ r: 0, g: 0, b: 0 }, "light").foreground, "light");
    const split = contrast.analyzeBands({
        ok: true,
        left: { r: 0, g: 0, b: 0 },
        center: { r: 128, g: 128, b: 128 },
        right: { r: 255, g: 255, b: 255 },
    }, null);
    assert.equal(split.available, true);
    assert.equal(split.scrim, true);
    const red = contrast.desaturate({ r: 200, g: 10, b: 10 });
    assert.ok(Math.max(red.r, red.g, red.b) - Math.min(red.r, red.g, red.b) <= 28);
    const manual = { manualText: "#112233" };
    const colored = contrast.surfaceColors({
        mode: "dark",
        automaticText: false,
        manualText: manual.manualText,
        analysis: { available: true, foreground: "dark", scrim: false, accent: { r: 255, g: 0, b: 0 } },
    });
    assert.equal(colored.text.r, 0x11);
    assert.equal(manual.manualText, "#112233");
    const automatic = contrast.surfaceColors({
        mode: "dark",
        automaticText: true,
        automaticGradient: true,
        manualText: "#112233",
        analysis: { available: true, foreground: "light", scrim: false, accent: { r: 180, g: 20, b: 20 } },
    });
    assert.equal(automatic.text.r, 242);
    assert.ok(Math.max(automatic.gradient.r, automatic.gradient.g, automatic.gradient.b) - Math.min(automatic.gradient.r, automatic.gradient.g, automatic.gradient.b) <= 28);
    function chunk(type, data) {
        const body = Buffer.concat([Buffer.from(type), data]);
        const crc = Buffer.alloc(4);
        crc.writeUInt32BE(zlib.crc32(body) >>> 0);
        const length = Buffer.alloc(4);
        length.writeUInt32BE(data.length);
        return Buffer.concat([length, body, crc]);
    }
    const raw = Buffer.from([
        0, 255, 255, 255, 0, 0, 0,
        0, 0, 0, 0, 255, 0, 0,
    ]);
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(2, 0);
    ihdr.writeUInt32BE(2, 4);
    ihdr[8] = 8;
    ihdr[9] = 2;
    const file = Buffer.concat([
        Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
        chunk("IHDR", ihdr),
        chunk("IDAT", zlib.deflateSync(raw)),
        chunk("IEND", Buffer.alloc(0)),
    ]);
    const decoded = png.decodePng(file);
    assert.equal(decoded.ok, true);
    assert.equal(decoded.width, 2);
    assert.equal(decoded.pixels[0], 255);
    assert.equal(decoded.pixels[9], 255);
    assert.equal(png.decodePng(Buffer.from("nope")).ok, false);
    const crimson = png.decodePng(fs.readFileSync(path.join(__dirname, "..", "assets", "wallpapers", "swiftshell-default-crimson.png")));
    assert.equal(crimson.ok, true);
    const top = png.topBands(crimson, 8);
    assert.ok(top.left.r > top.left.g);
    const looked = contrast.analyzeBands(top, null);
    assert.equal(looked.available, true);
    assert.equal(looked.foreground, "light");
    const again = contrast.analyzeBands(top, looked);
    assert.equal(again.foreground, "light");
    const pale = contrast.analyzeBands({
        ok: true,
        left: { r: 250, g: 250, b: 250 },
        center: { r: 250, g: 250, b: 250 },
        right: { r: 250, g: 250, b: 250 },
    }, looked);
    assert.equal(pale.foreground, "dark");
});

test("blank monitor text means automatic placement", function () {
    const blank = settings.validateSettings({ bar: { targetMonitor: " ", workspaceIds: [] } });
    assert.equal(blank.ok, true);
    assert.equal(blank.settings.bar.targetMonitor, "");
    assert.deepEqual(blank.settings.bar.workspaceIds, []);
    const kept = settings.validateSettings({ bar: { targetMonitor: "HDMI-A-1", workspaceIds: [4, 5, 6] } });
    assert.equal(kept.ok, true);
    assert.equal(kept.settings.bar.targetMonitor, "HDMI-A-1");
    assert.deepEqual(kept.settings.bar.workspaceIds, [4, 5, 6]);
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
    assert.equal(result.settings.bar.targetMonitor, "");
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

test("bar exclusion can turn reservation on again and popup focus clears before the grab", function () {
    const reserved = bar.exclusionUpdate(true, 28, 0);
    assert.deepEqual(reserved, { mode: "normal", zone: 28, writeZone: true });
    const again = bar.exclusionUpdate(true, 28, 28);
    assert.deepEqual(again, { mode: "normal", zone: 28, writeZone: false });
    const overlay = bar.exclusionUpdate(false, 28, 28);
    assert.deepEqual(overlay, { mode: "ignore", zone: null, writeZone: false });
    assert.deepEqual(bar.exclusionUpdate(true, 0, 28), { mode: "ignore", zone: null, writeZone: false });
    assert.equal(bar.layerForBar(), "top");
    const normal = bar.barMetrics(28, 1);
    assert.equal(normal.height, 28);
    assert.equal(normal.font, 12);
    assert.equal(normal.icon, 16);
    assert.equal(normal.marginH, 10);
    assert.equal(normal.moduleSpacing, 12);
    assert.equal(normal.hit, 28);
    const tall = bar.barMetrics(52, 1);
    assert.equal(tall.height, 52);
    assert.equal(tall.font, 22);
    assert.ok(tall.icon <= 30);
    assert.equal(bar.barMetrics(10, 1).height, 22);
    assert.equal(bar.barMetrics(80, 1).height, 52);
    assert.equal(bar.heightFromUnit(bar.unitFromHeight(28)), 28);
    assert.equal(bar.exclusionUpdate(true, tall.height, 28).zone, 52);
    assert.deepEqual(bar.visibleModules(bar.BAR_MODULES, ["clock"]), ["workspaces", "title", "search", "control"]);
    const moved = bar.moveModule(bar.BAR_MODULES, "clock", -1);
    assert.equal(moved[2], "clock");
    assert.equal(moved[3], "search");
    assert.deepEqual(bar.toggleHidden(["clock"], "clock"), []);
    assert.deepEqual(bar.toggleHidden([], "clock"), ["clock"]);
    const repaired = settings.validateSettings({ bar: { height: 9, moduleOrder: ["clock", "nope"], hiddenModules: ["search", "search"] } });
    assert.equal(repaired.ok, false);
    assert.equal(repaired.settings.bar.height, 22);
    assert.deepEqual(repaired.settings.bar.moduleOrder, bar.normalizeModuleOrder(["clock"]));
    assert.deepEqual(repaired.settings.bar.hiddenModules, ["search"]);
    assert.equal(repaired.settings.bar.targetMonitor, "");

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
    assert.equal(launcher.iconSource("system-file-manager", function (name) {
        return name === "system-file-manager" ? "image://icon/system-file-manager" : "";
    }), "image://icon/system-file-manager");
    assert.equal(launcher.iconSource("missing", function () { return ""; }), "");
    assert.equal(launcher.iconSource("/usr/share/icons/helium.png", function () { throw new Error("unused"); }), "/usr/share/icons/helium.png");
    assert.equal(launcher.iconSource("firefox", null), "");
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
    const armedPower = launcher.powerInvocation("", "reboot");
    assert.equal(armedPower.run, false);
    assert.equal(armedPower.argv, null);
    const confirmedPower = launcher.powerInvocation("reboot", "reboot");
    assert.equal(confirmedPower.run, true);
    assert.deepEqual(confirmedPower.argv, ["loginctl", "reboot"]);
    assert.equal(JSON.stringify(confirmedPower.argv).indexOf("dolphin"), -1);
    const switchedPower = launcher.powerInvocation("reboot", "poweroff");
    assert.equal(switchedPower.run, false);
    assert.equal(switchedPower.confirmId, "poweroff");
    assert.deepEqual(launcher.inputPlan(true, true), { visible: true, grab: true, keyboard: "exclusive", focusField: true, dismiss: false });
    assert.deepEqual(launcher.inputPlan(false, true), { visible: false, grab: false, keyboard: "none", focusField: false, dismiss: false });
    assert.equal(launcher.inputPlan(true, false).dismiss, true);
    assert.equal(launcher.inputPlan(true, false).grab, false);
    assert.equal(launcher.revealOffset(0, 100, 180, 28), 108);
    assert.equal(launcher.revealOffset(80, 100, 20, 28), 20);
    assert.equal(launcher.revealOffset(40, 100, 50, 28), 40);

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

test("desktop discovery waits for the model and searches past the empty grid", function () {
    assert.deepEqual(launcher.readApplicationModel(null), { available: false, entries: [] });
    assert.deepEqual(launcher.readApplicationModel({ values: null }), { available: false, entries: [] });
    const pending = launcher.readApplicationModel({ values: { length: 0 } });
    assert.equal(pending.available, true);
    assert.equal(pending.entries.length, 0);
    assert.equal(launcher.snapshotApplications(pending.entries).applications.length, 0);

    const dolphinText = [
        "[Desktop Entry]",
        "Type=Application",
        "Name=Dolphin",
        "GenericName=File Manager",
        "Exec=dolphin %u",
        "Icon=system-file-manager",
        "Categories=Qt;KDE;System;FileTools;FileManager;",
    ].join("\n");
    const heliumText = [
        "[Desktop Entry]",
        "Type=Application",
        "Name=Helium",
        "Exec=helium",
        "Icon=helium",
    ].join("\n");
    const dolphin = launcher.parseDesktopEntry(dolphinText, "org.kde.dolphin");
    const helium = launcher.parseDesktopEntry(heliumText, "helium");
    assert.equal(launcher.entryVisible(dolphin, ["Hyprland"]), true);
    assert.deepEqual(dolphin.command, ["dolphin"]);
    assert.equal(launcher.entryVisible(helium, ["Hyprland"]), true);
    assert.deepEqual(helium.command, ["helium"]);

    const hidden = launcher.parseDesktopEntry("[Desktop Entry]\nType=Application\nName=Hidden Dolphin\nExec=dolphin\nHidden=true\n", "org.kde.dolphin");
    const model = launcher.readApplicationModel({
        values: {
            length: 3,
            0: dolphin,
            1: helium,
            2: hidden,
        },
    });
    const qmlList = { length: 3, 0: dolphin, 1: helium, 2: hidden };
    assert.equal(Array.isArray(qmlList), false);
    assert.equal(model.entries.length, 3);
    const snap = launcher.snapshotApplications(model.entries);
    assert.equal(snap.applications.length, 2);
    assert.equal(snap.skipped, 1);
    assert.equal(snap.applications[0].id, "org.kde.dolphin");
    assert.equal(snap.applications[0].icon, "system-file-manager");
    assert.deepEqual(snap.applications[0].command, ["dolphin"]);

    const duplicate = launcher.snapshotApplications([
        { id: "helium", name: "Helium", command: ["helium"], icon: "helium" },
        { id: "helium", name: "Other Helium", command: ["other"], icon: "other" },
    ]);
    assert.equal(duplicate.applications.length, 1);
    assert.equal(duplicate.applications[0].name, "Helium");

    const catalog = snap.applications.slice();
    for (let i = 0; i < 20; i++) {
        catalog.push({
            id: "extra" + i,
            name: "Extra " + i,
            genericName: "",
            comment: "",
            icon: "extra",
            categories: [],
            keywords: [],
            command: ["extra"],
        });
    }
    const emptyRows = launcher.viewRows(catalog, "", [], []).filter(function (row) { return row.kind === "application"; });
    assert.equal(emptyRows.length, 12);
    assert.ok(catalog.length > emptyRows.length);
    assert.equal(emptyRows.some(function (row) { return row.id === "helium"; }), false);
    assert.equal(launcher.rank(catalog, "dolphin")[0].id, "org.kde.dolphin");
    assert.equal(launcher.rank(catalog, "helium")[0].id, "helium");
    assert.equal(launcher.rank(catalog, "org.kde.dolphin")[0].id, "org.kde.dolphin");
    const searched = launcher.viewRows(catalog, "dolphin", [], []);
    assert.equal(searched[0].id, "org.kde.dolphin");
    assert.equal(searched[0].section, "Results");
    assert.equal(searched[0].icon, "system-file-manager");
    assert.equal(searched.some(function (row) { return row.argv; }), false);
});

test("bar placement follows a saved monitor, then focus, then the first screen", function () {
    const hdmi = { id: "hdmi" };
    const dp = { id: "dp" };
    const laptop = { id: "laptop" };
    const records = [
        monitors.describeScreen({ name: "DP-1", id: "dp" }, "DP-1", "Dell Inc. DP"),
        monitors.describeScreen({ name: "HDMI-A-1", id: "hdmi" }, "HDMI-A-1", "LG Electronics HDMI"),
    ];
    records[0].screen = dp;
    records[1].screen = hdmi;

    const preferred = monitors.selectBarPlacement(records, "HDMI-A-1", { name: "DP-1", description: "Dell Inc. DP" });
    assert.equal(preferred.mode, "preference");
    assert.equal(preferred.screen, hdmi);

    const byDescription = monitors.selectBarPlacement(records, "LG Electronics HDMI", { name: "DP-1" });
    assert.equal(byDescription.mode, "preference");
    assert.equal(byDescription.screen, hdmi);

    const focused = monitors.selectBarPlacement(records, "", { name: "HDMI-A-1" });
    assert.equal(focused.mode, "focused");
    assert.equal(focused.screen, hdmi);

    const disconnected = monitors.selectBarPlacement(
        [records[0]],
        "HDMI-A-1",
        { name: "DP-1", description: "Dell Inc. DP" }
    );
    assert.equal(disconnected.mode, "fallback");
    assert.equal(disconnected.screen, dp);

    const renamed = monitors.selectBarPlacement(records, "hdmi-a-1", { name: "DP-1" });
    assert.equal(renamed.mode, "fallback");
    assert.equal(renamed.screen, dp);

    const alone = monitors.selectBarPlacement(
        [monitors.describeScreen(laptop, "eDP-1", "Laptop Panel")],
        "",
        null
    );
    assert.equal(alone.mode, "fallback");
    assert.equal(alone.screen, laptop);
    assert.equal(monitors.selectBarPlacement([], "HDMI-A-1", { name: "HDMI-A-1" }).mode, "missing");
});

test("spotlight resolves the focused monitor and survives a missing one", function () {
    const hdmi = { id: "hdmi" };
    const dp = { id: "dp" };
    const records = [
        monitors.describeScreen(hdmi, "HDMI-A-1", "LG Electronics HDMI"),
        monitors.describeScreen(dp, "DP-1", "Dell Inc. DP"),
    ];
    const onDp = monitors.resolveLauncherScreen(records, { name: "DP-1" }, hdmi);
    assert.equal(onDp.mode, "focused");
    assert.equal(onDp.screen, dp);
    const onDescription = monitors.resolveLauncherScreen(records, { name: "", description: "LG Electronics HDMI" }, dp);
    assert.equal(onDescription.mode, "focused");
    assert.equal(onDescription.screen, hdmi);

    const noFocus = monitors.resolveLauncherScreen(records, null, dp);
    assert.equal(noFocus.mode, "fallback");
    assert.equal(noFocus.screen, hdmi);
    const disconnectedFocus = monitors.resolveLauncherScreen(records, { name: "eDP-1" }, hdmi);
    assert.equal(disconnectedFocus.mode, "fallback");
    assert.equal(disconnectedFocus.screen, hdmi);

    const gone = monitors.resolveLauncherScreen([], { name: "DP-1" }, dp);
    assert.equal(gone.mode, "last");
    assert.equal(gone.screen, dp);
    assert.equal(monitors.screenListed(dp, []), false);
    assert.equal(monitors.screenListed(dp, [hdmi, dp]), true);
    assert.equal(monitors.resolveLauncherScreen([], null, null).mode, "missing");

    const barPrefersHdmi = monitors.selectBarPlacement(records, "HDMI-A-1", { name: "DP-1" });
    assert.equal(barPrefersHdmi.screen, hdmi);
    assert.equal(onDp.screen, dp);
});

test("workspace rows follow the bar monitor unless ids are explicit", function () {
    const live = [
        { id: 2, name: "2", monitorName: "DP-1", active: false, focused: false, urgent: false },
        { id: 1, name: "1", monitorName: "DP-1", active: true, focused: true, urgent: false },
        { id: 3, name: "3", monitorName: "DP-1", active: false, focused: false, urgent: false },
        { id: 4, name: "4", monitorName: "HDMI-A-1", active: true, focused: false, urgent: false },
        { id: 6, name: "6", monitorName: "HDMI-A-1", active: false, focused: false, urgent: false },
        { id: 5, name: "5", monitorName: "HDMI-A-1", active: false, focused: false, urgent: false },
        { id: -98, name: "special", monitorName: "HDMI-A-1", active: false, focused: false, urgent: false },
    ];
    assert.deepEqual(workspaces.indicatorItems([], live, "DP-1").map(function (item) { return item.id; }), [1, 2, 3]);
    assert.deepEqual(workspaces.indicatorItems([], live, "HDMI-A-1").map(function (item) { return item.id; }), [4, 5, 6]);
    assert.equal(workspaces.indicatorItems([], live, "DP-1")[0].active, true);
    assert.deepEqual(workspaces.indicatorItems([], live, ""), []);
    assert.deepEqual(workspaces.indicatorItems([], [], "eDP-1"), []);

    const explicit = workspaces.indicatorItems([4, 5, 6], live.filter(function (item) { return item.id !== 6; }), "HDMI-A-1");
    assert.deepEqual(explicit.map(function (item) { return item.id; }), [4, 5, 6]);
    assert.equal(explicit[2].exists, false);
    assert.equal(explicit[0].onMonitor, true);
    assert.equal(workspaces.dispatchWorkspaceCommand(5), "hl.dsp.focus({ workspace = 5 })");
});

test("spotlight card stays centered on each monitor", function () {
    assert.ok(launcher.SPOTLIGHT_MAX_WIDTH >= 440 && launcher.SPOTLIGHT_MAX_WIDTH <= 520);
    const content = launcher.spotlightContentHeight(4, 0, { field: 28, row: 28, status: 15, pad: 12, gap: 2 });
    const dp = launcher.spotlightFrame(2560, 1440, content);
    const hdmi = launcher.spotlightFrame(1920, 1080, content);
    const logicalHdmi = launcher.spotlightFrame(1280, 720, content);
    assert.equal(dp.width, 480);
    assert.equal(dp.height, content);
    assert.equal(dp.x, Math.round((2560 - 480) / 2));
    assert.equal(dp.y, Math.round((1440 - content) / 2));
    assert.equal(hdmi.x, Math.round((1920 - 480) / 2));
    assert.equal(hdmi.y, Math.round((1080 - content) / 2));
    assert.equal(logicalHdmi.width, 480);
    assert.equal(logicalHdmi.x, Math.round((1280 - 480) / 2));
    assert.equal(logicalHdmi.y, Math.round((720 - content) / 2));

    const tall = launcher.spotlightFrame(1920, 1080, 4000);
    assert.equal(tall.height, 1080 - 48);
    assert.equal(tall.y, 24);
    assert.equal(tall.x, Math.round((1920 - 480) / 2));
    const narrow = launcher.spotlightFrame(400, 300, content);
    assert.equal(narrow.width, 400 - 48);
    assert.equal(narrow.x, 24);
    assert.equal(launcher.spotlightFrame(0, 0, content).width, 0);
});

test("launcher requests toggle and keyboard focus is released", function () {
    let open = false;
    let seen = "";
    let ready = false;
    function apply(token) {
        const step = launcher.requestAction(open, token, seen, ready);
        seen = step.seen;
        ready = step.ready;
        if (step.action === "open")
            open = true;
        if (step.action === "close")
            open = false;
        return step.action;
    }
    assert.equal(apply("1.10"), "ignore");
    assert.equal(open, false);
    assert.equal(apply("1.10"), "ignore");
    assert.equal(apply("2.10"), "open");
    assert.equal(apply("3.10"), "close");
    assert.equal(apply("4.10"), "open");
    assert.equal(apply(""), "ignore");
    assert.equal(open, true);

    const rows = launcher.viewRows([
        { id: "org.kde.dolphin", name: "Dolphin", genericName: "File Manager", comment: "", icon: "system-file-manager", categories: [], keywords: [], command: ["dolphin"] },
        { id: "helium", name: "Helium", genericName: "", comment: "", icon: "helium", categories: [], keywords: [], command: ["helium"] },
    ], "dolphin", [], []);
    assert.equal(rows[0].id, "org.kde.dolphin");
    assert.equal(rows[0].icon, "system-file-manager");
    assert.equal(launcher.iconSource("system-file-manager", function () { return "image://icon/system-file-manager"; }), "image://icon/system-file-manager");
    assert.equal(launcher.iconSource("missing-theme-icon", function () { return ""; }), "");
    assert.equal(launcher.monogram("Dolphin"), "D");

    let selected = 0;
    const count = 6;
    selected = launcher.moveSelection(selected, count, 1);
    selected = launcher.moveSelection(selected, count, 1);
    assert.equal(selected, 2);
    selected = launcher.moveSelection(selected, count, -1);
    assert.equal(selected, 1);
    const scrolled = launcher.revealOffset(0, 84, 140, 28);
    assert.ok(scrolled + 84 >= 140 + 28);
    assert.equal(launcher.inputPlan(false, true).grab, false);
    assert.equal(launcher.inputPlan(false, true).keyboard, "none");
    assert.equal(launcher.inputPlan(false, false).focusField, false);
    assert.equal(launcher.inputPlan(true, false).dismiss, true);
    assert.equal(launcher.inputPlan(true, false).keyboard, "none");
});

if (failed > 0) {
    console.error(failed + " test(s) failed");
    process.exit(1);
}

console.log("logic tests passed");
