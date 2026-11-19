.pragma library

var styles = [
    { name: "Moon", diameter: 22 },
    { name: "Saturn", diameter: 19, ring: -0.35 },
    { name: "Cracked ice", diameter: 21 },
    { name: "Aurora storm", diameter: 21 },
    { name: "Jupiter", diameter: 23 },
    { name: "Earthlike", diameter: 22 },
    { name: "Archipelago", diameter: 23 },
    { name: "Lava rivers", diameter: 21 },
    { name: "Cyclone eye", diameter: 24 },
    { name: "Asteroid", diameter: 18 }
];

var legacyStyles = [
    { name: "Moon", diameter: 22 },
    { name: "Saturn", diameter: 19, ring: -0.35 },
    { name: "Cracked ice", diameter: 21 },
    { name: "Volcanic", diameter: 20 },
    { name: "Jupiter", diameter: 23 },
    { name: "Crescent", diameter: 19 },
    { name: "Dark moon", diameter: 25 },
    { name: "Polar world", diameter: 20 },
    { name: "Striated", diameter: 22 },
    { name: "Marble", diameter: 22 },
    { name: "Asteroid", diameter: 17 },
    { name: "Tilted rings", diameter: 20, ring: 0.3 }
];

// The planet textures are painted offline into Assets/original (see
// tests/planet-assets.cjs); at runtime only `appearance` is used. Coordinates
// below are on the planet's disc, from -1 to 1 (nx, ny), and on its sphere as
// longitude and latitude in radians.

// Each style's brightness (0..1) at one point of the disc. `variant` is the
// repeat of the style when there are more workspaces than styles.
function moon(nx, ny, longitude, latitude, seed) {
    const base = 0.8 - 0.27 * Math.exp(-Math.pow((nx + 0.25) / 0.36, 2)
        - Math.pow((ny + 0.12) / 0.42, 2));
    return base + 0.07 * Math.sin(nx * 18 + seed) * Math.cos(ny * 17);
}

function saturn(nx, ny, longitude, latitude, seed, variant) {
    return 0.61 + 0.24 * Math.sin(latitude * 14 + 0.5 * Math.sin(longitude * 3 + variant * 1.7) + variant * 0.4)
        + 0.08 * Math.sin(latitude * 35);
}

function crackedIce(nx, ny, longitude, latitude, seed) {
    const fissure = Math.abs(Math.sin(longitude * 6 + Math.sin(latitude * 5 + seed)));
    return 0.95 - 0.53 * Math.exp(-fissure * fissure * 65);
}

function auroraStorm(nx, ny, longitude, latitude, seed) {
    const storm = Math.sin(longitude * 2.4 + latitude * 3.2 + seed * 0.2)
        + 0.35 * Math.sin(longitude * 5 - latitude * 4);
    const base = 0.32 + 0.55 * Math.exp(-storm * storm * 3.2);
    return base + 0.09 * Math.sin(latitude * 18 + longitude * 2);
}

function jupiter(nx, ny, longitude, latitude, seed, variant) {
    const bands = 0.51 + 0.35 * Math.sin(latitude * 8 + 0.9 * Math.sin(longitude * 2 + variant));
    return bands + 0.12 * Math.exp(-Math.pow((nx - 0.25 + variant * 0.09) / 0.23, 2)
        - Math.pow((ny + 0.17) / 0.16, 2));
}

function earthlike(nx, ny, longitude, latitude, seed) {
    const continent = Math.sin(longitude * 3.1 + 0.7 * Math.sin(latitude * 5 + seed))
        + 0.45 * Math.cos(latitude * 7 - longitude * 1.7);
    const clouds = 0.08 * Math.sin(longitude * 10 + latitude * 13);
    const base = continent > 0.2 ? 0.86 : 0.36;
    return base + clouds;
}

function archipelago(nx, ny, longitude, latitude, seed) {
    const coast = Math.sin(longitude * 4 + 0.6 * Math.sin(latitude * 7 + seed))
        + 0.6 * Math.cos(latitude * 5 - longitude * 2);
    return coast > 0.1 ? 0.87 : 0.34;
}

function lavaRivers(nx, ny, longitude, latitude, seed) {
    const river = Math.abs(Math.sin(longitude * 4 + latitude * 3
        + 0.8 * Math.sin(latitude * 5 + seed)));
    return 0.24 + 0.73 * Math.exp(-river * river * 48);
}

function cycloneEye(nx, ny, longitude, latitude, seed) {
    const u = nx - 0.16;
    const v = ny + 0.1;
    const radius = Math.hypot(u, v);
    const spiral = Math.sin(Math.atan2(v, u) * 2 + radius * 20 + seed * 0.18);
    return 0.53 + 0.23 * spiral
        + 0.25 * Math.exp(-Math.pow((radius - 0.32) / 0.12, 2))
        - 0.52 * Math.exp(-Math.pow(radius / 0.13, 2));
}

function asteroid(nx, ny, longitude, latitude, seed) {
    return 0.54 + 0.18 * Math.sin(longitude * 5 + latitude * 7 + seed);
}

// Styles of the previous planet set, which `legacy` selects.
function volcanic(nx, ny, longitude, latitude, seed) {
    const ridge = Math.sin(longitude * 4 + latitude * 8 + seed);
    return 0.28 + 0.52 * Math.exp(-ridge * ridge * 75);
}

function crescent(nx, ny, longitude, latitude) {
    return 0.81 - 0.12 * Math.sin(longitude * 7 + latitude * 3);
}

function darkMoon(nx, ny, longitude, latitude, seed) {
    const base = 0.61 + 0.11 * Math.sin(nx * 17 + seed) * Math.cos(ny * 15);
    return base - 0.27 * Math.exp(-Math.pow((nx - 0.05) / 0.48, 2)
        - Math.pow((ny + 0.2) / 0.3, 2));
}

function polarWorld(nx, ny, longitude, latitude, seed) {
    return 0.3 + 0.62 / (1 + Math.exp((ny + 0.22
        + 0.1 * Math.sin(longitude * 4 + seed)) * 16));
}

function striated(nx, ny, longitude, latitude) {
    return 0.59 + 0.3 * Math.sin(longitude * 9 + latitude * 10
        + 0.6 * Math.sin(latitude * 4));
}

function marble(nx, ny, longitude, latitude, seed) {
    return 0.72 + 0.27 * Math.sin(longitude * 4
        + 1.3 * Math.sin(latitude * 7 + seed * 0.3));
}

function tiltedRings(nx, ny, longitude, latitude, seed) {
    const base = 0.8 + 0.16 * Math.sin(latitude * 6
        + 1.5 * Math.sin(longitude * 4 + seed * 0.2));
    return base - 0.36 * Math.exp(-Math.pow((nx + 0.34) / 0.24, 2)
        - Math.pow((ny - 0.13) / 0.2, 2));
}

// Brightness functions and crater counts in the order of `styles` and
// `legacyStyles`.
var albedos = [moon, saturn, crackedIce, auroraStorm, jupiter, earthlike, archipelago, lavaRivers, cycloneEye, asteroid];
var legacyAlbedos = [moon, saturn, crackedIce, volcanic, jupiter, crescent, darkMoon, polarWorld, striated, marble, asteroid, tiltedRings];
var craterCounts = [14, 0, 0, 0, 0, 0, 0, 0, 0, 5];
var legacyCraterCounts = [14, 0, 0, 5, 0, 3, 9, 0, 0, 0, 5, 0];

// Index of the legacy styles that are special-cased below.
var LEGACY_CRESCENT = 5;
var LEGACY_ASTEROID = 10;

// Light from the upper left, with a little ambient light so the night side
// is not black; the legacy crescent is lit from the right.
var standardLight = { x: -0.62, y: -0.46, z: 0.63, ambient: 0.03 };
var crescentLight = { x: 0.92, y: -0.15, z: -0.18, ambient: 0.015 };

function kindFor(seed, legacy) {
    const count = legacy ? legacyStyles.length : styles.length;
    return ((seed - 1) % count + count) % count;
}

function appearance(seed, legacy) {
    const kind = kindFor(seed, legacy);
    return legacy ? legacyStyles[kind] : styles[kind];
}

// The same seed always gives the same sequence, so a planet always looks the same.
function seededRandom(seed) {
    let state = (seed * 7919 + 17) >>> 0;
    return function () {
        state = (state * 1664525 + 1013904223) >>> 0;
        return state / 4294967296;
    };
}

function createCraters(random, count) {
    const craters = [];
    for (let i = 0; i < count; ++i)
        craters.push([random() * 1.7 - 0.85, random() * 1.7 - 0.85, 0.08 + random() * 0.22]);
    return craters;
}

// Craters change both the brightness and the surface direction the light
// meets. `shade` holds the pixel's brightness (albedo) and direction (dx, dy).
function applyCraters(craters, nx, ny, shade) {
    for (let i = 0; i < craters.length; ++i) {
        const crater = craters[i];
        const u = (nx - crater[0]) / crater[2];
        const v = (ny - crater[1]) / crater[2];
        const radius = Math.sqrt(u * u + v * v);
        if (radius < 1.25) {
            const rim = Math.exp(-Math.pow((radius - 0.84) * 8, 2));
            const bowl = Math.max(0, 1 - radius * radius);
            shade.albedo += rim * 0.13 - bowl * 0.17;
            shade.dx += u * bowl * 0.23;
            shade.dy += v * bowl * 0.23;
        }
    }
}

// The grey level of a pixel, from its brightness and surface direction.
function lit(shade, nz, light) {
    const brightness = Math.max(0, (light.x * shade.dx + light.y * shade.dy + light.z * nz)
        / Math.hypot(shade.dx, shade.dy, nz));
    return Math.round(255 * Math.pow(Math.max(0,
        Math.min(1, shade.albedo * (light.ambient + brightness * (1 - light.ambient)))), 0.72));
}

function paint(ctx, size, seed, legacy) {
    ctx.reset();
    const image = ctx.createImageData(size, size);
    const pixels = image.data;
    const kind = kindFor(seed, legacy);
    const variant = legacy ? 0 : Math.floor((seed - 1) / styles.length);
    const albedoAt = (legacy ? legacyAlbedos : albedos)[kind];
    const light = legacy && kind === LEGACY_CRESCENT ? crescentLight : standardLight;
    const craters = createCraters(seededRandom(seed), (legacy ? legacyCraterCounts : craterCounts)[kind]);
    const shade = { albedo: 0, dx: 0, dy: 0 };

    for (let y = 0; y < size; ++y) {
        for (let x = 0; x < size; ++x) {
            const nx = (x + 0.5) * 2 / size - 1;
            const ny = (y + 0.5) * 2 / size - 1;

            // The legacy asteroid has a lumpy outline instead of a circle.
            const azimuth = Math.atan2(ny, nx);
            const outline = legacy && kind === LEGACY_ASTEROID
                ? 0.92 + 0.04 * Math.sin(5 * azimuth + seed)
                    + 0.035 * Math.sin(7 * azimuth - seed * 0.4) : 1;
            const r2 = (nx * nx + ny * ny) / (outline * outline);
            if (r2 >= 1)
                continue;

            const nz = Math.sqrt(1 - r2);
            const longitude = Math.atan2(nx, nz);
            const latitude = Math.asin(ny / outline);

            shade.albedo = albedoAt(nx, ny, longitude, latitude, seed, variant);
            if (variant > 0)
                shade.albedo += 0.08 * Math.sin(longitude * (3 + variant % 4)
                    + latitude * (2 + variant % 3) + variant * 2.3);
            shade.dx = nx;
            shade.dy = ny;
            applyCraters(craters, nx, ny, shade);

            const value = lit(shade, nz, light);
            const offset = (y * size + x) * 4;
            pixels[offset] = value;
            pixels[offset + 1] = value;
            pixels[offset + 2] = value;
            pixels[offset + 3] = Math.round(255 * Math.min(1, (1 - Math.sqrt(r2)) * size / 2));
        }
    }
    ctx.putImageData(image, 0, 0, 0, 0, size, size);
}
