function isoWeekNumber(year, month, day) {
    const date = new Date(Date.UTC(year, month, day));
    const dayNum = date.getUTCDay() || 7;
    date.setUTCDate(date.getUTCDate() + 4 - dayNum);
    const isoYear = date.getUTCFullYear();
    const yearStart = new Date(Date.UTC(isoYear, 0, 1));
    return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
}

function cell(date, inMonth, todayYear, todayMonth, todayDay) {
    const year = date.getFullYear();
    const month = date.getMonth();
    const day = date.getDate();
    return {
        year: year,
        month: month,
        day: day,
        inMonth: inMonth === true,
        isToday: year === todayYear && month === todayMonth && day === todayDay,
    };
}

function weekStartIndex(preference, localeFirstDay, sundayValue) {
    if (preference === "sunday")
        return 0;
    if (preference === "monday")
        return 1;

    const day = Number(localeFirstDay);
    const sunday = sundayValue === undefined ? 7 : sundayValue;
    if (day === sunday || day === 0)
        return 0;
    if (day >= 1 && day <= 6)
        return day;
    return 1;
}

function shiftMonth(year, month, delta) {
    const date = new Date(year, month + delta, 1);
    return { year: date.getFullYear(), month: date.getMonth() };
}

function buildMonth(year, month, weekStart, todayYear, todayMonth, todayDay) {
    const start = ((weekStart % 7) + 7) % 7;
    const firstWeekday = new Date(year, month, 1).getDay();
    const offset = (firstWeekday - start + 7) % 7;
    const days = new Date(year, month + 1, 0).getDate();
    const cells = [];

    for (let index = 0; index < offset; index++)
        cells.push(cell(new Date(year, month, 1 - (offset - index)), false, todayYear, todayMonth, todayDay));

    for (let day = 1; day <= days; day++)
        cells.push(cell(new Date(year, month, day), true, todayYear, todayMonth, todayDay));

    while (cells.length % 7 !== 0) {
        const previous = cells[cells.length - 1];
        cells.push(cell(new Date(previous.year, previous.month, previous.day + 1), false, todayYear, todayMonth, todayDay));
    }

    const weeks = [];
    for (let index = 0; index < cells.length; index += 7) {
        const daysOfWeek = cells.slice(index, index + 7);
        const thursday = daysOfWeek[(4 - start + 7) % 7];
        weeks.push({
            weekNumber: isoWeekNumber(thursday.year, thursday.month, thursday.day),
            days: daysOfWeek,
        });
    }

    return { year: year, month: month, weeks: weeks };
}

var swiftshellCalendar = {
    isoWeekNumber: isoWeekNumber,
    weekStartIndex: weekStartIndex,
    shiftMonth: shiftMonth,
    buildMonth: buildMonth,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellCalendar;
