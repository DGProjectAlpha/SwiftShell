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

const Png=require('../shell/logic/png.js'),Wallpaper=require('../shell/logic/wallpaper.js');
const pixels=[];
for(let y=0;y<100;y++)for(let x=0;x<100;x++)pixels.push(...(x<10 ? [255,0,0] : x>=90 ? [0,0,255] : y>=90 ? [0,0,0] : [255,255,255]));
for(const [edge,rgb] of [['top',[255,255,255]],['bottom',[0,0,0]],['left',[255,0,0]],['right',[0,0,255]]]){
 const bands=Png.visibleBands({ok:true,width:100,height:100,bpp:3,pixels},100,100,'cover',10,Wallpaper.cropRect,edge);
 assert.deepEqual(bands.center,{r:rgb[0],g:rgb[1],b:rgb[2]});
}
