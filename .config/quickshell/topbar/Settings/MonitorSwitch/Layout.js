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

// Enough shared edge left over that the pointer can still cross between screens.
var EDGE_CONTACT = 100;

function alignments(ownLength, otherPos, otherLength) {
    return [otherPos, otherPos + otherLength - ownLength, otherPos + (otherLength - ownLength) / 2];
}

// Positions flush against one neighbour's four sides. The coordinate running
// along the touching edge keeps whatever the drag asked for, so a screen slides
// freely instead of jumping between a handful of fixed slots; within `threshold`
// of a shared edge or centre it latches onto that alignment exactly.
function sides(monitor, neighbour, desired, threshold) {
    const own = size(monitor), other = size(neighbour), result = [];

    function slide(wanted, ownLength, otherPos, otherLength) {
        for (const option of alignments(ownLength, otherPos, otherLength)) {
            if (Math.abs(wanted - option) <= threshold)
                return Math.round(option);
        }
        const contact = Math.min(EDGE_CONTACT, ownLength, otherLength);
        return Math.round(Math.max(otherPos - ownLength + contact, Math.min(otherPos + otherLength - contact, wanted)));
    }

    const y = slide(desired.y, own.height, neighbour.y, other.height);
    result.push({x: neighbour.x + other.width, y: y});
    result.push({x: neighbour.x - own.width, y: y});

    const x = slide(desired.x, own.width, neighbour.x, other.width);
    result.push({x: x, y: neighbour.y + other.height});
    result.push({x: x, y: neighbour.y - own.height});
    return result;
}

// Pulls a near-miss onto the exact shared edge, centre line or flush contact of
// whichever neighbour it is closest to, so screens can actually be lined up by
// hand. A zero threshold (the precise modifier) leaves the position untouched.
function magnetize(monitor, others, desired, threshold) {
    if (!threshold)
        return desired;

    const own = size(monitor);
    let x = desired.x, y = desired.y;
    let nearestX = threshold + 1, nearestY = threshold + 1;
    for (const neighbour of others) {
        const other = size(neighbour);
        for (const option of alignments(own.height, neighbour.y, other.height).concat([neighbour.y - own.height, neighbour.y + other.height])) {
            const gap = Math.abs(desired.y - option);
            if (gap <= threshold && gap < nearestY) {
                nearestY = gap;
                y = Math.round(option);
            }
        }
        for (const option of alignments(own.width, neighbour.x, other.width).concat([neighbour.x - own.width, neighbour.x + other.width])) {
            const gap = Math.abs(desired.x - option);
            if (gap <= threshold && gap < nearestX) {
                nearestX = gap;
                x = Math.round(option);
            }
        }
    }
    return {x: x, y: y};
}

// Where a screen ends up for a requested position: its own spot when that is
// already touching something and clear of everything, otherwise the nearest
// flush position. Nothing can be left floating apart from the rest.
function place(monitors, name, desiredX, desiredY, threshold) {
    const moving = monitors.find(m => m.name === name);
    const others = monitors.filter(m => m.name !== name && m.enabled);
    if (!others.length)
        return Object.assign({}, moving, {x: 0, y: 0});

    const desired = magnetize(moving, others, {x: Math.round(desiredX), y: Math.round(desiredY)}, threshold || 0);
    const candidates = [];
    const free = Object.assign({}, moving, desired);
    if (others.some(other => attached(free, other)) && !others.some(other => intersects(free, other)))
        candidates.push(desired);
    for (const neighbour of others) {
        for (const spot of sides(moving, neighbour, desired, threshold || 0)) {
            if (!others.some(other => intersects(Object.assign({}, moving, spot), other)))
                candidates.push(spot);
        }
    }
    if (!candidates.length)
        return Object.assign({}, moving);

    candidates.sort((a, b) => Math.hypot(a.x - desired.x, a.y - desired.y) - Math.hypot(b.x - desired.x, b.y - desired.y));
    return Object.assign({}, moving, candidates[0]);
}

function normalize(monitors) {
    const active = monitors.filter(m => m.enabled);
    if (!active.length)
        return monitors;
    const left = Math.min(...active.map(m => m.x));
    const top = Math.min(...active.map(m => m.y));
    return monitors.map(m => m.enabled ? Object.assign({}, m, {x: m.x - left, y: m.y - top}) : m);
}

function connected(monitors) {
    const active = monitors.filter(m => m.enabled);
    if (active.length < 2)
        return true;
    for (let i = 0; i < active.length; i++) {
        for (let j = i + 1; j < active.length; j++) {
            if (intersects(active[i], active[j]))
                return false;
        }
    }
    const reached = [active[0]];
    for (let pass = 0; pass < active.length; pass++) {
        for (const monitor of active) {
            if (reached.indexOf(monitor) < 0 && reached.some(other => attached(monitor, other)))
                reached.push(monitor);
        }
    }
    return reached.length === active.length;
}

// Reattaches only what is actually adrift. An arrangement that already holds
// together keeps its exact coordinates, or reopening the panel — or refreshing
// after an apply — would silently rewrite the placement the user just chose.
function repair(monitors) {
    const result = copy(monitors);
    if (connected(result))
        return result;

    const placed = [];
    for (const monitor of result.filter(m => m.enabled)) {
        if (placed.length && !connected(placed.concat([monitor])))
            Object.assign(monitor, place(placed.concat([monitor]), monitor.name, monitor.x, monitor.y, 0));
        placed.push(monitor);
    }
    return result;
}

function pack(monitors) {
    return normalize(repair(monitors));
}

// Moving a screen out of the middle of a row leaves the ones it used to bridge
// adrift, so the remainder is closed up before the dragged screen lands. Left
// un-recentred, which is what a live drag preview needs to stay put in the
// viewport the drag started in.
function draft(monitors, name, x, y, threshold) {
    const rest = repair(monitors.filter(m => m.name !== name));
    const staged = monitors.map(m => m.name === name ? Object.assign({}, m) : rest.find(n => n.name === m.name));
    const destination = place(staged, name, x, y, threshold);
    return staged.map(m => m.name === name ? destination : m);
}

function move(monitors, name, x, y, threshold) {
    return normalize(draft(monitors, name, x, y, threshold));
}

// Rails to draw for every edge of the moving screen that lines up exactly with
// a neighbour, spanning both so the alignment reads at a glance.
function guides(monitors, name) {
    const moving = monitors.find(m => m.name === name);
    if (!moving)
        return [];

    const own = size(moving), result = [];
    for (const neighbour of monitors.filter(m => m.name !== name && m.enabled)) {
        const other = size(neighbour);
        const edges = [
            {axis: "y", own: [moving.y, moving.y + own.height], other: [neighbour.y, neighbour.y + other.height], span: [moving.x, moving.x + own.width, neighbour.x, neighbour.x + other.width]},
            {axis: "x", own: [moving.x, moving.x + own.width], other: [neighbour.x, neighbour.x + other.width], span: [moving.y, moving.y + own.height, neighbour.y, neighbour.y + other.height]}
        ];
        for (const edge of edges) {
            for (const mine of edge.own) {
                for (const theirs of edge.other) {
                    if (mine !== theirs)
                        continue;
                    result.push({axis: edge.axis, at: mine, from: Math.min.apply(null, edge.span), to: Math.max.apply(null, edge.span)});
                }
            }
        }
    }
    return result;
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
