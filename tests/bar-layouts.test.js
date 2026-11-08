const assert=require('node:assert/strict');
const Bar=require('../shell/logic/bar.js');
const Settings=require('../shell/logic/settings.js');
const defaults=Settings.validateSettings({}).settings;
const custom={edge:'right',scale:1.25,order:['clock','workspaces'],sides:{clock:'left'}};
const json=JSON.stringify({'DP-1':custom});
const checked=Settings.validateSettings({bar:{layoutOutputsJson:json}});
assert.equal(checked.ok,true);
assert.equal(Bar.layoutForOutput(checked.settings.bar.layoutOutputsJson,'DP-1',defaults.bar.moduleOrder,'{}').edge,'right');
assert.equal(Bar.layoutForOutput(json,'HDMI-A-1',defaults.bar.moduleOrder,'{}').edge,'top');
assert.equal(Bar.layoutForOutput(json,'DP-1',defaults.bar.moduleOrder,'{}').scale,1.25);
assert.equal(Bar.layoutForOutput(json,'DP-1',defaults.bar.moduleOrder,'{}').order[0],'clock');
assert.equal(JSON.parse(Bar.layoutForOutput(json,'DP-1',defaults.bar.moduleOrder,'{}').sides).clock,'left');
assert.equal(Bar.layoutForOutput(JSON.stringify({'':custom}),'HDMI-A-1',defaults.bar.moduleOrder,'{}').edge,'right');
for(const bad of [{...custom,scale:0},{...custom,scale:8},{...custom,edge:'diagonal'},{...custom,order:['clock','clock']},{...custom,sides:{clock:'nope'}}])
 assert.equal(Settings.validateSettings({bar:{layoutOutputsJson:JSON.stringify({'DP-1':bad})}}).ok,false);
assert.equal(Settings.validateSettings({bar:{layoutOutputsJson:'{"__proto__":{}}'}}).ok,false);
assert.equal(Settings.validateSettings({bar:{layoutOutputsJson:'[]'}}).ok,false);
assert.equal(Settings.validateSettings({bar:{moduleOrder:['clock']}}).settings.bar.moduleOrder.includes('notifications'),true);
assert.equal(JSON.parse(Settings.serializeSettings(checked.settings)).bar.layoutOutputsJson,checked.settings.bar.layoutOutputsJson);
console.log('PASS per-output edge/scale/order/group inheritance, validation, additive migration and persistence');

const legacy=Settings.validateSettings({bar:{moduleOrder:['clock','workspaces','title'],hiddenModules:['title'],hiddenOutputsJson:'{"DP-1":["clock"]}',layoutOutputsJson:json}}).settings.bar;
assert.deepEqual(legacy.moduleOrder.slice(0,3),['clock','workspaces','title']);
for(const id of ['screenshot','clipboard','performance']) {
 assert.equal(legacy.moduleOrder.includes(id),true);
 assert.equal(Bar.layoutForOutput(legacy.layoutOutputsJson,'DP-1',legacy.moduleOrder,'{}').order.includes(id),true);
 assert.equal(Bar.hiddenForOutput(legacy.hiddenModules,legacy.hiddenOutputsJson,'DP-1').includes(id),false);
 assert.notEqual(Bar.moduleName(id),id);
}
assert.deepEqual(Bar.hiddenForOutput(legacy.hiddenModules,legacy.hiddenOutputsJson,'DP-1'),['clock']);
assert.deepEqual(Bar.hiddenForOutput(legacy.hiddenModules,legacy.hiddenOutputsJson,'HDMI-A-1'),['title']);
console.log('PASS desktop tools migrate into per-display module lists without changing existing order or visibility');

const Png=require('../shell/logic/png.js'),Wallpaper=require('../shell/logic/wallpaper.js');
const pixels=[];
for(let y=0;y<100;y++)for(let x=0;x<100;x++)pixels.push(...(x<10 ? [255,0,0] : x>=90 ? [0,0,255] : y>=90 ? [0,0,0] : [255,255,255]));
for(const [edge,rgb] of [['top',[255,255,255]],['bottom',[0,0,0]],['left',[255,0,0]],['right',[0,0,255]]]){
 const bands=Png.visibleBands({ok:true,width:100,height:100,bpp:3,pixels},100,100,'cover',10,Wallpaper.cropRect,edge);
 assert.deepEqual(bands.center,{r:rgb[0],g:rgb[1],b:rgb[2]});
}

const originalOrder=Bar.normalizeModuleOrder(['clock','search','screenshot']);
const movedOrder=Bar.moveModuleTo(originalOrder,'clock',2);
assert.deepEqual(movedOrder.slice(0,3),['search','screenshot','clock']);
assert.deepEqual(originalOrder.slice(0,3),['clock','search','screenshot']);
assert.equal(new Set(movedOrder).size,Bar.BAR_MODULES.length);
for(const destination of [-1,100,1.5,NaN])assert.deepEqual(Bar.moveModuleTo(originalOrder,'clock',destination),originalOrder);
assert.deepEqual(Bar.moveModuleTo(originalOrder,'missing',1),originalOrder);
console.log('PASS direct module drop insertion preserves membership and rejects invalid destinations');

// A size-only edit must inherit other fields, survive serialization and never
// rewrite the sibling output (the original Top bar Apply-to defect).
const base={height:28,reserveSpace:true,use24Hour:true,showDate:true};
let scoped=Bar.patchOutputLayouts(json,'HDMI-A-1',{height:42,scale:1,reserveSpace:false,showSeconds:true});
assert.deepEqual(JSON.parse(scoped)['DP-1'],custom);
let validated=Settings.validateSettings({bar:{layoutOutputsJson:scoped}});
assert.equal(validated.ok,true);
scoped=JSON.parse(Settings.serializeSettings(validated.settings)).bar.layoutOutputsJson;
assert.equal(Bar.layoutForOutput(scoped,'HDMI-A-1',defaults.bar.moduleOrder,'{}',base).height,42);
assert.equal(Bar.layoutForOutput(scoped,'DP-1',defaults.bar.moduleOrder,'{}',base).height,28);
scoped=Bar.patchOutputLayouts(scoped,'',{height:36,scale:1,showSeconds:false});
for(const output of ['DP-1','HDMI-A-1','new-output']) {
 const layout=Bar.layoutForOutput(scoped,output,defaults.bar.moduleOrder,'{}',base);
 assert.equal(layout.height,36);assert.equal(layout.scale,1);assert.equal(layout.showSeconds,false);
}
assert.equal(Bar.layoutForOutput(scoped,'DP-1',defaults.bar.moduleOrder,'{}',base).edge,'right');
assert.equal(Bar.layoutForOutput(scoped,'HDMI-A-1',defaults.bar.moduleOrder,'{}',base).reserveSpace,false);
scoped=Bar.patchOutputLayouts(scoped,'HDMI-A-1',{height:24});
assert.equal(Bar.layoutForOutput(scoped,'HDMI-A-1',defaults.bar.moduleOrder,'{}',base).height,24);
assert.equal(Bar.layoutForOutput(scoped,'DP-1',defaults.bar.moduleOrder,'{}',base).height,36);
assert.equal(Bar.layoutForOutput(scoped,'HDMI-A-1',defaults.bar.moduleOrder,'{}',base).showDate,true);
for(const bad of [{height:0},{height:79},{height:24.5},{height:'32'},{reserveSpace:1},{showSeconds:'yes'},{dateFormat:'nope'}])
 assert.equal(Settings.validateSettings({bar:{layoutOutputsJson:JSON.stringify({'DP-1':bad})}}).ok,false);
for(const height of [22,28,52,78])assert.equal(Bar.sizeFromUnit(Bar.unitFromSize(height)),height);
console.log('PASS per-display size/behavior isolation, sparse inheritance, all-display edits and persisted validation');

// Target dimensions replace the old whole-container transform. Device DPR is
// deliberately absent: Qt applies it once when rasterizing each native output.
for(const [height,font,icon] of [[28,12,16],[32,14,18],[42,18,24],[78,33,45]]) {
 const metrics=Bar.targetBarMetrics(28,height,1,13);
 assert.equal(metrics.height,height);
 assert.equal(metrics.font,font);
 assert.equal(metrics.icon,icon);
 for(const key of ['font','icon','marginH','moduleSpacing','workspaceGap','bodyFont','smallFont','valueFont','temperatureFont','railWidth'])
  assert.equal(Number.isInteger(metrics[key]),true,key+' must be drawn at its final target size');
}
const left=Bar.targetBarMetrics(28,32,1,13),right=Bar.targetBarMetrics(28,28,1,13);
assert.equal(left.font,14);assert.equal(right.font,12);
assert.equal(Bar.targetBarMetrics(28,28*1.25,1,13).height,35);
assert.equal(Bar.targetBarMetrics(28,NaN,1,13).height,28);
console.log('PASS direct target-size font/icon metrics and independent/legacy bar sizes without DPR multiplication');
