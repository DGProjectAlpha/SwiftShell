var inflateZlibRef = null;
var MAX_INPUT_BYTES = 32 * 1024 * 1024;
var MAX_INFLATED_BYTES = 16 * 1024 * 1024;

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
    if (input.length > MAX_INPUT_BYTES)
        return { ok: false, reason: "That png is too large to sample safely." };
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
    var idatLength = 0;
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
            idat.push(input.slice(offset, offset + length));
            idatLength += length;
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
    var expected = height * (width * bpp + 1);
    if (!Number.isSafeInteger(expected) || expected > MAX_INFLATED_BYTES)
        return { ok: false, reason: "That png is too large to sample safely." };
    try {
        if (typeof inflateZlibRef !== "function")
            return { ok: false, reason: "PNG inflate is not connected." };
        var compressed = new Uint8Array(idatLength);
        var compressedOffset = 0;
        for (var chunkIndex = 0; chunkIndex < idat.length; chunkIndex++) {
            compressed.set(idat[chunkIndex], compressedOffset);
            compressedOffset += idat[chunkIndex].length;
        }
        var inflated = inflateZlibRef(compressed, expected);
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

function pixel(decoded, x, y) {
    var offset = (y * decoded.width + x) * decoded.bpp;
    if (decoded.bpp === 1) {
        var gray = decoded.pixels[offset];
        return { r: gray, g: gray, b: gray };
    }
    var alpha = decoded.bpp === 4 ? decoded.pixels[offset + 3] / 255 : 1;
    return {
        r: Math.round(decoded.pixels[offset] * alpha),
        g: Math.round(decoded.pixels[offset + 1] * alpha),
        b: Math.round(decoded.pixels[offset + 2] * alpha),
    };
}

function visibleBand(decoded, rect, viewWidth, bandStart, bandEnd, barHeight) {
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;
    var columns = 24;
    var rows = 8;
    for (var row = 0; row < rows; row++) {
        var viewY = (row + 0.5) * barHeight / rows;
        for (var column = 0; column < columns; column++) {
            var viewX = bandStart + (column + 0.5) * (bandEnd - bandStart) / columns;
            var sample = { r: 0, g: 0, b: 0 };
            if (viewX >= rect.x && viewX < rect.x + rect.width
                    && viewY >= rect.y && viewY < rect.y + rect.height) {
                var sourceX = Math.max(0, Math.min(decoded.width - 1,
                    Math.floor((viewX - rect.x) * decoded.width / rect.width)));
                var sourceY = Math.max(0, Math.min(decoded.height - 1,
                    Math.floor((viewY - rect.y) * decoded.height / rect.height)));
                sample = pixel(decoded, sourceX, sourceY);
            }
            red += sample.r;
            green += sample.g;
            blue += sample.b;
            count += 1;
        }
    }
    return {
        r: Math.round(red / count),
        g: Math.round(green / count),
        b: Math.round(blue / count),
    };
}

function visibleBands(decoded, viewWidth, viewHeight, mode, barHeight, cropRectFn) {
    if (!decoded || !decoded.ok)
        return { ok: false, reason: decoded && decoded.reason ? decoded.reason : "That png could not be decoded." };
    var width = Number(viewWidth);
    var height = Number(viewHeight);
    var top = Math.max(1, Math.min(height, Number(barHeight) || 32));
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0
            || typeof cropRectFn !== "function")
        return { ok: false, reason: "The output geometry is unavailable." };
    var rect = cropRectFn(decoded.width, decoded.height, width, height, mode);
    var third = width / 3;
    return {
        ok: true,
        reason: "",
        width: decoded.width,
        height: decoded.height,
        left: visibleBand(decoded, rect, width, 0, third, top),
        center: visibleBand(decoded, rect, width, third, third * 2, top),
        right: visibleBand(decoded, rect, width, third * 2, width, top),
    };
}

var swiftshellPng = {
    MAX_INPUT_BYTES: MAX_INPUT_BYTES,
    MAX_INFLATED_BYTES: MAX_INFLATED_BYTES,
    bindInflate: bindInflate,
    decodePng: decodePng,
    topBands: topBands,
    visibleBands: visibleBands,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellPng;
