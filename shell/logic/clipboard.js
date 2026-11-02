function filter(history,query,now) {
    const term=String(query || "").trim().toLowerCase();
    return history.filter(function(item){return now-item.time<1200000 && item.text.toLowerCase().indexOf(term)>=0});
}
function preview(text) {return String(text || "").replace(/\s+/g," ").trim();}
function meta(text) {
    const lines=String(text || "").split(/\r?\n/).length;
    return text.length+" characters"+(lines>1 ? " · "+lines+" lines" : "");
}
if(typeof module!=="undefined" && module && module.exports)module.exports={filter:filter,preview:preview,meta:meta};
