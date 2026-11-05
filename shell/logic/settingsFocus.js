function findControl(node, id) {
    if (!node || !id) return null;
    if (node.controlId === id) return node;
    const children = node.children || [];
    for (let i=0;i<children.length;i++) {
        const found=findControl(children[i],id);
        if(found)return found;
    }
    if(node.controlIds && node.controlIds.indexOf(id)>=0)return node;
    return null;
}
function revealAncestors(node) {
    let current=node;
    while(current) {
        if(typeof current.reveal === "function")current.reveal();
        current=current.parent;
    }
}
function focusFirst(node) {
    if(!node || !node.visible || !node.enabled)return false;
    if(node.contentItem && node.effectiveExpanded !== undefined && focusFirst(node.contentItem))return true;
    if(node.activeFocusOnTab) {node.forceActiveFocus();return true;}
    const children=node.children || [];
    for(let i=0;i<children.length;i++)if(focusFirst(children[i]))return true;
    return false;
}
