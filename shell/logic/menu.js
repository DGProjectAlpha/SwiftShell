// Presentation and navigation only. Native QsMenuEntry owns all actions/state.
function values(model) {
    if (!model) return [];
    if (Array.isArray(model)) return model;
    const source=typeof model.length==="number" ? model : model.values;
    if (!source || typeof source==="function" || typeof source.length!=="number") return [];
    const result=[];
    for(let index=0;index<source.length;index++)result.push(source[index]);
    return result;
}
function caption(text) {
    // QsMenuEntry.text is already the native clean label. A literal ampersand
    // (for example Steam's Friends & Chat) must not be stripped a second time.
    return String(text || "").split("\t")[0];
}
function shortcut(text) {return String(text || "").split("\t").slice(1).join(" ");}
function mnemonic(text) {
    const raw=String(text || "").split("\t")[0];
    for(let index=0;index<raw.length-1;index++) {
        if(raw[index]!=="&")continue;
        if(raw[index+1]==="&") {index++;continue;}
        return raw[index+1].toLocaleLowerCase();
    }
    return "";
}
function selectable(entry) {return !!entry && entry.isSeparator!==true && entry.enabled!==false;}
function nextIndex(model,current,delta) {
    const entries=values(model),count=entries.length;
    if(!count)return -1;
    for(let step=1;step<=count;step++) {
        const index=((current+delta*step)%count+count)%count;
        if(selectable(entries[index]))return index;
    }
    return -1;
}
function matchingIndex(model,current,text,accelerator) {
    const entries=values(model),needle=String(text || "").toLocaleLowerCase();
    if(!needle)return -1;
    for(let step=1;step<=entries.length;step++) {
        const index=((current+step)%entries.length+entries.length)%entries.length,entry=entries[index];
        if(!selectable(entry))continue;
        const label=accelerator ? mnemonic(entry.text) : caption(entry.text).trim().toLocaleLowerCase();
        if(accelerator ? label===needle : label.indexOf(needle)===0)return index;
    }
    return -1;
}
var swiftshellMenu={values:values,caption:caption,shortcut:shortcut,mnemonic:mnemonic,selectable:selectable,nextIndex:nextIndex,matchingIndex:matchingIndex};
if(typeof module!=="undefined" && module && module.exports)module.exports=swiftshellMenu;
