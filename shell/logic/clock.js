function formatTime(date, use24Hour, showSeconds) {
    if (date == null || typeof date.getHours !== "function" || typeof date.getMinutes !== "function")
        return "--:--";

    const hours = date.getHours();
    const minutes = date.getMinutes();
    if (!Number.isInteger(hours) || !Number.isInteger(minutes))
        return "--:--";
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59)
        return "--:--";

    const minuteText = String(minutes).padStart(2, "0");
    let seconds="";
    if(showSeconds) {
        const value=typeof date.getSeconds === "function" ? date.getSeconds() : NaN;
        if(!Number.isInteger(value) || value<0 || value>59) return "--:--";
        seconds=":"+String(value).padStart(2,"0");
    }
    if (use24Hour)
        return String(hours).padStart(2, "0") + ":" + minuteText+seconds;

    const suffix = hours >= 12 ? "PM" : "AM";
    const hour12 = hours % 12 || 12;
    return hour12 + ":" + minuteText+seconds + " " + suffix;
}

function datePattern(format) { return format==="iso" ? "yyyy-MM-dd" : (format==="weekday" ? "ddd, d MMM" : "d MMM"); }

var swiftshellClock = {
    datePattern:datePattern,
    formatTime: formatTime,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellClock;
