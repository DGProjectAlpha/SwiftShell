const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const settings = require("../shell/logic/settings.js");

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "swiftshell-settings-"));
const live = path.join(dir, "settings.json");
const backup = live + ".bak-swiftshell";

function applyPlan(file, backupFile) {
    const original = fs.readFileSync(file, "utf8");
    const existing = fs.existsSync(backupFile) ? fs.readFileSync(backupFile, "utf8") : "";
    const next = settings.migrationPlan(original, existing);
    if (!next.writeSettings)
        return next;
    if (next.writeBackup) {
        const backupTemp = backupFile + ".tmp";
        fs.writeFileSync(backupTemp, next.backupText);
        fs.renameSync(backupTemp, backupFile);
    }
    assert.equal(settings.commitMigration(next, !next.writeBackup || fs.readFileSync(backupFile, "utf8") === original), true);
    const liveTemp = file + ".tmp";
    fs.writeFileSync(liveTemp, settings.serializeSettings(next.decision.settings));
    fs.renameSync(liveTemp, file);
    return next;
}

const v1 = "{\"version\":1,\"extra\":{\"kept\":true},\"clock\":{\"use24Hour\":false}}\n";
fs.writeFileSync(live, v1);
const raw = fs.readFileSync(live, "utf8");
const plan = settings.migrationPlan(raw, "");
assert.equal(plan.writeBackup, true);
assert.equal(plan.backupText, v1);
assert.equal(settings.commitMigration(plan, false), false);
assert.equal(fs.readFileSync(live, "utf8"), v1);

fs.writeFileSync(backup, plan.backupText);
assert.equal(fs.readFileSync(backup, "utf8"), v1);
fs.writeFileSync(live, settings.serializeSettings(plan.decision.settings));
const migrated = JSON.parse(fs.readFileSync(live, "utf8"));
assert.equal(migrated.version, 3);
assert.equal(migrated.clock.use24Hour, false);
assert.equal(JSON.parse(migrated.extensionsJson).extra.kept, true);
assert.equal(settings.migrationPlan(v1, fs.readFileSync(backup, "utf8")).writeBackup, false);

const v2 = "{\"version\":2,\"bar\":{\"height\":30}}\n";
fs.writeFileSync(path.join(dir, "v2.json"), v2);
assert.equal(settings.migrationFromText(fs.readFileSync(path.join(dir, "v2.json"), "utf8")).action, "migrate");

const defaults = fs.readFileSync(path.join(__dirname, "..", "shell", "config", "defaults.json"), "utf8");
assert.equal(settings.migrationFromText(defaults).action, "keep");

const bad = path.join(dir, "bad.json");
fs.writeFileSync(bad, "{");
const badPlan = settings.migrationPlan(fs.readFileSync(bad, "utf8"), "");
assert.equal(badPlan.writeSettings, false);
assert.equal(fs.readFileSync(bad, "utf8"), "{");

const repairFile = path.join(dir, "repair-v3.json");
const repairBackup = repairFile + ".bak-swiftshell";
const invalidV3 = '{"version":3,"bar":{"height":999},"future":{"enabled":true},"appearance":{"mode":"dark","futureTone":"soft"}}\n';
fs.writeFileSync(repairFile, invalidV3);
applyPlan(repairFile, repairBackup);
assert.equal(fs.readFileSync(repairBackup, "utf8"), invalidV3);
const repairedV3 = JSON.parse(fs.readFileSync(repairFile, "utf8"));
assert.equal(repairedV3.bar.height, 52);
assert.equal(JSON.parse(repairedV3.extensionsJson).future.enabled, true);
assert.equal(JSON.parse(repairedV3.extensionsJson).__nested.appearance.futureTone, "soft");

const repairLegacyFile = path.join(dir, "repair-v1.json");
const repairLegacyBackup = repairLegacyFile + ".bak-swiftshell";
const invalidV1 = '{"version":1,"clock":{"use24Hour":"yes"},"bar":{"height":31}}\n';
fs.writeFileSync(repairLegacyFile, invalidV1);
applyPlan(repairLegacyFile, repairLegacyBackup);
const repairedV1 = JSON.parse(fs.readFileSync(repairLegacyFile, "utf8"));
assert.equal(repairedV1.version, 3);
assert.equal(repairedV1.clock.use24Hour, true);
assert.equal(repairedV1.bar.height, 31);
assert.equal(fs.readFileSync(repairLegacyBackup, "utf8"), invalidV1);

const currentFile = path.join(dir, "current.json");
const currentText = settings.serializeSettings(settings.DEFAULTS);
fs.writeFileSync(currentFile, currentText);
assert.equal(applyPlan(currentFile, currentFile + ".bak-swiftshell").writeSettings, false);
assert.equal(fs.readFileSync(currentFile, "utf8"), currentText);
assert.equal(fs.existsSync(currentFile + ".bak-swiftshell"), false);

const occupiedBackupFile = path.join(dir, "occupied.json");
const occupiedBackup = occupiedBackupFile + ".bak-swiftshell";
fs.writeFileSync(occupiedBackupFile, invalidV1);
fs.writeFileSync(occupiedBackup, v1);
applyPlan(occupiedBackupFile, occupiedBackup);
assert.equal(fs.readFileSync(occupiedBackup, "utf8"), v1);

const wrapped = path.join(dir, "wrapped.json");
fs.writeFileSync(wrapped, JSON.stringify({ document: v1 }));
const restored = settings.restoreBackup(fs.readFileSync(wrapped, "utf8"));
assert.equal(restored.reason, "unwrapped");
fs.writeFileSync(live, restored.text);
assert.equal(fs.readFileSync(live, "utf8"), v1);

console.log("settings file tests passed");
