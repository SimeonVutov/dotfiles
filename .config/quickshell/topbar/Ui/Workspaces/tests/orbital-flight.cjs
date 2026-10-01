const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const motion = vm.createContext({});
const flight = vm.createContext({ Motion: motion });
for (const [file, context] of [['OrbitalMotion.js', motion], ['OrbitFlight.js', flight]]) {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8').replace(/^\.(pragma|import).*$/gm, '');
    vm.runInContext(source, context);
}
const bodies = [1, 2, 3].map((id, i) => ({ id, center: [28 + i * 48, 16.5], live: true, settled: true }));
const centers = bodies.map(body => body.center);
let plans = 0;
let reversed = 0;
let maximumDuration = 0;

function near(a, b, message, tolerance = 1e-7) {
    assert.equal(a.length, b.length);
    a.forEach((value, i) => assert.ok(Math.abs(value - b[i]) < tolerance, `${message}: ${a} != ${b}`));
}

for (let from = 0; from < bodies.length; ++from) {
    for (let to = 0; to < bodies.length; ++to) {
        if (from === to) continue;
        for (const direction of [-1, 1]) {
            for (let i = 0; i < 64; ++i) {
                const angle = i * Math.PI / 32;
                const plan = motion.plan(centers[from], centers[to], angle, direction, centers);
                assert.ok(plan);
                const route = plan.route;
                const start = motion.sampleDeparture(plan, 0).pose;
                const orbit = motion.orbit(centers[from], angle, direction * motion.angularSpeed);
                near(start.p, orbit.p, 'departure position');
                near(start.v, orbit.v, 'departure velocity');
                const launch = motion.sampleDeparture(plan, plan.duration).pose;
                const transferStart = motion.sampleTransfer(route, 0);
                near(launch.p, transferStart.p, 'launch position');
                near(launch.v, transferStart.v, 'launch velocity');
                const arrival = motion.sampleTransfer(route, route.duration);
                const nextOrbit = motion.orbit(centers[to], route.arrivalAngle, route.direction * motion.angularSpeed);
                near(arrival.p, nextOrbit.p, 'capture position');
                near(arrival.v, nextOrbit.v, 'capture velocity');
                for (let step = 0; step <= 100; ++step) {
                    const sample = motion.sampleDeparture(plan, plan.duration * step / 100);
                    const relative = sample.pose.p.map((value, axis) => value - (axis < 2 ? centers[from][axis] : 0));
                    assert.ok(Math.abs(Math.hypot(...relative) - motion.radiusX) < 1e-7, 'accelerating must not change orbit radius');
                    const pose = motion.sampleTransfer(route, route.duration * step / 100);
                    assert.ok(motion.finitePose(pose));
                    assert.ok(Math.abs(motion.heading(0, pose.v) - motion.heading(0, transferStart.v)) < 1e-9, 'burn heading must remain fixed');
                    for (const center of centers)
                        assert.ok(Math.hypot(pose.p[0] - center[0], pose.p[1] - center[1], pose.p[2]) >= 17 - 1e-7, 'transfer must clear every planet');
                }
                reversed += route.direction !== direction ? 1 : 0;
                maximumDuration = Math.max(maximumDuration, plan.cost + flight.settleDuration);
                ++plans;
            }
        }
    }
}
assert.ok(reversed > 0 && reversed < plans, 'both orbit capture directions must be used');
assert.ok(maximumDuration <= 0.951, 'settled transfers must fit the response budget');

for (const fps of [30, 60, 144, 180]) {
    const state = flight.create(1, centers[0]);
    const dt = 1 / fps;
    for (let frame = 0; frame < fps * 4; ++frame) {
        flight.request(state, Math.floor(frame * dt / 0.05) % 2 + 1);
        flight.advance(state, dt, bodies);
        assert.equal(state.mode, 'orbit', 'rapid toggles must settle before launching');
        assert.equal(state.throttle, 0);
    }
    flight.request(state, 3);
    let transferHeading = null;
    let redirected = false;
    for (let frame = 0; frame < fps * 6; ++frame) {
        const previousMode = state.mode;
        flight.advance(state, dt, bodies);
        assert.ok(motion.finitePose(state.pose));
        if (state.mode === 'transfer') {
            assert.ok(state.throttle >= 0.65, 'engine must stay lit throughout the transfer');
            if (previousMode !== 'transfer') transferHeading = state.heading;
            assert.ok(Math.abs(state.heading - transferHeading) < 1e-7, 'transfer must not steer while moving');
            if (!redirected) {
                flight.request(state, 2);
                redirected = true;
            }
        }
        if (state.mode !== 'transfer') {
            assert.equal(state.throttle, 0);
            assert.equal(state.braking, 0);
        }
    }
    assert.ok(redirected);
    assert.equal(state.orbitId, 2, 'the latest request must eventually arrive');
    assert.equal(state.mode, 'orbit');

    const disappearing = flight.create(1, centers[0]);
    const changingBodies = bodies.map(body => ({ ...body }));
    flight.request(disappearing, 2);
    let targetRemoved = false;
    for (let frame = 0; frame < fps * 6; ++frame) {
        flight.advance(disappearing, dt, changingBodies);
        assert.ok(motion.finitePose(disappearing.pose));
        if (disappearing.mode === 'transfer' && !targetRemoved) {
            changingBodies[1].live = false;
            flight.request(disappearing, 3);
            targetRemoved = true;
        }
    }
    assert.ok(targetRemoved);
    assert.equal(disappearing.mode, 'orbit');
    assert.equal(disappearing.orbitId, 3, 'a removed transfer target must not strand the rocket');
}

console.log(`Passed ${plans} tangent plans (${reversed} opposite-direction captures), orbit-radius and join checks, rapid switching and mid-flight redirection at four frame rates. Worst planned settled request: ${maximumDuration.toFixed(3)} s.`);
