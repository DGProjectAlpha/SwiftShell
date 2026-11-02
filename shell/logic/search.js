// Local providers only. Never evaluate source text or query the network while typing.
function formatNumber(value) {
    if (!Number.isFinite(value)) return "";
    return String(Number(value.toPrecision(12)));
}

function calculate(query) {
    const source=typeof query === "string" ? query.trim().replace(/^=\s*/,"") : "";
    if (!source || source.length>256 || !/[0-9]/.test(source)) return null;
    const tokens=source.match(/(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?|pi|[e()+\-*/%^]/gi) || [];
    if (tokens.join("").toLowerCase()!==source.replace(/\s/g,"").toLowerCase() || tokens.length>128) return null;
    let index=0,depth=0;
    function expression() {
        let value=term();
        while(tokens[index]==="+" || tokens[index]==="-") {
            const operation=tokens[index++],right=term();
            value=operation==="+" ? value+right : value-right;
        }
        return value;
    }
    function term() {
        let value=unary();
        while(tokens[index]==="*" || tokens[index]==="/" || tokens[index]==="%") {
            const operation=tokens[index++],right=unary();
            value=operation==="*" ? value*right : operation==="/" ? value/right : value%right;
        }
        return value;
    }
    function unary() {
        if(tokens[index]==="+") {index++;return unary();}
        if(tokens[index]==="-") {index++;return -unary();}
        let value=primary();
        if(tokens[index]==="^") {index++;value=Math.pow(value,unary());}
        return value;
    }
    function primary() {
        if(++depth>24) throw new Error("depth");
        const token=tokens[index++];
        let value;
        if(token==="(") {
            value=expression();
            if(tokens[index++]!==")") throw new Error("parenthesis");
        } else if(String(token).toLowerCase()==="pi") value=Math.PI;
        else if(String(token).toLowerCase()==="e") value=Math.E;
        else if(token!==undefined && /^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(token)) value=Number(token);
        else throw new Error("number");
        depth--;
        return value;
    }
    try {
        const value=expression();
        if(index!==tokens.length || !Number.isFinite(value)) return null;
        return {kind:"calculation",id:"calculation",name:"= "+formatNumber(value),detail:"Enter to copy result",value:formatNumber(value),icon:"accessories-calculator",section:"Calculator"};
    } catch(error) {return null;}
}

var UNITS={
    mm:{group:"length",factor:.001,label:"mm"},cm:{group:"length",factor:.01,label:"cm"},m:{group:"length",factor:1,label:"m"},km:{group:"length",factor:1000,label:"km"},
    in:{group:"length",factor:.0254,label:"in"},inch:{group:"length",factor:.0254,label:"in"},inches:{group:"length",factor:.0254,label:"in"},ft:{group:"length",factor:.3048,label:"ft"},feet:{group:"length",factor:.3048,label:"ft"},yd:{group:"length",factor:.9144,label:"yd"},mi:{group:"length",factor:1609.344,label:"mi"},
    g:{group:"mass",factor:.001,label:"g"},kg:{group:"mass",factor:1,label:"kg"},oz:{group:"mass",factor:.028349523125,label:"oz"},lb:{group:"mass",factor:.45359237,label:"lb"},lbs:{group:"mass",factor:.45359237,label:"lb"},
    ml:{group:"volume",factor:.001,label:"mL"},l:{group:"volume",factor:1,label:"L"},gal:{group:"volume",factor:3.785411784,label:"US gal"},
    c:{group:"temperature",label:"°C"},f:{group:"temperature",label:"°F"},k:{group:"temperature",label:"K"}
};
var DEFAULT_UNIT={mm:"in",cm:"in",m:"ft",km:"mi",in:"cm",inch:"cm",inches:"cm",ft:"m",feet:"m",yd:"m",mi:"km",g:"oz",kg:"lb",oz:"g",lb:"kg",lbs:"kg",ml:"l",l:"gal",gal:"l",c:"f",f:"c",k:"c"};
function convert(query) {
    const text=typeof query === "string" ? query.trim().toLowerCase() : "";
    if(text.length>128) return null;
    const match=text.match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*°?([a-z]+)(?:\s+(?:to|in)\s+°?([a-z]+))?$/);
    if(!match) return null;
    const from=UNITS[match[2]],to=UNITS[match[3] || DEFAULT_UNIT[match[2]]],value=Number(match[1]);
    if(!from || !to || from.group!==to.group || !Number.isFinite(value)) return null;
    let result;
    if(from.group==="temperature") {
        const celsius=match[2]==="f" ? (value-32)*5/9 : match[2]==="k" ? value-273.15 : value;
        const target=match[3] || DEFAULT_UNIT[match[2]];
        result=target==="f" ? celsius*9/5+32 : target==="k" ? celsius+273.15 : celsius;
    } else result=value*from.factor/to.factor;
    if(!Number.isFinite(result)) return null;
    if(from.group==="temperature") result=Number(result.toFixed(1));
    return {kind:"calculation",id:"conversion",name:"= "+formatNumber(result)+" "+to.label,detail:formatNumber(value)+" "+from.label+" · Enter to copy",value:formatNumber(result)+" "+to.label,icon:"accessories-calculator",section:"Conversion"};
}

function webAddress(query) {
    const text=typeof query === "string" ? query.trim() : "";
    if(!text || text.length>2048 || /[\s\u0000-\u001f\u007f]/.test(text)) return "";
    const explicit=/^https?:\/\//i.test(text);
    const candidate=explicit ? text : "https://"+text;
    // Reject credentials, alternate schemes, invalid ports, and hostname punctuation.
    const match=candidate.match(/^https?:\/\/([^/?#]+)(?:[/?#].*)?$/i);
    if(!match || match[1].indexOf("@")!==-1) return "";
    const authority=match[1].match(/^([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::([0-9]{1,5}))?$/i);
    if(!authority || authority[1].length>253 || authority[1].split(".").some(function(label){return !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label);})) return "";
    if(/^(?:[0-9]+\.){3}[0-9]+$/.test(authority[1]) && authority[1].split(".").some(function(part){return Number(part)>255;})) return "";
    if(authority[2] && (Number(authority[2])<1 || Number(authority[2])>65535)) return "";
    if(!explicit && !/\.[a-z]{2,}$/i.test(authority[1])) return "";
    return candidate;
}
function webResult(query) {
    const text=typeof query === "string" ? query.trim() : "";
    if(!text || text.length>2048 || /[\u0000-\u001f\u007f]/.test(text)) return null;
    const address=webAddress(text);
    let escaped;
    try {escaped=encodeURIComponent(text);} catch(error) {return null;}
    return {kind:"web",id:"web",name:address ? "Open "+text : "Search Google for “"+text+"”",detail:"Enter to open in your default browser",url:address || "https://www.google.com/search?q="+escaped,icon:"web-browser",section:address ? "Website" : "Web search"};
}
function providerResult(query) {return convert(query) || calculate(query);}
var swiftshellSearch={calculate:calculate,convert:convert,webAddress:webAddress,webResult:webResult,providerResult:providerResult,formatNumber:formatNumber};
if(typeof module!=="undefined" && module.exports) module.exports=swiftshellSearch;
