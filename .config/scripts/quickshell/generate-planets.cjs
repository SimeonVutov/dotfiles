#!/usr/bin/env node

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const zlib = require('node:zlib');

function options(args) {
    const result = { start: 1, count: 24, output: null, legacy: false };
    for (let i = 0; i < args.length; ++i) {
        const option = args[i];
        if (option === '--help') {
            process.stdout.write('Usage: node generate-planets.cjs [--start ID] [--count N] [--output DIR] [--legacy]\n');
            process.exit(0);
        }
        if (option === '--legacy') {
            result.legacy = true;
            if (!args.includes('--count'))
                result.count = 12;
            continue;
        }
        if (!['--start', '--count', '--output'].includes(option) || !args[i + 1])
            throw new Error(`Invalid option: ${option}`);
        result[option.slice(2)] = args[++i];
    }
    result.start = Number(result.start);
    result.count = Number(result.count);
    if (!Number.isSafeInteger(result.start) || result.start < 1
        || !Number.isSafeInteger(result.count) || result.count < 1 || result.count > 512)
        throw new Error('Start must be a positive integer and count must be between 1 and 512.');
    return result;
}

function crc32(buffer) {
    let crc = -1;
    for (const byte of buffer) {
        crc ^= byte;
        for (let bit = 0; bit < 8; ++bit)
            crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
    return (crc ^ -1) >>> 0;
}

function chunk(type, data) {
    const name = Buffer.from(type);
    const result = Buffer.alloc(12 + data.length);
    result.writeUInt32BE(data.length, 0);
    name.copy(result, 4);
    data.copy(result, 8);
    result.writeUInt32BE(crc32(result.subarray(4, 8 + data.length)), 8 + data.length);
    return result;
}

function png(width, height, pixels) {
    const header = Buffer.alloc(13);
    header.writeUInt32BE(width, 0);
    header.writeUInt32BE(height, 4);
    header[8] = 8;
    header[9] = 6;
    const raw = Buffer.alloc(height * (1 + width * 4));
    for (let y = 0; y < height; ++y)
        Buffer.from(pixels.buffer, pixels.byteOffset + y * width * 4, width * 4)
            .copy(raw, y * (1 + width * 4) + 1);
    return Buffer.concat([
        Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
        chunk('IHDR', header),
        chunk('IDAT', zlib.deflateSync(raw)),
        chunk('IEND', Buffer.alloc(0))
    ]);
}

function main() {
    const config = options(process.argv.slice(2));
    const source = path.resolve(__dirname, '../../quickshell/topbar/Ui/Workspaces/PlanetSurface.js');
    const surface = vm.createContext({});
    vm.runInContext(fs.readFileSync(source, 'utf8').replace(/^\.pragma library\s*$/m, ''), surface);
    const destination = config.output ? path.resolve(config.output)
        : fs.mkdtempSync(path.join(os.tmpdir(), 'quickshell-planets-'));
    fs.mkdirSync(destination, { recursive: true });
    if (fs.readdirSync(destination).length)
        throw new Error(`Output directory is not empty: ${destination}`);

    const cards = [];
    for (let id = config.start; id < config.start + config.count; ++id) {
        const appearance = surface.appearance(id, config.legacy);
        let image = null;
        const ctx = {
            reset() {},
            createImageData(width, height) {
                return { data: new Uint8ClampedArray(width * height * 4) };
            },
            putImageData(value) { image = value.data; }
        };
        surface.paint(ctx, 64, id, config.legacy);
        if (!image)
            throw new Error(`No image generated for workspace ${id}`);
        const filename = `planet-${String(id).padStart(3, '0')}.png`;
        fs.writeFileSync(path.join(destination, filename), png(64, 64, image), { flag: 'wx' });
        cards.push(`<article><div class="bar"><div class="planet" style="--diameter:${appearance.diameter}px"><img src="${filename}" alt=""></div></div><img class="detail" src="${filename}" alt=""><span>${id} · ${appearance.name}${appearance.ring === undefined ? '' : ' · ringed'}</span></article>`);
    }
    const html = `<!doctype html><html lang="en"><meta charset="utf-8"><title>Quickshell planets</title><style>
        body{margin:24px;background:#26384c;color:#eee;font:14px sans-serif}h1{font-size:20px;font-weight:500}
        main{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:14px}
        article{padding:12px;background:#101318;border-radius:16px;display:grid;justify-items:center;gap:6px}
        .bar{height:32px;width:88px;background:#05090e;border-radius:18px;display:grid;place-items:center}
        .planet{width:var(--diameter);height:var(--diameter)}.planet img{width:100%;height:100%}
        .detail{width:64px;height:64px;image-rendering:auto}span{text-align:center;font-size:12px}
    </style><h1>Quickshell ${config.legacy ? 'original' : 'current'} workspace planets</h1><main>${cards.join('')}</main></html>`;
    fs.writeFileSync(path.join(destination, 'index.html'), html, { flag: 'wx' });
    process.stdout.write(`${config.count} planets generated in ${destination}\nOpen ${path.join(destination, 'index.html')} to compare them.\n`);
}

try {
    main();
} catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
}
