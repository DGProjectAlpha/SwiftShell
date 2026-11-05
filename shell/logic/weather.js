function validLocation(value) {return value && typeof value.name==="string" && value.name.trim()!=="" && typeof value.latitude==="number" && isFinite(value.latitude) && value.latitude>=-90 && value.latitude<=90 && typeof value.longitude==="number" && isFinite(value.longitude) && value.longitude>=-180 && value.longitude<=180;}
function number(value){return typeof value==="number" && isFinite(value);}
function temperature(value,suffix){return number(value) ? Math.round(value)+ (suffix===undefined ? "°" : suffix) : "—";}
function amount(value,unit){return number(value) ? (Math.round(value*10)/10)+ (unit ? " "+unit : "") : "—";}
function percent(value){return number(value) ? Math.round(Math.max(0,Math.min(100,value)))+"%" : "—";}
function condition(code) {
    if(code===0)return "Clear skies";
    if(code===1)return "Mostly clear";
    if(code===2)return "Partly cloudy";
    if(code===3)return "Overcast";
    if(code===45 || code===48)return "Fog";
    if([51,53,55].indexOf(code)>=0)return "Drizzle";
    if([56,57,66,67].indexOf(code)>=0)return "Freezing rain";
    if([61,63,65,80,81,82].indexOf(code)>=0)return "Rain";
    if([71,73,75,77,85,86].indexOf(code)>=0)return "Snow";
    if([95,96,99].indexOf(code)>=0)return "Thunderstorms";
    return "Conditions unavailable";
}
function icon(code) {
    if(code===0 || code===1)return "clear";
    if(code===2)return "partly";
    if(code===3)return "cloud";
    if(code===45 || code===48)return "fog";
    if([71,73,75,77,85,86].indexOf(code)>=0)return "snow";
    if([95,96,99].indexOf(code)>=0)return "storm";
    if([51,53,55,56,57,61,63,65,66,67,80,81,82].indexOf(code)>=0)return "rain";
    return "unknown";
}
function aqi(value) {
    if(!number(value))return "Unavailable";
    if(value<=50)return "Good";
    if(value<=100)return "Moderate";
    if(value<=150)return "Unhealthy for sensitive groups";
    if(value<=200)return "Unhealthy";
    if(value<=300)return "Very unhealthy";
    return "Hazardous";
}
function windDirection(value) {return number(value) ? ["N","NE","E","SE","S","SW","W","NW"][Math.round(((value%360)+360)%360/45)%8] : "";}
function ageLabel(fetchedAt,now) {
    if(!number(fetchedAt) || fetchedAt<=0)return "Not updated";
    const minutes=Math.max(0,Math.floor((now-fetchedAt)/60000));
    if(minutes<1)return "Updated just now";
    if(minutes<60)return "Updated "+minutes+" min ago";
    if(minutes<1440)return "Updated "+Math.floor(minutes/60)+" hr ago";
    return "Updated "+Math.floor(minutes/1440)+" days ago";
}
function chartMaximum(hours,mode) {
    if(mode==="probability")return 100;
    const values=hours.map(function(hour){return hour.precipitation}).filter(number);
    return Math.max(.1,values.length ? Math.max.apply(null,values) : 0);
}
if(typeof module!=="undefined" && module && module.exports)module.exports={validLocation:validLocation,number:number,temperature:temperature,amount:amount,percent:percent,condition:condition,icon:icon,aqi:aqi,windDirection:windDirection,ageLabel:ageLabel,chartMaximum:chartMaximum};
