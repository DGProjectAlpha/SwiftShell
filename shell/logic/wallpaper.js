var IMAGE_EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp"];
var PACKAGED_NAME = "swiftshell-default-crimson.png";
var MAX_EDGE = 3840;

function extensionOf(path) {
    const value = String(path == null ? "" : path).trim();
    const query = value.split("?")[0];
    const dot = query.lastIndexOf(".");
    return dot === -1 ? "" : query.slice(dot).toLowerCase();
}

function fileUrl(path) {
    const text = String(path == null ? "" : path);
    if (text.indexOf("file:") === 0)
        return text;
    return "file://" + text.split("/").map(function (part) {
        return encodeURIComponent(part);
    }).join("/");
}

function pathFromFileUrl(url) {
    const text = String(url == null ? "" : url);
    if (text.indexOf("file://") !== 0)
        return "";
    const encoded = text.slice(7);
    if (encoded !== "" && encoded[0] !== "/")
        return "";
    try {
        return decodeURIComponent(encoded);
    } catch (error) {
        return "";
    }
}

function resolveSource(requested) {
    const value = String(requested == null ? "" : requested).trim();
    if (value === "" || value === "default")
        return { source: "packaged", path: "", reason: "" };
    if (value.indexOf("\0") !== -1 || value.indexOf("..") !== -1)
        return { source: "packaged", path: "", reason: "That path is not used." };
    if (IMAGE_EXTENSIONS.indexOf(extensionOf(value)) === -1)
        return { source: "packaged", path: "", reason: "Use a png, jpeg, or webp file." };
    return { source: "file", path: value, reason: "" };
}

function fitMode(mode) {
    return mode === "contain" ? "contain" : "cover";
}

function outputMap(text) {
    if (typeof text !== "string" || text.trim() === "")
        return {};
    try {
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return {};
        const out = {};
        const keys = Object.keys(parsed);
        for (let i = 0; i < keys.length; i++) {
            if (typeof parsed[keys[i]] === "string" && keys[i].indexOf("\0") === -1)
                out[keys[i]] = parsed[keys[i]];
        }
        return out;
    } catch (error) {
        return {};
    }
}

function sourceForOutput(name, path, outputsText) {
    const map = outputMap(outputsText);
    const named = typeof name === "string" && Object.prototype.hasOwnProperty.call(map, name);
    const specific = named ? map[name] : path;
    const resolved = resolveSource(specific);
    resolved.override = named;
    return resolved;
}

function sourceRequest(width, height) {
    const w = Number(width);
    const h = Number(height);
    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0)
        return { width: MAX_EDGE, height: 0 };
    const limited = decodeLimit(w, h);
    if (h > w)
        return { width: 0, height: limited.height };
    return { width: limited.width, height: 0 };
}

function samplePath(slideshowOn, shownPath, wallpaperPath) {
    if (slideshowOn === true && typeof shownPath === "string" && shownPath !== "")
        return shownPath;
    return typeof wallpaperPath === "string" ? wallpaperPath : "";
}

function cropRect(imageWidth, imageHeight, viewWidth, viewHeight, mode) {
    const iw = Number(imageWidth);
    const ih = Number(imageHeight);
    const vw = Number(viewWidth);
    const vh = Number(viewHeight);
    if (![iw, ih, vw, vh].every(function (n) { return Number.isFinite(n) && n > 0; }))
        return { x: 0, y: 0, width: 0, height: 0 };
    const fit = fitMode(mode);
    const scale = fit === "contain"
        ? Math.min(vw / iw, vh / ih)
        : Math.max(vw / iw, vh / ih);
    const width = iw * scale;
    const height = ih * scale;
    return {
        x: Math.round((vw - width) / 2),
        y: Math.round((vh - height) / 2),
        width: Math.round(width),
        height: Math.round(height),
    };
}

function decodeLimit(width, height) {
    const w = Number(width);
    const h = Number(height);
    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0)
        return { width: MAX_EDGE, height: MAX_EDGE };
    const edge = Math.max(w, h);
    if (edge <= MAX_EDGE)
        return { width: Math.round(w), height: Math.round(h) };
    const scale = MAX_EDGE / edge;
    return { width: Math.max(1, Math.round(w * scale)), height: Math.max(1, Math.round(h * scale)) };
}

var swiftshellWallpaper = {
    IMAGE_EXTENSIONS: IMAGE_EXTENSIONS,
    PACKAGED_NAME: PACKAGED_NAME,
    MAX_EDGE: MAX_EDGE,
    fileUrl: fileUrl,
    pathFromFileUrl: pathFromFileUrl,
    resolveSource: resolveSource,
    fitMode: fitMode,
    outputMap: outputMap,
    sourceForOutput: sourceForOutput,
    sourceRequest: sourceRequest,
    samplePath: samplePath,
    cropRect: cropRect,
    decodeLimit: decodeLimit,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellWallpaper;
