const assert=require('node:assert/strict');
const overview=require('../shell/logic/overview.js');
const dp={x:112,y:-88,width:2560,height:1440,scale:1};
const hdmi={x:2672,y:488,width:1920,height:1080,scale:1.25};
assert.deepEqual(overview.logicalMonitor(hdmi),{x:2672,y:488,width:1536,height:864});
assert.deepEqual(overview.logicalMonitor({...dp,transform:1}),{x:112,y:-88,width:1440,height:2560});
const left=overview.windowFrame({at:[117,-53],size:[1270,1400]},dp,512,288);
assert.equal(left.x,1);assert.equal(left.y,7);assert.equal(left.width,254);assert.equal(left.height,280);
const right=overview.windowFrame({at:[1397,-53],size:[1270,1400]},dp,512,288);
assert.equal(right.x,257);assert.equal(right.width,254);
const clipped=overview.windowFrame({at:[0,-200],size:[400,400]},dp,512,288);
assert.equal(clipped.x,0);assert.equal(clipped.y,0);assert.equal(clipped.width,57.6);
assert.equal(overview.workspaceKey({workspace:{address:'gaming',name:'gaming',type:'normal'}}),'gaming');
assert.equal(overview.workspaceKey({workspace:{id:4,name:'4'}}),'4');
assert.equal(overview.workspaceKey({workspace:{address:'special:x',type:'special'}}),'');
for(const count of [1,3,4,8,20]) {
 const g=overview.grid(1000,600,count,16/9);
 assert(g.width>0 && g.height>30);
 assert(g.columns*g.width+(g.columns-1)*18<=1000.01);
 assert(Math.ceil(count/g.columns)*g.height+(Math.ceil(count/g.columns)-1)*18<=600.01);
}
console.log('ok - overview preserves real mixed-scale window layouts, named/empty desktops and bounded grid');

const focus=require('../shell/logic/windows.js').focusCommand;
assert.equal(focus('0xabc','lua'),'eval hl.dispatch(hl.dsp.focus({window="address:0xabc"}))');
assert.equal(focus('abc','legacy'),'focuswindow address:0xabc');
assert.equal(focus('0xabc; unsafe()','lua'),'');
