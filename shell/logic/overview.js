// Geometry stays in compositor logical coordinates, including negative origins.
function logicalMonitor(monitor) {
    const scale = Math.max(.25, Number(monitor.scale) || 1);
    const rotated = [1, 3, 5, 7].indexOf(Number(monitor.transform)) >= 0;
    return {x: Number(monitor.x) || 0, y: Number(monitor.y) || 0,
        width: Math.max(1, (rotated ? monitor.height : monitor.width) / scale),
        height: Math.max(1, (rotated ? monitor.width : monitor.height) / scale)};
}
function windowFrame(client, monitor, width, height) {
    const bounds = logicalMonitor(monitor);
    const at = client.at || [bounds.x, bounds.y];
    const size = client.size || [bounds.width, bounds.height];
    const left = Math.max(0, Math.min(bounds.width, Number(at[0]) - bounds.x));
    const top = Math.max(0, Math.min(bounds.height, Number(at[1]) - bounds.y));
    const right = Math.max(left, Math.min(bounds.width, Number(at[0]) - bounds.x + Math.max(0, Number(size[0]) || 0)));
    const bottom = Math.max(top, Math.min(bounds.height, Number(at[1]) - bounds.y + Math.max(0, Number(size[1]) || 0)));
    return {x:left / bounds.width * width, y:top / bounds.height * height,
        width:(right-left) / bounds.width * width, height:(bottom-top) / bounds.height * height};
}
function workspaceKey(client) {
    const ws=client.workspace || {};
    if(ws.type && ws.type!=="normal")return "";
    if(ws.address !== undefined)return String(ws.address);
    return ws.id>0 ? String(ws.id) : String(ws.name || "").replace(/^name:/, "");
}
function grid(width, height, count, aspect) {
    const gap=18, label=30, usableWidth=Math.max(1,width), usableHeight=Math.max(1,height);
    let best={columns:1,width:usableWidth,height:usableWidth/aspect+label,score:0};
    for(let columns=1;columns<=Math.max(1,count);columns++) {
        const rows=Math.ceil(Math.max(1,count)/columns);
        const w=Math.min((usableWidth-gap*(columns-1))/columns, Math.max(1,(usableHeight-gap*(rows-1)-label*rows)/rows)*aspect);
        if(w>best.score)best={columns:columns,width:Math.max(1,w),height:Math.max(1,w/aspect)+label,score:w};
    }
    return best;
}
if(typeof module!=="undefined" && module && module.exports)module.exports={logicalMonitor,windowFrame,workspaceKey,grid};
