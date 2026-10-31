const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const settings = require("../shell/logic/settings.js");

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "swiftshell-settings-"));
const live = path.join(dir, "settings.json");
const backup = live + ".bak-swiftshell";

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

const wrapped = path.join(dir, "wrapped.json");
fs.writeFileSync(wrapped, JSON.stringify({ document: v1 }));
const restored = settings.restoreBackup(fs.readFileSync(wrapped, "utf8"));
assert.equal(restored.reason, "unwrapped");
fs.writeFileSync(live, restored.text);
assert.equal(fs.readFileSync(live, "utf8"), v1);

console.log("settings file tests passed");
