import QtQuick

// A ring buffer of the ship's recent positions, from which the trail and the
// sparks behind it are drawn.
QtObject {
    id: root

    readonly property int capacity: 80
    readonly property real interval: 1 / 90

    property var points: []
    property int head: -1
    // The time of the newest point, and the time the next one is due.
    property real clock: 0
    property real nextAt: 0

    // The point `age` steps behind the newest, or null.
    function point(age) {
        return head < 0 ? null : points[(head - age + capacity) % capacity] || null;
    }

    function clear(now) {
        points = [];
        head = -1;
        clock = now;
        nextAt = now;
    }

    // Adds the ship's position when one is due. `heat` is how hard the engine
    // was burning.
    function record(pose, heat, now) {
        if (now < nextAt)
            return;

        const next = (head + 1) % capacity;
        points[next] = { x: pose.p[0], y: pose.p[1], z: pose.p[2], heat: heat, time: now };
        head = next;
        clock = now;
        nextAt = nextAt < now - interval ? now + interval : nextAt + interval;
    }
}
