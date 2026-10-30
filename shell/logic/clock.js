function formatTime(date, use24Hour) {
    if (date == null || typeof date.getHours !== "function" || typeof date.getMinutes !== "function")
        return "--:--";

    const hours = date.getHours();
    const minutes = date.getMinutes();
    if (!Number.isInteger(hours) || !Number.isInteger(minutes))
        return "--:--";
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59)
        return "--:--";

    const minuteText = String(minutes).padStart(2, "0");
    if (use24Hour)
        return String(hours).padStart(2, "0") + ":" + minuteText;

    const suffix = hours >= 12 ? "PM" : "AM";
    const hour12 = hours % 12 || 12;
    return hour12 + ":" + minuteText + " " + suffix;
}

var swiftshellClock = {
    formatTime: formatTime,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellClock;
