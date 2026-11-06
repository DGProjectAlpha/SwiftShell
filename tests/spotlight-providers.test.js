const assert=require('node:assert/strict');
const search=require('../shell/logic/search.js');
const launcher=require('../shell/logic/launcher.js');
for(const [query,result] of [['2+2','4'],['2*(3+4)','14'],['2^3^2','512'],['-2^2','-4'],['.5e2/5','10'],['(100-20)*.5','40']])assert.equal(search.calculate(query).value,result,query);
for(const query of ['1/0','2+','2**3','(()=>4)()','process.exit()','constructor.constructor("return 1")()','2;3','2+Math.PI','('.repeat(80)+'1'+')'.repeat(80),'1e999'])assert.equal(search.calculate(query),null,query);
assert.equal(search.convert('42f').value,'5.6 °C');
assert.equal(search.convert('10 km to mi').value,'6.21371192237 mi');
assert.equal(search.convert('12 in to cm').value,'30.48 cm');
assert.equal(search.convert('1kg to lb').value,'2.20462262185 lb');
assert.equal(search.convert('32f to c').value,'0 °C');
assert.equal(search.convert('1kg to m'),null);
assert.equal(search.convert('hello'),null);
assert.equal(search.webAddress('example.com/path?x=1'),'https://example.com/path?x=1');
assert.equal(search.webAddress('https://example.com'),'https://example.com');
for(const query of ['javascript:alert(1)','file:///etc/passwd','https://user:pass@example.com','https://example.com:99999','https://example..com','https://foo-.com','https://999.2.3.4','not a url'])assert.equal(search.webAddress(query),'',query);
assert.equal(search.webResult('a&b ? "hello"').url,'https://www.google.com/search?q=a%26b%20%3F%20%22hello%22');
assert.equal(search.webResult(''),null);
assert.equal(search.webResult('a\nb'),null);
assert.equal(search.webResult('\ud800'),null);
console.log('Spotlight calculator, units, website validation and explicit web fallback passed');
const apps=Array.from({length:35},(_,i)=>({id:'app'+i+'.desktop',name:'App '+String(i).padStart(2,'0'),icon:''}));
assert.equal(launcher.gridRows(apps,'all',[],[]).length,35);
assert.deepEqual(launcher.gridRows(apps,'favorites',['app12.desktop','missing.desktop'],[]).map(a=>a.id),['app12.desktop']);
assert.deepEqual(launcher.gridRows(apps,'recent',[],['app8.desktop','app4.desktop']).map(a=>a.id),['app8.desktop','app4.desktop']);
assert.deepEqual(launcher.toggleFavorite(['app1.desktop'],'app2.desktop'),['app1.desktop','app2.desktop']);
assert.deepEqual(launcher.toggleFavorite(['app1.desktop','app2.desktop'],'app1.desktop'),['app2.desktop']);
assert.deepEqual(launcher.toggleFavorite([],'bad id;rm'),[]);
assert.equal(launcher.powerInvocation('reboot','reboot').action,'reboot');
assert.equal(launcher.powerInvocation('','lock').run,true);
assert.equal(launcher.powerInvocation('lock','lock').action,'lock');
assert.equal(launcher.powerInvocation('logout','logout').action,'logout');
assert.equal(launcher.powerInvocation('','poweroff').run,false);
for(const [w,h] of [[2560,1440],[1536,864],[600,420]]) {const f=launcher.gridFrame(w,h);assert.ok(f.width<=w && f.height<=h && f.x>=0 && f.y>=0);}
console.log('Spotlight complete grids, favorite isolation, confirmed session actions and mixed-scale frames passed');
const settings=require('../shell/logic/settings.js');
assert.equal(settings.validateSettings({version:3,launcher:{pinnedIds:['app1.desktop']}}).settings.launcher.defaultMode,'all');
for(const mode of ['all','favorites','recent']) {
    const result=settings.validateSettings({version:3,launcher:{defaultMode:mode,pinnedIds:['app1.desktop']}});
    assert.equal(result.settings.launcher.defaultMode,mode);
    assert.deepEqual(result.settings.launcher.pinnedIds,['app1.desktop']);
}
const invalid=settings.validateSettings({version:3,launcher:{defaultMode:'unknown'}});
assert.equal(invalid.settings.launcher.defaultMode,'all');
assert.ok(invalid.errors.includes('launcher.defaultMode'));
console.log('Spotlight saved opening modes preserve existing favorites and reject invalid values');

assert.deepEqual(launcher.reorderFavorite(["a.desktop","missing.desktop","b.desktop","c.desktop"],"a.desktop","c.desktop"),["missing.desktop","b.desktop","c.desktop","a.desktop"]);
assert.deepEqual(launcher.reorderFavorite(["a.desktop","b.desktop","c.desktop"],"c.desktop","a.desktop"),["c.desktop","a.desktop","b.desktop"]);
assert.deepEqual(launcher.reorderFavorite(["a.desktop"],"unknown.desktop","a.desktop"),["a.desktop"]);
