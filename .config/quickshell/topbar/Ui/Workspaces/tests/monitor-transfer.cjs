const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const base = path.resolve(__dirname, '..');
const motion = vm.createContext({});
const monitor = vm.createContext({ Motion: motion });
for (const [file, context] of [['OrbitalMotion.js', motion], ['MonitorTransfer.js', monitor]]) {
    const source = fs.readFileSync(path.join(base, file), 'utf8');
    vm.runInContext(source.replace(/^\.(pragma|import).*$/gm, ''), context);
}

const layouts = [
    [{ x: 2048, y: 0, width: 1920, height: 1080 }, { x: 0, y: 373, width: 2048, height: 1152 }],
    [{ x: 0, y: 0, width: 1920, height: 1080 }, { x: 600, y: 1080, width: 2048, height: 1152 }],
    [{ x: -1920, y: -300, width: 1920, height: 1080 }, { x: 0, y: 0, width: 2048, height: 1152 }],
    [{ x: 0, y: 0, width: 1920, height: 1080 }, { x: 1920, y: 0, width: 2048, height: 1152 }]
];

function near(actual, expected, epsilon = 1e-6) {
    actual.forEach((value, axis) =>
        assert.ok(Math.abs(value - expected[axis]) < epsilon, `${actual} != ${expected}`));
}

let checks = 0;
for (const screens of layouts) {
    for (const reverse of [false, true]) {
        const [from, to] = reverse ? screens.slice().reverse() : screens;
        for (const offset of [120, 300, 600]) {
            const source = [from.x + offset, from.y + 21];
            const target = [to.x + offset, to.y + 21];

            for (const direction of [-1, 1]) {
                const routes = motion.tangentRoutes(source, target, direction, [source, target]);
                const route = routes.find(candidate => candidate.direction === direction);
                const start = motion.orbit(source, route.departureAngle, direction * motion.angularSpeed);
                const end = motion.orbit(target, route.arrivalAngle, direction * motion.angularSpeed);
                route.duration = 1.4;
                route.curve = monitor.throughSharedEdge(start, end, screens, route.duration);

                assert.ok(route.curve);
                near(motion.sampleTransfer(route, 0).p, start.p);
                near(motion.sampleTransfer(route, 0).v, start.v);
                near(motion.sampleTransfer(route, route.duration).p, end.p);
                near(motion.sampleTransfer(route, route.duration).v, end.v);

                let lastProgress = -1;
                for (let step = 0; step <= 2000; step++) {
                    const time = route.duration * step / 2000;
                    const progress = motion.sample(route.curve, time).p[0];
                    assert.ok(progress >= lastProgress - 1e-9 && progress <= 1 + 1e-9, 'monotone timing');
                    lastProgress = progress;

                    const pose = motion.sampleTransfer(route, time);
                    const visible = screens.some(screen =>
                        pose.p[0] >= screen.x - 1e-6 && pose.p[0] <= screen.x + screen.width + 1e-6
                        && pose.p[1] >= screen.y - 1e-6 && pose.p[1] <= screen.y + screen.height + 1e-6);
                    assert.ok(motion.finitePose(pose));
                    assert.ok(visible, `path leaves screens: ${pose.p}`);
                }

                const [first, second] = route.curve.segments;
                near(first[3], second[0]);
                near(first[3].map((value, axis) => value - first[2][axis]),
                    second[1].map((value, axis) => value - second[0][axis]));
                checks++;
            }
        }
    }
}

console.log(`Passed ${checks} monitor routes, including scaled/offset layouts, both directions, stacked screens, endpoint velocities, continuous edge joins and full-path visibility.`);
