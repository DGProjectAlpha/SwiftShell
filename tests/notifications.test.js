const assert=require('node:assert/strict');
const N=require('../shell/logic/notifications.js');
const settings=require('../shell/logic/settings.js');
function reduce(state,action){return N.reduceNotifications(state,action)}
let s=reduce(N.emptyCenter(),{type:'configure',ownership:'on',dnd:false,historyLimit:20});
s=reduce(s,{type:'receive',now:1000,notification:{id:1,summary:'First',actions:[{identifier:'default',text:'Open'}]}});
assert.equal(N.allEntries(s).filter(x=>x.unread).length,1);
s=reduce(s,{type:'archive',id:1});
assert.equal(s.live.length,0);assert.equal(s.history[0].nativeAlive,true);assert.equal(s.history[0].actions.length,1);
s=reduce(s,{type:'snooze',id:1,now:2000,durationMs:5000});
assert.equal(s.history[0].snoozedUntil,7000);
s=reduce(s,{type:'receive',now:3000,notification:{id:1,summary:'Updated while snoozed'}});
assert.equal(s.live.length,0);assert.equal(s.history[0].snoozedUntil,7000);
s=reduce(s,{type:'tick',now:6999});assert.equal(s.live.length,0);
s=reduce(s,{type:'tick',now:7000});assert.equal(s.live.length,1);assert.equal(s.live[0].summary,'Updated while snoozed');
s=reduce(s,{type:'read-all'});assert.equal(N.allEntries(s)[0].unread,false);
s=reduce(s,{type:'snooze',id:1,now:8000,durationMs:1000});
s=reduce(s,{type:'configure',ownership:'on',dnd:true});s=reduce(s,{type:'tick',now:9000});
assert.equal(s.live.length,0);assert.equal(s.history[0].snoozedUntil,0);assert.equal(s.history[0].unread,true);
s=reduce(s,{type:'closed',id:1});assert.equal(s.history[0].nativeAlive,false);assert.deepEqual(s.history[0].actions,[]);
s=reduce(s,{type:'dismiss',id:1});assert.equal(N.allEntries(s).length,0);
s=reduce(s,{type:'receive',notification:{id:2,transient:true,summary:'Temporary'}});assert.equal(N.allEntries(s).length,0);
s=reduce(s,{type:'configure',ownership:'on',dnd:false});
for(let id=3;id<203;id++)s=reduce(s,{type:'receive',notification:{id,summary:'Burst'}});
assert.equal(s.live.length,4);assert.equal(s.history.length,20);
assert.equal(N.policyFor({'org.foo.desktop':'hide'},'org.foo'),'hide');
assert.equal(N.policyFor({'org.foo':'quiet'},'org.foo.desktop'),'quiet');
const conf=settings.validateSettings({notifications:{bannerDuration:10,historyLimit:100,screenTarget:'HDMI-A-1',quietUntil:1234567}}).settings.notifications;
assert.equal(conf.bannerDuration,10);assert.equal(conf.historyLimit,100);assert.equal(conf.screenTarget,'HDMI-A-1');assert.equal(conf.quietUntil,1234567);
const invalid=settings.validateSettings({notifications:{bannerDuration:Infinity,historyLimit:10000,screenTarget:'bad / target',quietUntil:-1}});
assert.equal(invalid.errors.length,4);
console.log('Notification lifecycle, snooze, source close, policies, bounded burst and settings regressions passed');

// DND and rule edits affect existing native and local entries, without replay.
let live=reduce(N.emptyCenter(),{type:'configure',ownership:'on',dnd:false});
live=reduce(live,{type:'receive',notification:{id:-1,local:true,desktopEntry:'swiftshell.clock',summary:'Clock'}});
live=reduce(live,{type:'receive',notification:{id:50,desktopEntry:'mail',urgency:'critical'}});
live=reduce(live,{type:'configure',ownership:'on',dnd:true});
assert.equal(live.live.length,1);assert.equal(live.live[0].id,50);assert.equal(live.history[0].id,-1);
live=reduce(live,{type:'configure',ownership:'on',dnd:false});assert.equal(live.live.length,1);
live=reduce(live,{type:'configure',ownership:'on',dnd:false,policies:{'swiftshell.clock':'hide',mail:'hide'}});
assert.equal(N.allEntries(live).length,0);
assert.doesNotThrow(()=>reduce(null,{type:'configure',ownership:'on'}));
const when=(day,hour,minute=0)=>new Date(2026,10,day,hour,minute).getTime();
assert.equal(N.scheduledQuiet(true,1320,420,1,when(2,22)),true); // Monday starts
assert.equal(N.scheduledQuiet(true,1320,420,1,when(3,6,59)),true);
assert.equal(N.scheduledQuiet(true,1320,420,1,when(3,7)),false);
assert.equal(N.scheduledQuiet(true,1320,420,1,when(2,6)),false); // Sunday not selected
assert.equal(N.scheduledQuiet(true,1320,420,31,when(7,6)),true); // Friday tail Saturday
assert.equal(N.scheduledQuiet(true,1320,420,31,when(7,23)),false);
assert.equal(N.scheduledQuiet(true,540,1020,1,when(2,12)),true);
assert.equal(N.scheduledQuiet(true,540,1020,1,when(2,17)),false);
assert.equal(N.scheduledQuiet(true,0,0,1,when(2,12)),true);
assert.equal(N.scheduledQuiet(true,0,0,1,when(3,12)),false);
assert.equal(N.scheduledQuiet(false,0,0,127,when(2,12)),false);
assert.equal(N.scheduledQuiet(true,-1,0,127,when(2,12)),false);
assert.equal(N.safeImageSource('https://example.org/private.png'),'');
assert.equal(N.safeImageSource('//example.org/private.png'),'');
assert.equal(N.safeImageSource('file:///tmp/owned.png'),'file:///tmp/owned.png');
assert.equal(N.safeImageSource('image://qsimage/123'),'image://qsimage/123');
assert.equal(N.safeImageSource('image://qsimage/123\0secret'),'');
for(const patch of [{quietStart:1440},{quietDays:0},{soundVolume:2},{soundEnabled:'yes'},{previewMode:'unknown'}])assert.equal(settings.validateSettings({notifications:patch}).ok,false);
const defaults=settings.validateSettings({}).settings.notifications;
assert.equal(defaults.soundEnabled,false);assert.equal(defaults.quietHoursEnabled,false);assert.equal(defaults.previewMode,'full');

let priority=reduce(N.emptyCenter(),{type:'configure',ownership:'on',dnd:false});
for(let id=1;id<=4;id++)priority=reduce(priority,{type:'receive',notification:{id,summary:'Ordinary'}});
priority=reduce(priority,{type:'receive',notification:{id:5,urgency:'critical',summary:'Important'}});
assert.equal(priority.live.length,4);assert.equal(priority.live[3].id,5);assert.equal(priority.live[3].expireMs,0);
assert.equal(priority.history.length,1);assert.equal(priority.history[0].nativeAlive,true);
priority=reduce(priority,{type:'receive',notification:{id:5,urgency:'critical',expireTimeout:1,summary:'Explicit timeout'}});
assert.equal(priority.live[3].expireMs,1000);

priority=reduce(priority,{type:'snooze',id:5,now:1000,durationMs:1000});
priority=reduce(priority,{type:'receive',notification:{id:6,summary:'Another ordinary'}});
priority=reduce(priority,{type:'tick',now:2000});
assert.equal(priority.live.length,4);assert.equal(priority.live.some(item=>item.id===5),true);
