const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const base = require('node:path').resolve(__dirname, '..') + '/';
const motion = vm.createContext({});
const monitor = vm.createContext({Motion: motion});
for (const [file, context] of [['OrbitalMotion.js', motion], ['MonitorTransfer.js', monitor]])
    vm.runInContext(fs.readFileSync(base + file, 'utf8').replace(/^\.(pragma|import).*$/gm, ''), context);
const layouts = [
    [{x: 2048, y: 0, width: 1920, height: 1080}, {x: 0, y: 373, width: 2048, height: 1152}],
    [{x: 0, y: 0, width: 1920, height: 1080}, {x: 600, y: 1080, width: 2048, height: 1152}],
    [{x: -1920, y: -300, width: 1920, height: 1080}, {x: 0, y: 0, width: 2048, height: 1152}],
    [{x: 0, y: 0, width: 1920, height: 1080}, {x: 1920, y: 0, width: 2048, height: 1152}]
];
const close = (a, b, epsilon=1e-6) => a.forEach((v,i) => assert.ok(Math.abs(v-b[i]) < epsilon, `${a} != ${b}`));
let checks = 0;
for (const screens of layouts) {
    for (const reverse of [false, true]) {
        const [a,b] = reverse ? screens.slice().reverse() : screens;
        for (const offset of [120, 300, 600]) {
            const source = [a.x + offset, a.y + 21];
            const target = [b.x + offset, b.y + 21];
            for (const direction of [-1,1]) {
                const route = motion.tangentRoutes(source, target, direction, [source,target]).find(r => r.direction === direction);
                const start = motion.orbit(source, route.departureAngle, direction * motion.angularSpeed);
                const end = motion.orbit(target, route.arrivalAngle, direction * motion.angularSpeed);
                route.duration = 1.4;
                route.curve = monitor.throughSharedEdge(start, end, screens, route.duration);
                assert.ok(route.curve);
                close(motion.sampleTransfer(route, 0).p, start.p);
                close(motion.sampleTransfer(route, 0).v, start.v);
                close(motion.sampleTransfer(route, route.duration).p, end.p);
                close(motion.sampleTransfer(route, route.duration).v, end.v);
                let lastProgress = -1;
                for (let step=0; step<=2000; step++) {
                    const time = route.duration * step / 2000;
                    const progress = motion.sample(route.curve, time).p[0];
                    assert.ok(progress >= lastProgress - 1e-9 && progress <= 1+1e-9, 'monotone timing');
                    lastProgress = progress;
                    const pose = motion.sampleTransfer(route, time);
                    assert.ok(motion.finitePose(pose));
                    assert.ok(screens.some(s => pose.p[0] >= s.x-1e-6 && pose.p[0] <= s.x+s.width+1e-6 && pose.p[1] >= s.y-1e-6 && pose.p[1] <= s.y+s.height+1e-6), `path leaves screens: ${pose.p}`);
                }
                const [first,second] = route.curve.segments;
                close(first[3],second[0]);
                close(first[3].map((v,i)=>v-first[2][i]),second[1].map((v,i)=>v-second[0][i]));
                checks++;
            }
        }
    }
}
console.log(`Passed ${checks} monitor routes, including current scaled/offset layout, both directions, stacked screens, endpoint velocities, continuous edge joins and full-path visibility.`);
