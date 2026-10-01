.pragma library

var radiusX = 18;
var radiusY = 4.5;
var radiusZ = Math.sqrt(radiusX * radiusX - radiusY * radiusY);
var angularSpeed = 2 * Math.PI / 5.6;
var transferBudget = 0.83;

function finitePose(pose) {
    return pose && [pose.p, pose.v, pose.a].every(vector =>
        vector && vector.length === 3 && vector.every(Number.isFinite));
}

function heading(previous, velocity) {
    const target = Math.atan2(velocity[1], velocity[0]);
    return previous + Math.atan2(Math.sin(target - previous), Math.cos(target - previous));
}

function ease(progress) {
    const t = Math.max(0, Math.min(1, progress));
    return t * t * t * (10 + t * (-15 + t * 6));
}

function orbit(center, angle, speed, acceleration) {
    const c = Math.cos(angle), s = Math.sin(angle);
    const w = speed === undefined ? angularSpeed : speed;
    const a = acceleration || 0;
    return {
        p: [center[0] + radiusX * c, center[1] + radiusY * s, radiusZ * s],
        v: [-radiusX * s * w, radiusY * c * w, radiusZ * c * w],
        a: [-radiusX * (c * w * w + s * a), radiusY * (-s * w * w + c * a), radiusZ * (-s * w * w + c * a)]
    };
}

function coefficients(start, end, duration) {
    const result = [];
    for (let axis = 0; axis < 3; ++axis) {
        const p = start.p[axis], v = start.v[axis] * duration;
        const a = start.a[axis] * duration * duration;
        const dp = end.p[axis] - p - v - a / 2;
        const dv = end.v[axis] * duration - v - a;
        const da = end.a[axis] * duration * duration - a;
        result.push([p, v, a / 2, 10 * dp - 4 * dv + da / 2,
                     -15 * dp + 7 * dv - da, 6 * dp - 3 * dv + da / 2, 0]);
    }
    return result;
}

function sample(path, time) {
    const t = Math.max(0, Math.min(1, time / path.duration));
    const pose = { p: [], v: [], a: [] };
    for (let axis = 0; axis < 3; ++axis) {
        const c = path.axes[axis];
        pose.p.push(c[0] + t * (c[1] + t * (c[2] + t * (c[3] + t * (c[4] + t * (c[5] + t * c[6]))))));
        pose.v.push((c[1] + t * (2 * c[2] + t * (3 * c[3] + t * (4 * c[4] + t * (5 * c[5] + t * 6 * c[6]))))) / path.duration);
        pose.a.push((2 * c[2] + t * (6 * c[3] + t * (12 * c[4] + t * (20 * c[5] + t * 30 * c[6])))) / (path.duration * path.duration));
    }
    return pose;
}

function progression(distance, duration, speed, seconds) {
    if (duration <= 0)
        return { position: distance, speed: speed, acceleration: 0 };
    const t = Math.max(0, Math.min(1, seconds / duration));
    const extra = distance - speed * duration;
    return {
        position: speed * t * duration + extra * ease(t),
        speed: speed + extra * 30 * t * t * (1 - t) * (1 - t) / duration,
        acceleration: extra * 60 * t * (1 - t) * (1 - 2 * t) / (duration * duration)
    };
}

function tangentRoutes(source, destination, direction, bodies) {
    const dx = destination[0] - source[0];
    if (!Number.isFinite(dx) || Math.abs(dx) <= 2 * radiusX)
        return [];
    const routes = [];
    for (const opposite of [false, true]) {
        const nx = opposite ? 2 * radiusX / dx : 0;
        const ny = -Math.sign(dx) * direction * Math.sqrt(1 - nx * nx);
        const start = [source[0] + radiusX * nx, radiusX * ny];
        const end = [destination[0] + (opposite ? -1 : 1) * radiusX * nx,
            (opposite ? -1 : 1) * radiusX * ny];
        const vector = [end[0] - start[0], end[1] - start[1]];
        const length = Math.hypot(vector[0], vector[1]);
        const clear = bodies.every(body => {
            const t = Math.max(0, Math.min(1, ((body[0] - start[0]) * vector[0] - start[1] * vector[1]) / (length * length)));
            return Math.hypot(start[0] + t * vector[0] - body[0], start[1] + t * vector[1]) >= 17;
        });
        if (!clear)
            continue;
        const angle = Math.atan2(ny, nx);
        routes.push({ start: start, end: end, length: length, source: source.slice(), destination: destination.slice(),
            departureAngle: angle, arrivalAngle: opposite ? angle + Math.PI : angle,
            direction: opposite ? -direction : direction, duration: Math.min(0.56, 0.34 + length / 600) });
    }
    return routes;
}

function plan(source, destination, angle, direction, bodies) {
    const routes = tangentRoutes(source, destination, direction, bodies);
    let best = null;
    for (const route of routes) {
        const arc = ((route.departureAngle - angle) * direction % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
        const duration = arc < 0.12 ? arc / angularSpeed
            : Math.min(transferBudget - route.duration, Math.max(0.1, arc / 9));
        const cost = duration + route.duration;
        if (!best || cost < best.cost)
            best = { route: route, startAngle: angle, arc: arc, direction: direction, duration: duration, cost: cost };
    }
    return best;
}

function sampleDeparture(plan, seconds) {
    const travel = progression(plan.arc, plan.duration, angularSpeed, seconds);
    const angle = plan.startAngle + plan.direction * travel.position;
    return { angle: angle, pose: orbit(plan.route.source, angle,
        plan.direction * travel.speed, plan.direction * travel.acceleration) };
}

function sampleTransfer(route, seconds) {
    const travel = progression(route.length, route.duration, radiusX * angularSpeed, seconds);
    const vector = [(route.end[0] - route.start[0]) / route.length,
        (route.end[1] - route.start[1]) / route.length];
    const plane = [route.start[0] + vector[0] * travel.position, route.start[1] + vector[1] * travel.position];
    const tangent = [vector[0], vector[1] * radiusY / radiusX, vector[1] * radiusZ / radiusX];
    return {
        p: [plane[0], route.source[1] + plane[1] * radiusY / radiusX, plane[1] * radiusZ / radiusX],
        v: tangent.map(value => value * travel.speed),
        a: tangent.map(value => value * travel.acceleration)
    };
}
