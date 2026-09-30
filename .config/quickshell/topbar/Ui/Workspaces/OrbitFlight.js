.pragma library
.import "OrbitalMotion.js" as Motion

var settleDuration = 0.12;

function create(id, center) {
    const angle = -0.9;
    const pose = Motion.orbit(center, angle);
    return { mode: "orbit", orbitId: id, targetId: id, requestedId: id, requestAge: 0,
        angle: angle, direction: 1, elapsed: 0, plan: null, pose: pose,
        heading: Math.atan2(pose.v[1], pose.v[0]), throttle: 0, braking: 0 };
}

function request(state, id) {
    if (id === state.requestedId)
        return;
    state.requestedId = id;
    state.requestAge = 0;
}

function advance(state, seconds, bodies) {
    if (!Number.isFinite(seconds) || seconds <= 0)
        return;
    state.requestAge += seconds;
    state.throttle = 0;
    state.braking = 0;
    let remaining = seconds;
    for (let transition = 0; transition < 4 && remaining > 0; ++transition) {
        if (state.mode === "orbit") {
            const source = bodies.find(body => body.id === state.orbitId);
            if (!source)
                return;
            state.angle = (state.angle + state.direction * Motion.angularSpeed * remaining) % (2 * Math.PI);
            state.pose = Motion.orbit(source.center, state.angle, state.direction * Motion.angularSpeed);
            remaining = 0;
            const target = bodies.find(body => body.id === state.requestedId && body.live);
            if (!target || target.id === source.id || state.requestAge < settleDuration || !bodies.every(body => body.settled))
                break;
            const plan = Motion.plan(source.center, target.center, state.angle, state.direction, bodies.map(body => body.center));
            if (plan) {
                state.plan = plan;
                state.targetId = target.id;
                state.elapsed = 0;
                state.mode = "departure";
            }
        } else if (state.mode === "departure") {
            const consumed = Math.min(remaining, Math.max(0, state.plan.duration - state.elapsed));
            state.elapsed += consumed;
            remaining -= consumed;
            const sample = Motion.sampleDeparture(state.plan, state.elapsed);
            state.angle = sample.angle;
            state.pose = sample.pose;
            if (state.elapsed >= state.plan.duration) {
                const target = bodies.find(body => body.id === state.targetId && body.live);
                const committed = target && state.requestedId === state.targetId && state.requestAge >= settleDuration;
                state.mode = committed ? "transfer" : "orbit";
                state.elapsed = 0;
                state.throttle = committed ? 0.65 : 0;
                if (!committed)
                    state.plan = null;
            }
        } else if (state.mode === "transfer") {
            const route = state.plan.route;
            const consumed = Math.min(remaining, Math.max(0, route.duration - state.elapsed));
            state.elapsed += consumed;
            remaining -= consumed;
            state.pose = Motion.sampleTransfer(route, state.elapsed);
            const t = state.elapsed / route.duration;
            const thrust = 60 * t * (1 - t) * (1 - 2 * t) / 5.7735026919;
            state.throttle = 0.65 + 0.35 * Math.max(0, thrust);
            state.braking = Math.max(0, -thrust);
            if (state.elapsed >= route.duration) {
                state.orbitId = state.targetId;
                state.angle = route.arrivalAngle;
                state.direction = route.direction;
                state.mode = "orbit";
                state.plan = null;
                state.elapsed = 0;
                state.throttle = 0;
                state.braking = 0;
            }
        }
    }
    if (Motion.finitePose(state.pose))
        state.heading = Motion.heading(state.heading, state.pose.v);
}
