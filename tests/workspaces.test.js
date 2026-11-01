const assert = require('node:assert/strict');
const W = require('../shell/logic/workspaces.js');
const S = require('../shell/logic/settings.js');
const M = require('../shell/logic/monitors.js');
// Sanitized observed Hyprland 0.57.0 IPC, CachyOS 2026-10-31.
// Preserve the crucial missing numeric id on gaming, persistent empty workspaces,
// simultaneous active workspaces, reversed monitor order, and mixed scale.
const monitors = [
    { id: 0, name: 'HDMI-A-1', model: 'PM161Q C', scale: 1.25, focused: false, activeWorkspace: { address: '4', id: 4, type: 'normal', name: '4' } },
    { id: 1, name: 'DP-1', model: 'HP X32', scale: 1, focused: true, activeWorkspace: { address: 'gaming', type: 'normal', name: 'gaming' } },
];
const workspaces = [
    { address: '4', id: 4, type: 'normal', name: '4', monitor: 'HDMI-A-1', windows: 1, ispersistent: true },
    { address: 'gaming', type: 'normal', name: 'gaming', monitor: 'DP-1', windows: 2, ispersistent: false },
    ...[1,2,3,5,6].map(id => ({ address: String(id), id, type: 'normal', name: String(id), monitor: id < 4 ? 'DP-1' : 'HDMI-A-1', windows: 0, ispersistent: true })),
];
const rules = ['gaming',1,2,3,4,5,6].map(key => ({ workspaceString: key === 'gaming' ? 'name:gaming' : String(key), enabled: true, monitor: key === 'gaming' || key < 4 ? 'DP-1' : 'HDMI-A-1' }));
const live = W.snapshotItems(monitors, workspaces, rules);
const items = (name, json='{}', legacy=[], target='') => W.perMonitorItems(json, legacy, target, live, name);
assert.deepEqual(items('DP-1').map(w=>w.key), ['1','2','3','gaming']);
assert.deepEqual(items('HDMI-A-1').map(w=>w.key), ['4','5','6']);
assert.deepEqual(items('DP-1').filter(w=>w.active).map(w=>w.key), ['gaming']);
assert.equal(items('HDMI-A-1').find(w=>w.active).focused, false);
assert.equal(items('DP-1').find(w=>w.key==='2').windows, 0);
assert.equal(W.snapshotItems(monitors, [], rules).find(w=>w.key==='2').exists, false);
assert.deepEqual(items('DP-1','{}',[1,2,3,4,5,6]).map(w=>w.key), ['1','2','3','gaming']);
assert.deepEqual(items('HDMI-A-1','{}',[1,2,3,4,5,6]).map(w=>w.key), ['4','5','6']);
assert.deepEqual(items('DP-1','{"DP-1":null}',[4,5,6]).map(w=>w.key), ['1','2','3','gaming']);
assert.deepEqual(items('DP-1','{"DP-1":["2","new game"]}').map(w=>w.key), ['2','new game']);
assert.deepEqual(items('HDMI-A-1','{"DP-1":["2"]}').map(w=>w.key), ['4','5','6']);
assert.equal(items('DP-1','{"DP-1":["4"]}')[0].active, false);
assert.equal(items('DP-1','{"DP-1":["4"]}')[0].elsewhere, true);
assert.deepEqual(items('DP-1','{"DP-1":[]}'), []);
assert.equal(W.parseOverrides('{"DP-1":["1","1"]}'), null);
assert.equal(W.dispatchAddressCommand('gaming','lua',true), 'hl.dsp.focus({ workspace = "name:gaming" })');
assert.equal(W.dispatchAddressCommand('4','lua',true), 'hl.dsp.focus({ workspace = 4 })');
assert.equal(W.dispatchAddressCommand('gaming','legacy',false), 'workspace name:gaming');
assert.equal(W.dispatchAddressCommand('bad\nname','lua',true), '');
assert.equal(W.dispatchAddressCommand('a"}); evil() --','lua',true), 'hl.dsp.focus({ workspace = "name:a\\"}); evil() --" })');
const document = { version:3, bar:{targetMonitor:'HDMI-A-1', workspaceIds:[4,5,6],reserveSpace:false}, custom:{keep:true} };
const migrated = S.validateSettings(document).settings;
assert.deepEqual(migrated.bar.workspaceIds, [4,5,6]);
assert.equal(migrated.bar.targetMonitor, 'HDMI-A-1');
assert.equal(migrated.bar.reserveSpace, false);
assert.equal(migrated.bar.workspaceOutputsJson,'{}');
assert.equal(JSON.parse(migrated.extensionsJson).custom.keep,true);
for (const bad of ['[]','{"DP-1":["1","1"]}','{"DP-1":["special:test"]}','{"DP-1":[3]}'])
    assert.equal(S.validateSettings({bar:{workspaceOutputsJson:bad}}).ok,false);
const custom = S.validateSettings({bar:{workspaceOutputsJson:'{"DP-1":["gaming","2"],"HDMI-A-1":null}'}}).settings;
assert.deepEqual(S.validateSettings(JSON.parse(S.serializeSettings(custom))).settings, custom);
const records = monitors.map(m=>({name:m.name,hyprlandName:m.name,description:m.model,screen:{name:m.name}}));
assert.equal(M.selectBarPlacement(records,'',monitors[1],'focused').screen.name,'DP-1');
assert.equal(M.selectBarPlacement(records,'',monitors[0],'focused').screen.name,'HDMI-A-1');
assert.equal(M.selectBarPlacement(records,'',monitors[1],'all').screens.length,2);
// Legacy negative-id named workspaces and moved/removed outputs.
assert.equal(W.snapshotItems(monitors,[{id:-1337,name:'gaming',monitor:'DP-1'}],[]).find(w=>w.key==='gaming').active,true);
assert.deepEqual(W.snapshotItems([],[],[]),[]);
assert.equal(W.snapshotItems([], [{id:-1337,name:'inactive game',monitor:'DP-1'}],[])[0].key, 'inactive game');
assert.deepEqual(items('DP-1','{}',[4,5,6],'HDMI-A-1').map(w=>w.key), ['1','2','3','gaming']);
assert.equal(W.dispatchMonitorCommand('HDMI-A-1','lua',true), 'hl.dsp.focus({ monitor = "HDMI-A-1" })');
assert.equal(W.dispatchMonitorCommand('evil"','lua',true), '');
console.log('workspace regressions passed (observed Hyprland 0.57 address data)');
