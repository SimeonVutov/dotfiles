pragma ComponentBehavior: Bound

import QtQuick

// Sparks drifting off the trail while the engine burns hard. Like the trail's
// segments they are the parent's children, stacked by their own z.
Repeater {
    id: root

    required property TrailBuffer trail
    property bool shown: true

    model: 8

    Rectangle {
        required property int index
        readonly property var point: root.trail.point(index * 3)
        readonly property real age: point ? root.trail.clock - point.time : 2
        x: point ? point.x + Math.sin(index * 12.7) * age * 12 : 0
        y: point ? point.y + Math.cos(index * 8.3) * age * 10 : 0
        width: index % 3 === 0 ? 1.5 : 1
        height: width
        radius: width / 2
        color: "#FFE4BD"
        opacity: point ? point.heat * Math.max(0, 1 - age / 0.5) * 0.8 : 0
        visible: root.shown && opacity > 0.01
        z: point && point.z > 0 ? 2 : 0
    }
}
