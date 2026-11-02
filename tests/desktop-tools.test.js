const assert=require('node:assert/strict');
const tools=require('../shell/logic/desktoptools.js');
let list=[];
for(let i=0;i<50;i++)list=tools.remember(list,'item '+i,1000+i);
assert.equal(list.length,30);
assert.equal(tools.remember(list,'',2000),list);
assert.equal(tools.remember(list,'a'.repeat(4097),2000),list);
assert.equal(tools.remember(list,'private\0text',2000),list);
list=tools.remember(list,'item 49',3000);assert.equal(list.length,30);
assert.equal(tools.results(list,'item',3000).length,0);
assert.equal(tools.results(list,'clip item 49',3000)[0].value,'item 49');
assert.equal(tools.results(list,'clipboard',1204000).length,0);
const handle={activate(){}};
const windows=[{title:'Editor',appId:'org.editor',address:'1',handle},{title:'Browser',appId:'web',address:'2',handle}];
assert.equal(tools.windowResults(windows,'edit')[0].handle,handle);
assert.equal(tools.windowResults(windows,'window browser')[0].name,'Browser');
assert.equal(tools.windowResults(windows,'windows').length,2);
assert.equal(tools.windowResults(windows,'').length,0);
console.log('PASS bounded ephemeral explicit clipboard search and typed window results');

const settings=require('../shell/logic/settings.js');
assert.equal(settings.validateSettings({launcher:{clipboardHistory:'true'}}).ok,false);
assert.equal(settings.validateSettings({launcher:{searchWindows:0}}).ok,false);
assert.equal(settings.validateSettings({}).settings.launcher.clipboardHistory,false);

const windowsLogic=require('../shell/logic/windows.js');
assert.equal(windowsLogic.focusCommand('0xabc','lua'),'eval hl.dispatch(hl.dsp.focus({window="address:0xabc"}))');
assert.equal(windowsLogic.focusCommand('abc','legacy'),'focuswindow address:0xabc');
assert.equal(windowsLogic.focusCommand('0xabc; unsafe()','lua'),'');
