const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const layout = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, "Layout.js"), "utf8").replace(/^\.pragma library\s*/, ""), layout);

function monitor(name, x, width = 1920, height = 1080, scale = 1) {
    return {name, x, y: 0, width, height, scale, transform: 0, enabled: true, internal: name === "eDP-1"};
}

function valid(monitors) {
    const active = monitors.filter(m => m.enabled);
    for (let i = 0; i < active.length; i++) {
        for (let j = i + 1; j < active.length; j++)
            assert.equal(layout.intersects(active[i], active[j]), false, "Displays overlap");
    }
    const reached = new Set([active[0]]);
    for (let step = 0; step < active.length; step++) {
        for (const m of active)
            if ([...reached].some(other => layout.attached(m, other)))
                reached.add(m);
    }
    assert.equal(reached.size, active.length, "Displays are disconnected");
}

const original = [monitor("eDP-1", 0), monitor("DP-1", 1920, 2560, 1440), monitor("DP-2", 4480)];
for (const mode of ["laptop", "external", "extend", "custom"])
    valid(layout.mode(original, mode));

let draft = original;
for (let step = 0; step < 300; step++) {
    draft = layout.move(draft, draft[step % draft.length].name,
        Math.sin(step * 1.7) * 10000, Math.cos(step * 2.3) * 10000);
    valid(draft);
}
valid(layout.pack([monitor("eDP-1", 0, 3840, 2160, 2), monitor("DP-1", 6000), monitor("DP-2", -4000)]));
const rotated = monitor("DP-1", 0, 1920, 1080);
rotated.transform = 1;
assert.equal(layout.size(rotated).width, 1080);
assert.equal(original[0].x, 0, "Layout operations mutated the source");
assert.ok(layout.scales(original[0]).includes(5 / 6));
assert.ok(layout.scales(original[0]).every(f => Math.abs(1920 / f - Math.round(1920 / f)) < .001
    && Math.abs(1080 / f - Math.round(1080 / f)) < .001));
assert.equal(layout.maxRefresh({width: 1920, height: 1080, rate: 60,
    modes: ["1920x1080@144", "1920x1080@120", "3840x2160@60"]}), 144);
console.log("PASS edge snapping, bridge moves, connected layouts, mixed scales and rotation");
