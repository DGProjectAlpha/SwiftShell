var LENGTH_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
var LENGTH_EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
var DIST_BASE = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577];
var DIST_EXTRA = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
var CLEN_ORDER = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

function toBytes(bytes) {
    if (bytes instanceof Uint8Array)
        return bytes;
    if (typeof ArrayBuffer !== "undefined" && bytes instanceof ArrayBuffer)
        return new Uint8Array(bytes);
    if (typeof Buffer !== "undefined" && Buffer.isBuffer && Buffer.isBuffer(bytes))
        return new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    throw new Error("bytes");
}

function Reader(data, offset) {
    this.data = data;
    this.p = offset || 0;
    this.bit = 0;
    this.buf = 0;
}

Reader.prototype.bits = function (count) {
    var need = count;
    while (this.bit < need) {
        if (this.p >= this.data.length)
            throw new Error("truncated");
        this.buf |= this.data[this.p++] << this.bit;
        this.bit += 8;
    }
    var value = this.buf & ((1 << need) - 1);
    this.buf >>>= need;
    this.bit -= need;
    return value;
};

Reader.prototype.align = function () {
    this.bit = 0;
    this.buf = 0;
};

function buildMap(lengths) {
    var count = [];
    var max = 0;
    var index;
    for (index = 0; index < 16; index++)
        count[index] = 0;
    for (index = 0; index < lengths.length; index++) {
        var length = lengths[index] || 0;
        if (length > 15)
            throw new Error("code length");
        if (length) {
            count[length] += 1;
            if (length > max)
                max = length;
        }
    }
    var next = [];
    var code = 0;
    for (var bits = 1; bits <= 15; bits++) {
        code = (code + count[bits - 1]) << 1;
        next[bits] = code;
    }
    var map = {};
    for (var symbol = 0; symbol < lengths.length; symbol++) {
        var used = lengths[symbol] || 0;
        if (!used)
            continue;
        map[used + ":" + next[used]] = symbol;
        next[used] += 1;
    }
    return { map: map, max: max };
}

function readSymbol(reader, tree) {
    if (!tree || tree.max === 0)
        throw new Error("empty huffman");
    var code = 0;
    for (var length = 1; length <= tree.max; length++) {
        code = (code << 1) | reader.bits(1);
        var found = tree.map[length + ":" + code];
        if (found !== undefined)
            return found;
    }
    throw new Error("bad huffman");
}

var FIXED_LIT = null;
var FIXED_DIST = null;

function fixedLit() {
    if (FIXED_LIT)
        return FIXED_LIT;
    var lengths = [];
    var index;
    for (index = 0; index <= 143; index++)
        lengths.push(8);
    for (index = 144; index <= 255; index++)
        lengths.push(9);
    for (index = 256; index <= 279; index++)
        lengths.push(7);
    for (index = 280; index <= 287; index++)
        lengths.push(8);
    FIXED_LIT = buildMap(lengths);
    return FIXED_LIT;
}

function fixedDist() {
    if (FIXED_DIST)
        return FIXED_DIST;
    var lengths = [];
    for (var index = 0; index < 32; index++)
        lengths.push(5);
    FIXED_DIST = buildMap(lengths);
    return FIXED_DIST;
}

function copyBytes(out, distance, length) {
    if (distance <= 0 || distance > out.length)
        throw new Error("distance");
    var start = out.length - distance;
    for (var index = 0; index < length; index++)
        out.push(out[start + index]);
}

function inflateBlock(reader, lit, dist, out) {
    for (;;) {
        var symbol = readSymbol(reader, lit);
        if (symbol < 256) {
            out.push(symbol);
            continue;
        }
        if (symbol === 256)
            return;
        var lengthIndex = symbol - 257;
        if (lengthIndex < 0 || lengthIndex >= LENGTH_BASE.length)
            throw new Error("length");
        var extra = LENGTH_EXTRA[lengthIndex];
        var length = LENGTH_BASE[lengthIndex] + (extra ? reader.bits(extra) : 0);
        var distSymbol = readSymbol(reader, dist);
        if (distSymbol < 0 || distSymbol >= DIST_BASE.length)
            throw new Error("distance symbol");
        var distExtra = DIST_EXTRA[distSymbol];
        var distance = DIST_BASE[distSymbol] + (distExtra ? reader.bits(distExtra) : 0);
        copyBytes(out, distance, length);
    }
}

function dynamicTrees(reader) {
    var literalCount = reader.bits(5) + 257;
    var distanceCount = reader.bits(5) + 1;
    var codeCount = reader.bits(4) + 4;
    var codeLengths = [];
    var index;
    for (index = 0; index < 19; index++)
        codeLengths.push(0);
    for (index = 0; index < codeCount; index++)
        codeLengths[CLEN_ORDER[index]] = reader.bits(3);
    var codeTree = buildMap(codeLengths);
    var lengths = [];
    while (lengths.length < literalCount + distanceCount) {
        var symbol = readSymbol(reader, codeTree);
        if (symbol < 16) {
            lengths.push(symbol);
        } else if (symbol === 16) {
            if (lengths.length === 0)
                throw new Error("repeat");
            var previous = lengths[lengths.length - 1];
            var repeat = reader.bits(2) + 3;
            for (var copy = 0; copy < repeat; copy++)
                lengths.push(previous);
        } else if (symbol === 17) {
            var zeros = reader.bits(3) + 3;
            for (var zero = 0; zero < zeros; zero++)
                lengths.push(0);
        } else if (symbol === 18) {
            var many = reader.bits(7) + 11;
            for (var fill = 0; fill < many; fill++)
                lengths.push(0);
        } else {
            throw new Error("code length");
        }
    }
    if (lengths.length !== literalCount + distanceCount)
        throw new Error("code length count");
    return {
        lit: buildMap(lengths.slice(0, literalCount)),
        dist: buildMap(lengths.slice(literalCount)),
    };
}

function inflateRaw(data, offset) {
    var reader = new Reader(data, offset || 0);
    var out = [];
    var finalBlock = 0;
    while (!finalBlock) {
        finalBlock = reader.bits(1);
        var type = reader.bits(2);
        if (type === 0) {
            reader.align();
            if (reader.p + 4 > reader.data.length)
                throw new Error("stored");
            var length = reader.data[reader.p] | (reader.data[reader.p + 1] << 8);
            var complement = reader.data[reader.p + 2] | (reader.data[reader.p + 3] << 8);
            reader.p += 4;
            if ((length ^ 0xffff) !== complement)
                throw new Error("stored length");
            if (reader.p + length > reader.data.length)
                throw new Error("stored data");
            for (var index = 0; index < length; index++)
                out.push(reader.data[reader.p++]);
        } else if (type === 1) {
            inflateBlock(reader, fixedLit(), fixedDist(), out);
        } else if (type === 2) {
            var trees = dynamicTrees(reader);
            inflateBlock(reader, trees.lit, trees.dist, out);
        } else {
            throw new Error("block type");
        }
    }
    return { bytes: Uint8Array.from(out), offset: reader.p };
}

function adler32(bytes) {
    var a = 1;
    var b = 0;
    for (var index = 0; index < bytes.length; index++) {
        a = (a + bytes[index]) % 65521;
        b = (b + a) % 65521;
    }
    return ((b << 16) | a) >>> 0;
}

function inflateZlib(bytes) {
    var input = toBytes(bytes);
    if (input.length < 6)
        throw new Error("short zlib");
    var cmf = input[0];
    var flg = input[1];
    if ((cmf & 15) !== 8 || (cmf >> 4) > 7)
        throw new Error("zlib method");
    if (((cmf << 8) + flg) % 31 !== 0)
        throw new Error("zlib header");
    if (flg & 32)
        throw new Error("zlib dictionary");
    var raw = inflateRaw(input, 2);
    if (raw.offset + 4 > input.length)
        throw new Error("zlib trailer");
    var checksum = ((input[raw.offset] << 24) | (input[raw.offset + 1] << 16) | (input[raw.offset + 2] << 8) | input[raw.offset + 3]) >>> 0;
    if (checksum !== adler32(raw.bytes))
        throw new Error("adler");
    return raw.bytes;
}

var swiftshellInflate = {
    inflateZlib: inflateZlib,
    inflateRaw: inflateRaw,
    adler32: adler32,
};

if (typeof module !== "undefined" && module.exports)
    module.exports = swiftshellInflate;
