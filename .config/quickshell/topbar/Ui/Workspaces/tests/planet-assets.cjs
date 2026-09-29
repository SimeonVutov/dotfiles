const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const zlib = require('node:zlib');

const directory = path.join(__dirname, '..');
const surface = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(directory, 'PlanetSurface.js'), 'utf8')
    .replace(/^\.pragma library\s*$/m, ''), surface);

function pixelsFromPng(file) {
    const data = fs.readFileSync(file);
    assert.equal(data.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    const compressed = [];
    let width = 0;
    let height = 0;
    for (let offset = 8; offset < data.length;) {
        const length = data.readUInt32BE(offset);
        const type = data.toString('ascii', offset + 4, offset + 8);
        const chunk = data.subarray(offset + 8, offset + 8 + length);
        if (type === 'IHDR') {
            width = chunk.readUInt32BE(0);
            height = chunk.readUInt32BE(4);
            assert.equal(chunk[9], 6);
        } else if (type === 'IDAT') {
            compressed.push(chunk);
        }
        offset += length + 12;
    }
    assert.equal(width, 64);
    assert.equal(height, 64);
    const scanlines = zlib.inflateSync(Buffer.concat(compressed));
    const pixels = Buffer.alloc(width * height * 4);
    for (let y = 0; y < height; ++y) {
        assert.equal(scanlines[y * (width * 4 + 1)], 0);
        scanlines.copy(pixels, y * width * 4, y * (width * 4 + 1) + 1,
            (y + 1) * (width * 4 + 1));
    }
    return pixels;
}

let checked = 0;
for (const [set, count, legacy] of [['expanded', 10, false], ['original', 12, true]]) {
    for (let id = 1; id <= count; ++id) {
        let expected;
        const context = {
            reset() {},
            createImageData(width, height) {
                return { data: new Uint8ClampedArray(width * height * 4) };
            },
            putImageData(image) { expected = Buffer.from(image.data); }
        };
        surface.paint(context, 64, id, legacy);
        const file = path.join(directory, 'Assets', set, `planet-${String(id).padStart(3, '0')}.png`);
        assert.deepEqual(pixelsFromPng(file), expected, `${set} planet ${id} differs from its source`);
        ++checked;
    }
}
console.log(`Verified ${checked} pre-rendered planet textures.`);
