const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const base = path.resolve(__dirname, '../../..');
const motion = vm.createContext({});
const flight = vm.createContext({ Motion: motion });
const monitor = vm.createContext({ Motion: motion });

for (const [file, context] of [
    ['OrbitalMotion.js', motion],
    ['OrbitFlight.js', flight],
    ['MonitorTransfer.js', monitor]
]) {
    const source = fs.readFileSync(path.join(base, 'Ui/Workspaces', file), 'utf8');
    vm.runInContext(source.replace(/^\.(pragma|import).*$/gm, ''), context);
}

// Exercise the coordinator's actual functions without starting a compositor or overlay.
const coordinator = fs.readFileSync(path.join(base, 'Services/WorkspaceRocket.qml'), 'utf8');
const functions = coordinator.match(/^    function [\s\S]*?^    }/gm).join('\n');

function fixture() {
    const callbacks = [];
    const noop = () => {};
    const rocket = vm.createContext({
        Motion: motion,
        Flight: flight,
        MonitorTransfer: monitor,
        Qt: { callLater: callback => callbacks.push(callback) },
        retry: { stop: noop, restart: noop },
        fade: { stop: noop, start: noop },

        focusedMonitor: 'A',
        monitorName: 'A',
        scenes: {},
        transfer: null,
        bodies: [],
        destination: '',
        destinationId: -1,

        pose: null,
        heading: 0,
        elapsed: 0,
        trailPoints: [],
        trailRevision: 0,
        trailOpacity: 1,
        stage: 'idle',
        departureMonitor: ''
    });
    Object.defineProperty(rocket, 'travelling', { get: () => rocket.transfer !== null });
    vm.runInContext(functions, rocket);

    const displays = [
        ['A', { x: 0, y: 373, width: 2048, height: 1152 }, [1, 2, 3]],
        ['B', { x: 2048, y: 0, width: 1920, height: 1080 }, [6, 7, 8]]
    ];
    for (const [name, screen, ids] of displays) {
        const centers = Object.fromEntries(ids.map((id, index) =>
            [id, [screen.x + 300 + index * 48, screen.y + 21]]));
        const scene = {
            activeId: ids[0],
            externalDeparture: false,
            captures: [],
            flight: flight.create(ids[0], centers[ids[0]]),

            departureState() {
                return {
                    state: this.flight,
                    body: { id: this.flight.orbitId, center: centers[this.flight.orbitId], live: true, settled: true }
                };
            },
            arrivalTarget() {
                return { id: this.activeId, center: centers[this.activeId], live: true, settled: true };
            },
            displayDeparture() {},
            acceptFlight(state) {
                this.captures.push(state.orbitId);
                this.flight = Object.assign({}, state);
            }
        };
        rocket.scenes[name] = { screen, scene };
    }

    function tick(seconds) {
        rocket.advance(seconds);
        if (rocket.travelling) {
            assert.ok(motion.finitePose(rocket.pose));

            const velocityHeading = Math.atan2(rocket.pose.v[1], rocket.pose.v[0]);
            const difference = rocket.heading - velocityHeading;
            const turn = Math.atan2(Math.sin(difference), Math.cos(difference));
            assert.ok(Math.abs(turn) < 1e-7, 'heading must follow motion without independent rotation');
        }

        while (callbacks.length)
            callbacks.shift()();
    }

    return { rocket, tick };
}

for (const fps of [30, 60, 144, 240]) {
    const dt = 1 / fps;

    // A change before takeoff must realign the orbit toward the latest workspace.
    {
        const { rocket, tick } = fixture();
        rocket.focusedMonitor = 'B';
        rocket.followFocus();
        while (rocket.transfer.mode !== 'departure')
            tick(dt);

        const plan = rocket.transfer.plan;
        const pose = rocket.pose;
        rocket.scenes.B.scene.activeId = 7;
        rocket.followFocus();
        assert.equal(rocket.transfer.plan, plan, 'new request must not rewrite a departure already in progress');
        assert.equal(rocket.pose, pose);

        for (let frame = 0; frame < fps * 8 && rocket.travelling; frame++)
            tick(dt);

        assert.equal(rocket.travelling, false);
        assert.deepEqual(rocket.scenes.B.scene.captures, [7],
            'prelaunch change should go directly to the latest workspace after realignment');
    }

    // Returning to the source must finish the orbital motion before cancelling.
    {
        const { rocket, tick } = fixture();
        rocket.focusedMonitor = 'B';
        rocket.followFocus();
        while (rocket.transfer.mode !== 'departure')
            tick(dt);
        tick(dt);

        const plan = rocket.transfer.plan;
        const pose = rocket.pose;
        rocket.focusedMonitor = 'A';
        rocket.followFocus();
        assert.equal(rocket.transfer.plan, plan, 'cancellation must finish the current orbital departure');
        assert.equal(rocket.pose, pose);

        for (let frame = 0; frame < fps * 4 && rocket.travelling; frame++)
            tick(dt);

        assert.equal(rocket.travelling, false);
        assert.equal(rocket.scenes.A.scene.externalDeparture, false);
        assert.deepEqual(rocket.scenes.A.scene.captures, [1]);
        assert.deepEqual(rocket.scenes.B.scene.captures, []);
    }

    // Per-frame requests must preserve the airborne path, then follow the latest focus.
    {
        const { rocket, tick } = fixture();
        rocket.focusedMonitor = 'B';
        rocket.followFocus();
        while (rocket.stage !== 'transfer')
            tick(dt);

        const plan = rocket.transfer.plan;
        for (let frame = 0; frame < fps * 4 && rocket.scenes.B.scene.captures.length === 0; frame++) {
            const elapsed = rocket.transfer.elapsed;
            const pose = rocket.pose;
            rocket.focusedMonitor = frame % 2 ? 'A' : 'B';
            rocket.scenes.B.scene.activeId = frame % 3 + 6;
            rocket.followFocus();

            assert.equal(rocket.transfer.plan, plan, 'airborne plan must survive repeated switches');
            assert.equal(rocket.transfer.elapsed, elapsed, 'new focus must not restart flight time');
            assert.equal(rocket.pose, pose, 'request must not move or rotate the rocket');
            tick(dt);
        }
        assert.deepEqual(rocket.scenes.B.scene.captures, [6], 'committed flight must land once');

        rocket.focusedMonitor = 'A';
        rocket.followFocus();
        for (let frame = 0; frame < fps * 8 && rocket.travelling; frame++)
            tick(dt);

        assert.equal(rocket.monitorName, 'A', 'latest focus must be followed after landing');
        assert.equal(rocket.travelling, false);
    }
}

console.log('Passed coordinator departure retargeting, cancellation, per-frame airborne request churn, latest-focus capture and heading/motion alignment at 30/60/144/240 FPS.');
