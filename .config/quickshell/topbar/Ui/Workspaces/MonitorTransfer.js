.pragma library
.import "OrbitalMotion.js" as Motion

function sharedEdge(source, target) {
    for (const axis of [0, 1]) {
        const position = axis === 0 ? "x" : "y";
        const size = axis === 0 ? "width" : "height";
        const crossPosition = axis === 0 ? "y" : "x";
        const crossSize = axis === 0 ? "height" : "width";

        const direction = target[position] >= source[position] + source[size] - 1 ? 1 : -1;
        const edge = source[position] + (direction > 0 ? source[size] : 0);
        const otherEdge = target[position] + (direction > 0 ? 0 : target[size]);

        const low = Math.max(source[crossPosition], target[crossPosition]);
        const high = Math.min(source[crossPosition] + source[crossSize], target[crossPosition] + target[crossSize]);

        if (Math.abs(edge - otherEdge) <= 1 && high > low)
            return {axis: axis, position: (edge + otherEdge) / 2, direction: direction, low: low, high: high};
    }
    return null;
}

function tangentHandle(pose, screen, direction, desiredLength) {
    const speed = Math.max(.01, Math.hypot(pose.v[0], pose.v[1]));
    const vector = pose.v.map(value => direction * value / speed);
    let length = desiredLength;

    for (const axis of [0, 1]) {
        const low = axis === 0 ? screen.x : screen.y;
        const high = low + (axis === 0 ? screen.width : screen.height);
        if (Math.abs(vector[axis]) > .00001) {
            const boundary = vector[axis] > 0 ? high - 2 : low + 2;
            length = Math.min(length, Math.max(.01, (boundary - pose.p[axis]) / vector[axis]));
        }
    }

    return {
        point: pose.p.map((value, axis) => value + vector[axis] * length),
        length: length,
        speed: speed
    };
}

function throughSharedEdge(start, end, screens, duration) {
    const containing = point => screens.find(screen => point[0] >= screen.x && point[0] < screen.x + screen.width
        && point[1] >= screen.y && point[1] < screen.y + screen.height);
    const source = containing(start.p);
    const target = containing(end.p);
    if (!source || !target || source === target)
        return null;

    const edge = sharedEdge(source, target);
    if (!edge)
        return null;

    const axis = edge.axis;
    const cross = 1 - axis;
    const fraction = Math.max(0, Math.min(1, (edge.position - start.p[axis]) / (end.p[axis] - start.p[axis])));
    const padding = Math.min(64, (edge.high - edge.low) / 4);
    const crossing = [0, 0, 0];
    crossing[axis] = edge.position;
    crossing[cross] = Math.max(edge.low + padding,
        Math.min(edge.high - padding, start.p[cross] + fraction * (end.p[cross] - start.p[cross])));

    const sourceDistance = Math.hypot(crossing[0] - start.p[0], crossing[1] - start.p[1]);
    const targetDistance = Math.hypot(end.p[0] - crossing[0], end.p[1] - crossing[1]);
    const departure = tangentHandle(start, source, 1, sourceDistance * .35);
    const arrival = tangentHandle(end, target, -1, targetDistance * .35);

    const sourceSize = axis === 0 ? source.width : source.height;
    const targetSize = axis === 0 ? target.width : target.height;
    const reach = Math.min(sourceDistance * .35, targetDistance * .35, sourceSize * .4, targetSize * .4);
    const before = crossing.slice();
    const after = crossing.slice();
    before[axis] -= edge.direction * reach;
    after[axis] += edge.direction * reach;

    // Each cubic stays inside its screen's convex bounds. Equal handles at the
    // shared edge keep position and velocity continuous across both surfaces.
    const segments = [[start.p, departure.point, before, crossing], [crossing, after, arrival.point, end.p]];

    const timingStart = {p: [0, 0, 0], v: [departure.speed / (6 * departure.length), 0, 0], a: [0, 0, 0]};
    const timingEnd = {p: [1, 0, 0], v: [arrival.speed / (6 * arrival.length), 0, 0], a: [0, 0, 0]};

    return {
        axes: Motion.coefficients(timingStart, timingEnd, duration),
        duration: duration,
        segments: segments,
        arc: 0,
        normal: [0, 0, 0]
    };
}
