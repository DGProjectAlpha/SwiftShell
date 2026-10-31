var inflateZlibRef = null;

function bindInflate(fn) {
    inflateZlibRef = fn;
}

function toBytes(bytes) {
    if (bytes instanceof Uint8Array)
        return bytes;
    if (typeof ArrayBuffer !== "undefined" && bytes instanceof ArrayBuffer)
        return new Uint8Array(bytes);
    if (typeof Buffer !== "undefined" && Buffer.isBuffer && Buffer.isBuffer(bytes))
        return new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    return null;
}

function word(bytes, offset) {
    return ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
}

function paeth(left, up, upLeft) {
    var estimate = left + up - upLeft;
    var leftDistance = Math.abs(estimate - left);
    var upDistance = Math.abs(estimate - up);
    var diagonal = Math.abs(estimate - upLeft);
    if (leftDistance <= upDistance && leftDistance <= diagonal)
        return left;
    if (upDistance <= diagonal)
        return up;
    return upLeft;
}

function unfilter(data, width, height, bpp) {
    var stride = width * bpp;
    var expected = height * (stride + 1);
    if (data.length < expected)
        throw new Error("png short");
    var out = new Uint8Array(height * stride);
    var cursor = 0;
    for (var y = 0; y < height; y++) {
        var filter = data[cursor++];
        var row = y * stride;
        for (var x = 0; x < stride; x++) {
            var raw = data[cursor++];
            var left = x >= bpp ? out[row + x - bpp] : 0;
            var up = y > 0 ? out[row - stride + x] : 0;
            var upLeft = y > 0 && x >= bpp ? out[row - stride + x - bpp] : 0;
            var value = raw;
            if (filter === 1)
                value = raw + left;
            else if (filter === 2)
                value = raw + up;
            else if (filter === 3)
                value = raw + ((left + up) >> 1);
            else if (filter === 4)
                value = raw + paeth(left, up, upLeft);
            else if (filter !== 0)
                throw new Error("png filter");
            out[row + x] = value & 255;
        }
    }
    return out;
}

function decodePng(bytes) {
    var input = toBytes(bytes);
    if (!input || input.length < 8)
        return { ok: false, reason: "That file is not a png." };
    var signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var mark = 0; mark < signature.length; mark++) {
        if (input[mark] !== signature[mark])
            return { ok: false, reason: "That file is not a png." };
    }
    var width = 0;
    var height = 0;
    var bitDepth = 0;
    var colorType = 0;
    var interlace = 0;
    var idat = [];
    var offset = 8;
    while (offset + 8 <= input.length) {
        var length = word(input, offset);
        var type = String.fromCharCode(input[offset + 4], input[offset + 5], input[offset + 6], input[offset + 7]);
        offset += 8;
        if (length < 0 || offset + length + 4 > input.length)
            return { ok: false, reason: "That png is incomplete." };
        if (type === "IHDR") {
            if (length < 13)
                return { ok: false, reason: "That png is incomplete." };
            width = word(input, offset);
            height = word(input, offset + 4);
            bitDepth = input[offset + 8];
            colorType = input[offset + 9];
            interlace = input[offset + 12];
        } else if (type === "IDAT") {
            for (var index = 0; index < length; index++)
                idat.push(input[offset + index]);
        } else if (type === "IEND") {
            break;
        }
        offset += length + 4;
    }
    if (width < 1 || height < 1 || width > 16384 || height > 16384)
        return { ok: false, reason: "That png size is not used." };
    if (interlace !== 0)
        return { ok: false, reason: "Interlaced png files are not read." };
    if (bitDepth !== 8 || (colorType !== 2 && colorType !== 6 && colorType !== 0))
        return { ok: false, reason: "That png color format is not read." };
    var bpp = colorType === 2 ? 3 : colorType === 6 ? 4 : 1;
    try {
        if (typeof inflateZlibRef !== "function")
            return { ok: false, reason: "PNG inflate is not connected." };
        var inflated = inflateZlibRef(Uint8Array.from(idat));
        var pixels = unfilter(inflated, width, height, bpp);
        return { ok: true, reason: "", width: width, height: height, bpp: bpp, pixels: pixels };
    } catch (error) {
        return { ok: false, reason: "That png could not be decoded." };
    }
}

function average(pixels, bpp, width, x0, x1, y0, y1) {
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;
    for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
            var index = (y * width + x) * bpp;
            if (bpp === 1) {
                red += pixels[index];
                green += pixels[index];
                blue += pixels[index];
            } else {
                red += pixels[index];
                green += pixels[index + 1];
                blue += pixels[index + 2];
            }
            count += 1;
        }
    }
    if (count === 0)
        return { r: 0, g: 0, b: 0 };
    return {
        r: Math.round(red / count),
        g: Math.round(green / count),
        b: Math.round(blue / count),
    };
}

function topBands(decoded, rowCount) {
    if (!decoded || !decoded.ok)
        return { ok: false, reason: decoded && decoded.reason ? decoded.reason : "That png could not be decoded." };
    var rows = Math.max(1, Math.min(decoded.height, rowCount || 8));
    var third = Math.max(1, Math.floor(decoded.width / 3));
    return {
        ok: true,
        reason: "",
        width: decoded.width,
        height: decoded.height,
        left: average(decoded.pixels, decoded.bpp, decoded.width, 0, third, 0, rows),
        center: average(decoded.pixels, decoded.bpp, decoded.width, third, third * 2, 0, rows),
        right: average(decoded.pixels, decoded.bpp, decoded.width, third * 2, decoded.width, 0, rows),
    };
}

var swiftshellPng = {
    bindInflate: bindInflate,
    decodePng: decodePng,
    topBands: topBands,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPng;
