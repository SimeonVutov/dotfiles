.pragma library

function copy(monitors) {
    return monitors.map(m => Object.assign({}, m));
}

function size(monitor) {
    const rotated = monitor.transform % 2 !== 0;
    return {
        width: Math.round((rotated ? monitor.height : monitor.width) / monitor.scale),
        height: Math.round((rotated ? monitor.width : monitor.height) / monitor.scale)
    };
}

function intersects(a, b) {
    const as = size(a), bs = size(b);
    return Math.min(a.x + as.width, b.x + bs.width) > Math.max(a.x, b.x)
        && Math.min(a.y + as.height, b.y + bs.height) > Math.max(a.y, b.y);
}

function attached(a, b) {
    const as = size(a), bs = size(b);
    return ((a.x + as.width === b.x || b.x + bs.width === a.x)
            && Math.min(a.y + as.height, b.y + bs.height) > Math.max(a.y, b.y))
        || ((a.y + as.height === b.y || b.y + bs.height === a.y)
            && Math.min(a.x + as.width, b.x + bs.width) > Math.max(a.x, b.x));
}

function snap(monitor, placed, desiredX, desiredY) {
    if (!placed.length)
        return Object.assign({}, monitor, {x: 0, y: 0});

    const own = size(monitor), candidates = [];
    for (const neighbour of placed) {
        const other = size(neighbour);
        const overlapX = Math.min(80, own.width / 2, other.width / 2);
        const overlapY = Math.min(80, own.height / 2, other.height / 2);
        const clampedX = Math.round(Math.max(neighbour.x - own.width + overlapX,
                                            Math.min(neighbour.x + other.width - overlapX, desiredX)));
        const clampedY = Math.round(Math.max(neighbour.y - own.height + overlapY,
                                            Math.min(neighbour.y + other.height - overlapY, desiredY)));
        for (const y of [clampedY, neighbour.y, neighbour.y + other.height - own.height]) {
            candidates.push({x: neighbour.x - own.width, y: y});
            candidates.push({x: neighbour.x + other.width, y: y});
        }
        for (const x of [clampedX, neighbour.x, neighbour.x + other.width - own.width]) {
            candidates.push({x: x, y: neighbour.y - own.height});
            candidates.push({x: x, y: neighbour.y + other.height});
        }
    }
    const available = candidates.map(p => Object.assign({}, monitor, p))
        .filter(candidate => !placed.some(other => intersects(candidate, other)));
    available.sort((a, b) => Math.hypot(a.x - desiredX, a.y - desiredY) - Math.hypot(b.x - desiredX, b.y - desiredY));
    return available[0];
}

function normalize(monitors) {
    const active = monitors.filter(m => m.enabled);
    if (!active.length)
        return monitors;
    const left = Math.min(...active.map(m => m.x));
    const top = Math.min(...active.map(m => m.y));
    return monitors.map(m => m.enabled ? Object.assign({}, m, {x: m.x - left, y: m.y - top}) : m);
}

function pack(monitors) {
    const result = copy(monitors), placed = [];
    for (const monitor of result.filter(m => m.enabled)) {
        const canStay = placed.length && placed.some(other => attached(monitor, other))
            && !placed.some(other => intersects(monitor, other));
        if (!canStay)
            Object.assign(monitor, snap(monitor, placed, monitor.x, monitor.y));
        placed.push(monitor);
    }
    return normalize(result);
}

function move(monitors, name, x, y) {
    const others = pack(monitors.filter(m => m.name !== name));
    const moving = monitors.find(m => m.name === name);
    const destination = snap(moving, others.filter(m => m.enabled), x, y);
    return normalize(monitors.map(m => m.name === name ? destination : others.find(n => n.name === m.name)));
}

function mode(monitors, selectedMode) {
    const result = copy(monitors);
    for (const monitor of result) {
        if (selectedMode !== "custom")
            monitor.enabled = selectedMode === "laptop" ? monitor.internal : selectedMode === "external" ? !monitor.internal : true;
    }
    return pack(result);
}

function detect(monitors) {
    const active = monitors.filter(m => m.enabled);
    if (active.some(m => m.mirror && m.mirror !== "none"))
        return "duplicate";
    if (active.every(m => m.internal))
        return "laptop";
    if (active.length === monitors.filter(m => !m.internal).length && active.every(m => !m.internal))
        return "external";
    return active.length === monitors.length ? "extend" : "custom";
}

function displayRects(monitors, duplicate) {
    const packed = duplicate ? mode(monitors, "extend") : monitors;
    const active = packed.filter(m => m.enabled);
    const bottom = Math.max(0, ...active.map(m => m.y + size(m).height));
    let dockX = 0;
    return packed.map(m => {
        const rect = Object.assign({}, m, size(m));
        if (!m.enabled) {
            rect.x = dockX;
            rect.y = bottom + 220;
            dockX += rect.width + 120;
        }
        return rect;
    });
}

function bounds(rectangles) {
    if (!rectangles.length)
        return {x: 0, y: 0, width: 1, height: 1};
    const x = Math.min(...rectangles.map(r => r.x));
    const y = Math.min(...rectangles.map(r => r.y));
    return {x: x, y: y,
        width: Math.max(...rectangles.map(r => r.x + r.width)) - x,
        height: Math.max(...rectangles.map(r => r.y + r.height)) - y};
}

function resolutions(monitor) {
    if (!monitor)
        return [];
    return Array.from(new Set([monitor.width + "x" + monitor.height].concat(monitor.modes.map(m => m.split("@")[0]))));
}

function maxRefresh(monitor, resolution) {
    const prefix = (resolution || monitor.width + "x" + monitor.height) + "@";
    const advertised = monitor.modes.filter(m => m.startsWith(prefix)).map(m => Number(m.split("@")[1]));
    return advertised.length ? Math.max(...advertised) : monitor.rate;
}

function scales(monitor) {
    if (!monitor)
        return [];
    const result = [];
    // Hyprland searches fractional scales in 1/120 increments.
    for (let step = 100; step <= 360; step++) {
        if ((monitor.width * 120) % step === 0 && (monitor.height * 120) % step === 0)
            result.push(step / 120);
    }
    return result;
}
