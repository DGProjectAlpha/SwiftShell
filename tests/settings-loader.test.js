const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');

// Exercise the actual entrypoint handler, so changing it back to a synchronous
// Loader-active mutation reproduces the original failure in this regression.
const source=fs.readFileSync(path.join(__dirname,'../shell/shell.qml'),'utf8');
const loader=source.indexOf('id: settingsLoader');
assert.ok(loader>=0,'Settings Loader must exist in the shell entrypoint');
const handler=source.indexOf('onStatusChanged:',loader);
const opening=source.indexOf('{',handler);
let depth=1,end=opening+1;
while(depth && end<source.length) {
    if(source[end]==='{')depth++;
    if(source[end]==='}')depth--;
    end++;
}
assert.equal(depth,0,'Settings Loader handler must be complete');
const body=source.slice(opening+1,end-1);

function scenario() {
    const queued=[];
    const context={status:3,Loader:{Error:3,Ready:1},settingsLoader:{status:3},SettingsModel:{open:true,failures:0,noteLoadFailed(){this.failures++;this.open=false;}},Qt:{callLater(callback){queued.push(callback);}}};
    vm.runInNewContext('(function(){'+body+'})()',context);
    assert.equal(context.SettingsModel.failures,0,'Loader failure must not change its active binding synchronously');
    assert.equal(queued.length,1,'A failed load schedules one guarded callback');
    return {context,flush(){queued.shift()();}};
}

let run=scenario();
run.flush();assert.equal(run.context.SettingsModel.failures,1);
run=scenario();run.context.settingsLoader.status=1;run.flush();
assert.equal(run.context.SettingsModel.failures,0,'A stale failure cannot close a recovered window');
run=scenario();run.context.SettingsModel.open=false;run.flush();
assert.equal(run.context.SettingsModel.failures,0,'A stale callback cannot fail an already closed window');
console.log('PASS actual Settings Loader handler: deferred failure, recovered-load guard and closed-window guard');
