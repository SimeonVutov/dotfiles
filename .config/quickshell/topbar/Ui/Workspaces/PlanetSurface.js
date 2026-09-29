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

function kindFor(seed, legacy) {
    const count = legacy ? legacyStyles.length : styles.length;
    return ((seed - 1) % count + count) % count;
}

function appearance(seed, legacy) {
    const kind = kindFor(seed, legacy);
    return legacy ? legacyStyles[kind] : styles[kind];
}

function paint(ctx, size, seed, legacy) {
    ctx.reset();
    const image = ctx.createImageData(size, size);
    const pixels = image.data;
    const kind = kindFor(seed, legacy);
    const variant = legacy ? 0 : Math.floor((seed - 1) / styles.length);
    const craters = [];
    let randomState = (seed * 7919 + 17) >>> 0;
    function random() {
        randomState = (randomState * 1664525 + 1013904223) >>> 0;
        return randomState / 4294967296;
    }
    let craterCount = legacy ? [14, 0, 0, 5, 0, 3, 9, 0, 0, 0, 5, 0][kind]
        : [14, 0, 0, 0, 0, 0, 0, 0, 0, 5][kind];
    if (legacy && kind === 6)
        craterCount = 9;
    for (let i = 0; i < craterCount; ++i)
        craters.push([random() * 1.7 - 0.85, random() * 1.7 - 0.85, 0.08 + random() * 0.22]);
    for (let y = 0; y < size; ++y) {
        for (let x = 0; x < size; ++x) {
            const nx = (x + 0.5) * 2 / size - 1;
            const ny = (y + 0.5) * 2 / size - 1;
            const azimuth = Math.atan2(ny, nx);
            const outline = kind === 10 || kind === 21
                ? 0.92 + 0.04 * Math.sin(5 * azimuth + seed)
                    + 0.035 * Math.sin(7 * azimuth - seed * 0.4) : 1;
            const r2 = (nx * nx + ny * ny) / (outline * outline);
            if (r2 >= 1)
                continue;
            const nz = Math.sqrt(1 - r2);
            const longitude = Math.atan2(nx, nz), latitude = Math.asin(ny / outline);
            let dx = nx, dy = ny, albedo;
            switch (kind) {
            case 0:
                albedo = 0.8 - 0.27 * Math.exp(-Math.pow((nx + 0.25) / 0.36, 2)
                    - Math.pow((ny + 0.12) / 0.42, 2));
                albedo += 0.07 * Math.sin(nx * 18 + seed) * Math.cos(ny * 17);
                break;
            case 1:
                albedo = 0.61 + 0.24 * Math.sin(latitude * 14 + 0.5 * Math.sin(longitude * 3 + variant * 1.7) + variant * 0.4)
                    + 0.08 * Math.sin(latitude * 35);
                break;
            case 2: {
                const fissure = Math.abs(Math.sin(longitude * 6 + Math.sin(latitude * 5 + seed)));
                albedo = 0.95 - 0.53 * Math.exp(-fissure * fissure * 65);
                break;
            }
            case 3: {
                if (legacy) {
                    const ridge = Math.sin(longitude * 4 + latitude * 8 + seed);
                    albedo = 0.28 + 0.52 * Math.exp(-ridge * ridge * 75);
                    break;
                }
                const storm = Math.sin(longitude * 2.4 + latitude * 3.2 + seed * 0.2)
                    + 0.35 * Math.sin(longitude * 5 - latitude * 4);
                albedo = 0.32 + 0.55 * Math.exp(-storm * storm * 3.2);
                albedo += 0.09 * Math.sin(latitude * 18 + longitude * 2);
                break;
            }
            case 4:
                albedo = 0.51 + 0.35 * Math.sin(latitude * 8 + 0.9 * Math.sin(longitude * 2 + variant));
                albedo += 0.12 * Math.exp(-Math.pow((nx - 0.25 + variant * 0.09) / 0.23, 2)
                    - Math.pow((ny + 0.17) / 0.16, 2));
                break;
            case 5: {
                if (legacy) {
                    albedo = 0.81 - 0.12 * Math.sin(longitude * 7 + latitude * 3);
                    break;
                }
                const continent = Math.sin(longitude * 3.1 + 0.7 * Math.sin(latitude * 5 + seed))
                    + 0.45 * Math.cos(latitude * 7 - longitude * 1.7);
                const clouds = 0.08 * Math.sin(longitude * 10 + latitude * 13);
                albedo = continent > 0.2 ? 0.86 : 0.36;
                albedo += clouds;
                break;
            }
            case 6: {
                if (legacy) {
                    albedo = 0.61 + 0.11 * Math.sin(nx * 17 + seed) * Math.cos(ny * 15);
                    albedo -= 0.27 * Math.exp(-Math.pow((nx - 0.05) / 0.48, 2)
                        - Math.pow((ny + 0.2) / 0.3, 2));
                    break;
                }
                const coast = Math.sin(longitude * 4 + 0.6 * Math.sin(latitude * 7 + seed))
                    + 0.6 * Math.cos(latitude * 5 - longitude * 2);
                albedo = coast > 0.1 ? 0.87 : 0.34;
                break;
            }
            case 7: {
                if (!legacy) {
                    const river = Math.abs(Math.sin(longitude * 4 + latitude * 3
                        + 0.8 * Math.sin(latitude * 5 + seed)));
                    albedo = 0.24 + 0.73 * Math.exp(-river * river * 48);
                    break;
                }
                albedo = 0.3 + 0.62 / (1 + Math.exp((ny + 0.22
                    + 0.1 * Math.sin(longitude * 4 + seed)) * 16));
                break;
            }
            case 8: {
                if (!legacy) {
                    const u = nx - 0.16, v = ny + 0.1;
                    const radius = Math.hypot(u, v);
                    const spiral = Math.sin(Math.atan2(v, u) * 2 + radius * 20 + seed * 0.18);
                    albedo = 0.53 + 0.23 * spiral
                        + 0.25 * Math.exp(-Math.pow((radius - 0.32) / 0.12, 2))
                        - 0.52 * Math.exp(-Math.pow(radius / 0.13, 2));
                    break;
                }
                albedo = 0.59 + 0.3 * Math.sin(longitude * 9 + latitude * 10
                    + 0.6 * Math.sin(latitude * 4));
                break;
            }
            case 9:
                if (!legacy) {
                    albedo = 0.54 + 0.18 * Math.sin(longitude * 5 + latitude * 7 + seed);
                    break;
                }
                albedo = 0.72 + 0.27 * Math.sin(longitude * 4
                    + 1.3 * Math.sin(latitude * 7 + seed * 0.3));
                break;
            case 10:
                albedo = 0.54 + 0.18 * Math.sin(longitude * 5 + latitude * 7 + seed);
                break;
            case 11:
                albedo = 0.8 + 0.16 * Math.sin(latitude * 6
                    + 1.5 * Math.sin(longitude * 4 + seed * 0.2));
                albedo -= 0.36 * Math.exp(-Math.pow((nx + 0.34) / 0.24, 2)
                    - Math.pow((ny - 0.13) / 0.2, 2));
                break;
            case 12: {
                const continent = Math.sin(longitude * 3 + 0.7 * Math.sin(latitude * 4 + seed))
                    + 0.55 * Math.cos(latitude * 6 - longitude * 2);
                albedo = continent > 0.24 ? 0.95 : 0.38;
                albedo += 0.07 * Math.sin(latitude * 12 + longitude * 4);
                break;
            }
            case 13: {
                const river = Math.abs(Math.sin(longitude * 4 + latitude * 3
                    + 0.8 * Math.sin(latitude * 5 + seed)));
                albedo = 0.24 + 0.73 * Math.exp(-river * river * 48);
                break;
            }
            case 14: {
                const plates = Math.abs(Math.sin(longitude * 5 + latitude * 2 + seed)
                    * Math.sin(latitude * 6 - longitude * 3));
                albedo = 0.9 - 0.68 * Math.exp(-plates * plates * 70);
                break;
            }
            case 15: {
                const u = nx - 0.16, v = ny + 0.1;
                const radius = Math.hypot(u, v);
                const spiral = Math.sin(Math.atan2(v, u) * 2 + radius * 20 + seed * 0.18);
                albedo = 0.53 + 0.23 * spiral
                    + 0.25 * Math.exp(-Math.pow((radius - 0.32) / 0.12, 2))
                    - 0.52 * Math.exp(-Math.pow(radius / 0.13, 2));
                break;
            }
            case 16: {
                const border = ny + 0.17 + 0.08 * Math.sin(longitude * 4 + seed);
                albedo = 0.31 + 0.63 / (1 + Math.exp(border * 24));
                albedo += 0.08 * Math.sin(longitude * 7 + latitude * 5);
                break;
            }
            case 17:
                albedo = 0.66 + 0.24 * Math.sin(latitude * 13 + 1.1 * Math.sin(longitude * 3 + seed))
                    + 0.09 * Math.sin(longitude * 6 - latitude * 8);
                break;
            case 18: {
                const cells = Math.cos(longitude * 7 + seed) + Math.cos(latitude * 8)
                    + Math.cos(longitude * 7 + latitude * 8 + seed);
                albedo = cells > 0.7 ? 0.86 : 0.3;
                break;
            }
            case 19: {
                const lights = Math.sin(longitude * 11 + seed) * Math.sin(latitude * 10);
                albedo = 0.28 + (lights > 0.75 ? 0.67 : 0.05);
                albedo += 0.11 * Math.sin(longitude * 3 + latitude * 4);
                break;
            }
            case 20: {
                const radius = Math.hypot(nx - 0.15, ny + 0.12);
                albedo = 0.58 + 0.36 * Math.exp(-Math.pow((radius - 0.48) / 0.08, 2))
                    - 0.34 * Math.exp(-Math.pow(radius / 0.27, 2));
                break;
            }
            case 21: {
                const steps = Math.floor(Math.hypot(nx + 0.15, ny - 0.12) * 5 + 0.4);
                albedo = 0.28 + (steps % 2 === 0 ? 0.6 : 0.18);
                break;
            }
            case 22: {
                const fault = Math.abs(longitude + 0.28 * Math.sin(latitude * 9 + seed)
                    - 0.28 * Math.sin(latitude * 3));
                albedo = 0.78 - 0.7 * Math.exp(-fault * fault * 23)
                    + 0.14 * Math.exp(-Math.pow((fault - 0.27) * 9, 2));
                break;
            }
            default:
                albedo = 0.24 + 0.68 * Math.exp(-Math.pow((longitude
                    - 0.28 * Math.sin(latitude * 3 + seed)) / 0.13, 2));
                albedo += 0.54 * Math.exp(-Math.pow((longitude + 0.7
                    + 0.2 * Math.sin(latitude * 4)) / 0.12, 2));
            }
            if (variant > 0)
                albedo += 0.08 * Math.sin(longitude * (3 + variant % 4)
                    + latitude * (2 + variant % 3) + variant * 2.3);
            for (let i = 0; i < craters.length; ++i) {
                const crater = craters[i];
                const u = (nx - crater[0]) / crater[2], v = (ny - crater[1]) / crater[2];
                const radius = Math.sqrt(u * u + v * v);
                if (radius < 1.25) {
                    const rim = Math.exp(-Math.pow((radius - 0.84) * 8, 2));
                    const bowl = Math.max(0, 1 - radius * radius);
                    albedo += rim * 0.13 - bowl * 0.17;
                    dx += u * bowl * 0.23;
                    dy += v * bowl * 0.23;
                }
            }
            const light = legacy && kind === 5
                ? Math.max(0, (0.92 * dx - 0.15 * dy - 0.18 * nz) / Math.hypot(dx, dy, nz))
                : Math.max(0, (-0.62 * dx - 0.46 * dy + 0.63 * nz) / Math.hypot(dx, dy, nz));
            const ambient = legacy && kind === 5 ? 0.015 : 0.03;
            const value = Math.round(255 * Math.pow(Math.max(0,
                Math.min(1, albedo * (ambient + light * (1 - ambient)))), 0.72));
            const offset = (y * size + x) * 4;
            pixels[offset + 3] = Math.round(255 * Math.min(1, (1 - Math.sqrt(r2)) * size / 2));
            pixels[offset] = value;
            pixels[offset + 1] = value;
            pixels[offset + 2] = value;
        }
    }
    ctx.putImageData(image, 0, 0, 0, 0, size, size);
}
