// Clock tools keep deadlines rather than decrementing tick counters, so sleeping
// or a shell restart cannot silently extend a countdown.
var MAX_DURATION = 7 * 24 * 60 * 60 * 1000;
var MAX_ELAPSED = 366 * 24 * 60 * 60 * 1000;
function finite(value, fallback, maximum) {
    return typeof value === "number" && Number.isFinite(value) && value >= 0
        ? Math.min(value, maximum) : fallback;
}
function emptyState() {
    return { version: 1, style: "digital", tab: "clock",
        timer: { status: "ready", duration: 300000, remaining: 300000, deadline: 0 },
        stopwatch: { status: "ready", elapsed: 0, startedAt: 0, laps: [] } };
}
function normalize(raw) {
    const result = emptyState();
    const source = raw && typeof raw === "object" ? raw : {};
    result.style = source.style === "analogue" ? "analogue" : "digital";
    if (["clock", "calendar", "timer", "stopwatch"].indexOf(source.tab) >= 0) result.tab = source.tab;
    const timer = source.timer || {};
    result.timer.duration = Math.max(1000, finite(timer.duration, 300000, MAX_DURATION));
    result.timer.remaining = finite(timer.remaining, result.timer.duration, MAX_DURATION);
    result.timer.deadline = finite(timer.deadline, 0, Number.MAX_SAFE_INTEGER);
    if (["ready", "running", "paused", "finished"].indexOf(timer.status) >= 0) result.timer.status = timer.status;
    if (result.timer.status === "running" && result.timer.deadline === 0) result.timer.status = "paused";
    const stopwatch = source.stopwatch || {};
    result.stopwatch.elapsed = finite(stopwatch.elapsed, 0, MAX_ELAPSED);
    result.stopwatch.startedAt = finite(stopwatch.startedAt, 0, Number.MAX_SAFE_INTEGER);
    result.stopwatch.status = stopwatch.status === "running" && result.stopwatch.startedAt > 0
        ? "running" : (result.stopwatch.elapsed > 0 ? "paused" : "ready");
    const laps = Array.isArray(stopwatch.laps) ? stopwatch.laps : [];
    let last = 0;
    for (let index = 0; index < Math.min(50, laps.length); index++) {
        const lap = laps[index];
        if (typeof lap === "number" && Number.isFinite(lap) && lap >= last && lap <= MAX_ELAPSED) {
            result.stopwatch.laps.push(lap);
            last = lap;
        }
    }
    return result;
}
function readState(raw) {
    try {
        const value = JSON.parse(raw);
        if (!value || typeof value !== "object" || Array.isArray(value) || value.version !== 1)
            return { ok: false, state: emptyState() };
        return { ok: true, state: normalize(value) };
    } catch (error) { return { ok: false, state: emptyState() }; }
}
function timerRemaining(timer, now) {
    return timer.status === "running" ? Math.max(0, timer.deadline - now) : timer.remaining;
}
function stopwatchElapsed(stopwatch, now) {
    return Math.min(MAX_ELAPSED, stopwatch.elapsed + (stopwatch.status === "running" ? Math.max(0, now - stopwatch.startedAt) : 0));
}
function timerAction(current, action, now, duration) {
    const timer = Object.assign({}, current);
    if (action === "start" && typeof duration === "number" && Number.isFinite(duration) && duration >= 1000 && duration <= MAX_DURATION) {
        timer.duration = Math.round(duration);
        timer.remaining = timer.duration;
        timer.deadline = now + timer.duration;
        timer.status = "running";
    } else if (action === "pause" && timer.status === "running") {
        timer.remaining = timerRemaining(timer, now);
        timer.deadline = 0;
        timer.status = timer.remaining > 0 ? "paused" : "finished";
    } else if (action === "resume" && timer.status === "paused" && timer.remaining > 0) {
        timer.deadline = now + timer.remaining;
        timer.status = "running";
    } else if (action === "finish" && timer.status === "running" && timerRemaining(timer, now) === 0) {
        timer.remaining = 0;
        timer.status = "finished";
    } else if (action === "reset") {
        timer.remaining = timer.duration;
        timer.deadline = 0;
        timer.status = "ready";
    }
    return timer;
}
function stopwatchAction(current, action, now) {
    const stopwatch = Object.assign({}, current, { laps: current.laps.slice() });
    if (action === "start" && stopwatch.status !== "running") {
        stopwatch.startedAt = now;
        stopwatch.status = "running";
    } else if (action === "pause" && stopwatch.status === "running") {
        stopwatch.elapsed = stopwatchElapsed(stopwatch, now);
        stopwatch.startedAt = 0;
        stopwatch.status = "paused";
    } else if (action === "lap" && stopwatch.status === "running" && stopwatch.laps.length < 50) {
        stopwatch.laps.push(stopwatchElapsed(stopwatch, now));
    } else if (action === "reset") {
        stopwatch.elapsed = 0;
        stopwatch.startedAt = 0;
        stopwatch.laps = [];
        stopwatch.status = "ready";
    }
    return stopwatch;
}
function durationText(milliseconds, hundredths) {
    const value = Math.max(0, finite(milliseconds, 0, MAX_ELAPSED));
    const totalSeconds = hundredths ? Math.floor(value / 1000) : Math.ceil(value / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor(totalSeconds / 60) % 60;
    const seconds = totalSeconds % 60;
    return (hours > 0 ? String(hours).padStart(2, "0") + ":" : "")
        + String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
        + (hundredths ? "." + String(Math.floor(value / 10) % 100).padStart(2, "0") : "");
}
var clockTools = { emptyState: emptyState, normalize: normalize, readState: readState,
    timerRemaining: timerRemaining, stopwatchElapsed: stopwatchElapsed,
    timerAction: timerAction, stopwatchAction: stopwatchAction, durationText: durationText };
if (typeof module !== "undefined" && module.exports) module.exports = clockTools;
