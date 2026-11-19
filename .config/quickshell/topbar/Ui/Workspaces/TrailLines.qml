pragma ComponentBehavior: Bound

import QtQuick

// The line the ship leaves behind it: one short segment between each pair of
// neighbouring trail points, fading with age. The segments are the parent's
// children, so each stacks with the planets and the ship by its own z.
Repeater {
    id: root

    required property TrailBuffer trail
    property bool shown: true

    model: trail.capacity - 1

    Rectangle {
        required property int index
        readonly property var head: root.trail.point(index)
        readonly property var tail: root.trail.point(index + 1)
        readonly property bool connected: head && tail && head.time - tail.time < 0.09
            && head.z * tail.z >= 0
            && Math.hypot(tail.x - head.x, tail.y - head.y) < 36
        readonly property real age: head ? root.trail.clock - head.time : 2
        x: head ? head.x : 0
        y: head ? head.y - height / 2 : 0
        width: connected ? Math.hypot(tail.x - head.x, tail.y - head.y) + 0.25 : 0
        height: 1.2
        radius: 0.6
        transformOrigin: Item.Left
        rotation: head && tail ? Math.atan2(tail.y - head.y, tail.x - head.x) * 180 / Math.PI : 0
        color: head && head.heat > 0.25 ? "#E8C59B" : "#FFFFFF"
        opacity: Math.max(0, 1 - age / 1.05) * 0.58
        visible: root.shown && connected && opacity > 0
        z: head && head.z > 0 ? 2 : 0
    }
}
