function remember(history,text,now) {
    if(typeof text!=="string" || !text.trim() || text.length>4096 || text.indexOf("\0")>=0)return history;
    const kept=history.filter(function(item){return item.text!==text && now-item.time<1200000});
    let id=String(now),suffix=0;
    while(kept.some(function(item){return item.id===id}))id=String(now)+"-"+(++suffix);
    return [{text:text,time:now,id:id}].concat(kept).slice(0,30);
}
function results(history,query,now) {
    if(!/^clip(?:board)?(?:\s|$)/i.test(query))return [];
    const term=query.replace(/^clip(?:board)?\s*/i,"").toLowerCase();
    return history.filter(function(item){return now-item.time<1200000 && item.text.toLowerCase().indexOf(term)>=0})
        .slice(0,5).map(function(item){return {kind:"clipboard",id:"clip-"+item.id,name:item.text.replace(/\s+/g," ").slice(0,120),detail:"Clipboard · Enter to copy",value:item.text}});
}
function windowResults(windows,query) {
    const raw=query.trim().toLowerCase();if(!raw)return [];
    const term=raw.replace(/^windows?(?:\s|$)/,"").trim();
    return windows.filter(function(item){return (item.title+" "+item.appId).toLowerCase().indexOf(term)>=0})
        .slice(0,4).map(function(item){return {kind:"window",id:"window-"+item.address,name:item.title || item.appId,detail:"Open window · "+item.appId,address:item.address,handle:item.handle}});
}
if(typeof module!=="undefined" && module && module.exports)module.exports={remember:remember,results:results,windowResults:windowResults};
