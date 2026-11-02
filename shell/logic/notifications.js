var HISTORY_CAP = 60;
var BANNER_CAP = 4;

// Quiet hours use local calendar time. Overnight tails belong to their start day.
function scheduledQuiet(enabled,start,end,days,now) {
    if(!enabled || !Number.isInteger(start) || !Number.isInteger(end) || !Number.isInteger(days) || start<0 || start>1439 || end<0 || end>1439 || days<1 || days>127)return false;
    const date=new Date(now),minute=date.getHours()*60+date.getMinutes(),day=(date.getDay()+6)%7;
    if(!Number.isFinite(date.getTime()))return false;
    const selected=function(value){return (days & (1 << value))!==0};
    if(start===end)return selected(day);
    if(start<end)return selected(day) && minute>=start && minute<end;
    return minute>=start ? selected(day) : minute<end && selected((day+6)%7);
}
function timeLabel(value) {return String(Math.floor(value/60)).padStart(2,"0")+":"+String(value%60).padStart(2,"0")}
function safeImageSource(value) {
    if(typeof value!=="string" || value.length>4096 || /[\x00-\x1f]/.test(value))return "";
    if(/^image:\/\//.test(value) || /^file:\/\/\//.test(value) || /^\/(?!\/)/.test(value))return value;
    return "";
}
function emptyCenter() {
    return { ownership: "off", dnd: false, policies: {}, historyLimit:HISTORY_CAP, live: [], history: [], sequence: 1,
        lastRoute: { id: -1, disposition: "ignored" } };
}
function clip(value, max) {
    if (typeof value !== "string") return "";
    const text = value.replace(/\0/g, "").trim();
    return text.length > max ? text.slice(0, max - 3) + "..." : text;
}
function actionRecords(actions) {
    const out = [], source = Array.isArray(actions) ? actions : [];
    for (let i = 0; i < source.length && out.length < 6; i++) {
        const item = source[i];
        const text = typeof item === "string" ? item : item && (item.text || item.identifier);
        const identifier = item && typeof item.identifier === "string" ? item.identifier : "";
        if (clip(text, 40)) out.push({ text: clip(text, 40), identifier: identifier });
    }
    return out;
}
function expireMs(timeoutSeconds) {
    const value = Number(timeoutSeconds);
    if (value === 0) return 0;
    if (!Number.isFinite(value) || value < 0) return 5000;
    return Math.min(86400000, Math.max(1000, Math.round(value * 1000)));
}
function nativeClose(native, kind) {
    if (!native) return "missing";
    if (kind === "expire" && typeof native.expire === "function") { native.expire(); return "expire"; }
    if (typeof native.dismiss === "function") { native.dismiss(); return "dismiss"; }
    return "missing";
}
function entryFrom(raw, sequence, now) {
    const source = raw || {};
    return {
        id: typeof source.id === "number" && Number.isFinite(source.id) ? source.id : sequence,
        appName: clip(source.appName, 80) || "Application", summary: clip(source.summary, 160) || "Notification",
        body: clip(source.body, 2000), urgency: source.urgency === "critical" ? "critical" : "normal",
        desktopEntry: clip(source.desktopEntry, 128), actions: actionRecords(source.actions),
        appIcon: clip(source.appIcon, 4096),image:safeImageSource(source.image),
        hasInlineReply:source.hasInlineReply === true,replyPlaceholder:clip(source.replyPlaceholder,100),suppressSound:source.suppressSound === true,
        expireMs: expireMs(source.urgency==="critical" && (source.expireTimeout===undefined || source.expireTimeout<0) ? 0 : source.expireTimeout),
        preview: source.preview === true, local:source.local === true, transient: source.transient === true,
        nativeAlive: source.nativeAlive !== false, receivedAt: now, unread: true, snoozedUntil: 0
    };
}
function clone(state) {
    const current = state && Array.isArray(state.live) ? state : emptyCenter();
    return { ownership: current.ownership === "on" ? "on" : "off", dnd: current.dnd === true,
        policies: current.policies || {}, historyLimit: current.historyLimit || HISTORY_CAP, live: current.live.slice(), history: current.history.slice(),
        sequence: current.sequence || 1, lastRoute: current.lastRoute || {id:-1,disposition:"ignored"} };
}
function without(items, id) { return items.filter(function(item) { return item.id !== id; }); }
function remember(next, item) {
    if (item.preview || item.transient) return;
    next.history = [item].concat(without(next.history,item.id)).slice(0, next.historyLimit);
}
function enqueueBanner(next,item) {
    if(item.urgency==="critical" && next.live.length>=BANNER_CAP) {
        const ordinary=next.live.findIndex(function(row){return row.urgency!=="critical"});
        if(ordinary>=0){remember(next,next.live[ordinary]);next.live.splice(ordinary,1)}
    }
    if(next.live.length>=BANNER_CAP)return false;
    next.live.push(item);return true;
}
function parsePolicies(text) {
    try {
        const parsed = typeof text === "string" ? JSON.parse(text) : text;
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
        const out = {};
        Object.keys(parsed).slice(0,200).forEach(function(key) {
            if (["quiet","hide","show"].indexOf(parsed[key]) !== -1) out[key] = parsed[key];
        });
        return out;
    } catch (error) { return {}; }
}
function policyFor(policies, desktopEntry) {
    const key=typeof desktopEntry === "string" ? desktopEntry.replace(/\.desktop$/, "") : "";
    const value = policies && (policies[desktopEntry] || policies[key] || policies[key+".desktop"]);
    return value === "quiet" || value === "hide" ? value : "show";
}
function placement(next, item) {
    const policy = policyFor(next.policies, item.desktopEntry);
    if (policy === "hide") return "drop";
    if (item.urgency === "critical" || (policy === "show" && !next.dnd)) return "banner";
    return "history";
}
function policyRows(text) {
    const policies = parsePolicies(text);
    return Object.keys(policies).map(function(key) { return {id:key,value:policies[key]}; });
}
function allEntries(state) {
    const ids = {}, result = [];
    (state.live || []).concat(state.history || []).forEach(function(item) {
        if (!item.preview && !ids[item.id]) {ids[item.id] = true;result.push(item);}
    });
    return result.sort(function(a,b) { return b.receivedAt-a.receivedAt; });
}
function groupHistory(history) {
    const groups = [];
    (history || []).forEach(function(item) {
        const key = item.desktopEntry || item.appName;
        let group = groups.find(function(row) {return row.key === key;});
        if (!group) {group={key:key,app:item.appName || "Application",items:[]};groups.push(group);}
        group.items.push(item);
    });
    return groups;
}
function reduceNotifications(state, action) {
    const next = clone(state), type = action && action.type;
    const now = action && Number.isFinite(action.now) ? action.now : Date.now();
    if (type === "configure") {
        next.ownership = action.ownership === "on" ? "on" : "off";
        next.dnd = action.dnd === true;
        if(Number.isFinite(action.historyLimit)) next.historyLimit=Math.max(20,Math.min(200,Math.round(action.historyLimit)));
        next.history=next.history.slice(0,next.historyLimit);
        if (action.policies !== undefined) next.policies = parsePolicies(action.policies);
        if(state && next.ownership===state.ownership && next.dnd===state.dnd && next.historyLimit===state.historyLimit && JSON.stringify(next.policies)===JSON.stringify(state.policies))return state;
        // Reconfigure every source, including local Clock entries. Never replay history.
        const keep=[];
        next.history=next.history.filter(function(item){return placement(next,item)!=="drop"});
        next.live.forEach(function(item){
            const route=placement(next,item);
            if(route==="drop")return;
            if(next.ownership === "on" && route==="banner")keep.push(item);
            else remember(next,item);
        });
        next.live=keep;
        return next;
    }
    if (type === "clear-history") {next.history=[];return next;}
    if (type === "read-all") {
        const read=function(item){return Object.assign({},item,{unread:false});};
        next.live=next.live.map(read);next.history=next.history.map(read);return next;
    }
    if (type === "remove") {next.live=without(next.live,action.id);next.history=without(next.history,action.id);return next;}
    if (type === "closed") {
        const closed=function(item){return item.id === action.id ? Object.assign({},item,{nativeAlive:false,actions:[],image:"",hasInlineReply:false,snoozedUntil:0}) : item;};
        next.live.filter(function(item){return item.id===action.id;}).forEach(function(item){remember(next,closed(item));});
        next.live=without(next.live,action.id);next.history=next.history.map(closed);return next;
    }
    if (next.ownership !== "on") return next;
    if (type === "receive" || type === "preview") {
        const item=entryFrom(type === "preview" ? Object.assign({},action.notification,{preview:true,id:-1}) : action.notification,next.sequence++,now);
        const previous=next.live.concat(next.history).find(function(row){return row.id===item.id;});
        if(previous && previous.snoozedUntil>now) item.snoozedUntil=previous.snoozedUntil;
        next.live=without(next.live,item.id);next.history=without(next.history,item.id);
        const place=type === "preview" ? "banner" : placement(next,item);
        const shown=place==="banner" && !item.snoozedUntil && enqueueBanner(next,item);
        if(!shown && place!=="drop")remember(next,item);
        next.lastRoute={id:item.id,disposition:place === "drop" ? "drop" : next.live.indexOf(item)!==-1 ? "banner" : "history"};
        return next;
    }
    if (type === "snooze") {
        const item=next.live.concat(next.history).find(function(row){return row.id===action.id;});
        if(!item || item.preview || item.transient) return next;
        const duration=Math.max(1000,Math.min(86400000,Number(action.durationMs)||300000));
        next.live=without(next.live,action.id);
        remember(next,Object.assign({},item,{snoozedUntil:now+duration,unread:false}));return next;
    }
    if(type === "wake") {
        next.history=next.history.map(function(item){return item.id===action.id ? Object.assign({},item,{snoozedUntil:now}) : item;});
        return reduceNotifications(next,{type:"tick",now:now});
    }
    if (type === "tick") {
        const due=next.history.filter(function(item){return item.snoozedUntil>0 && item.snoozedUntil<=now;});
        due.forEach(function(item){
            const awake=Object.assign({},item,{snoozedUntil:0,unread:true,receivedAt:now});
            next.history=without(next.history,item.id);
            if(placement(next,awake)!=="banner" || !enqueueBanner(next,awake))remember(next,awake);
        });return next;
    }
    if(type === "archive") {
        const item=next.live.find(function(row){return row.id===action.id;});
        next.live=without(next.live,action.id);if(item) remember(next,item);return next;
    }
    if (type === "dismiss" || type === "expire") {
        const item=next.live.find(function(row){return row.id===action.id;});
        next.live=without(next.live,action.id);
        if(type === "expire" && item) remember(next,Object.assign({},item,{nativeAlive:item.local === true,actions:item.local ? item.actions : []}));
        if(type === "dismiss") next.history=without(next.history,action.id);
        return next;
    }
    return next;
}
function shouldTrack(state) { return !!(state && state.ownership === "on"); }
var swiftshellNotifications={scheduledQuiet:scheduledQuiet,timeLabel:timeLabel,safeImageSource:safeImageSource,HISTORY_CAP:HISTORY_CAP,BANNER_CAP:BANNER_CAP,emptyCenter:emptyCenter,reduceNotifications:reduceNotifications,
    shouldTrack:shouldTrack,parsePolicies:parsePolicies,policyFor:policyFor,groupHistory:groupHistory,policyRows:policyRows,
    expireMs:expireMs,nativeClose:nativeClose,actionRecords:actionRecords,allEntries:allEntries};
if(typeof module!=="undefined" && module && module.exports) module.exports=swiftshellNotifications;
