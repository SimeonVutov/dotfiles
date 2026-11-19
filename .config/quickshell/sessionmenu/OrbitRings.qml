pragma ComponentBehavior: Bound

import QtQuick
import qs.Common as Shared

// The ring the actions sit on, and the thin orbits around the hub with a dot
// circling each at its own pace.
Item {
    id: root

    required property MenuGeometry geometry
    // Whether the dots circle, and whether they hold still.
    property bool running: false
    property bool paused: false

    readonly property color dotHalo: "#353535"
    readonly property real dotHaloPadding: 6
    readonly property real dotHaloMinSize: 6

    Rectangle {
        anchors.centerIn: parent
        width: root.geometry.orbitRingDiameter
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Shared.Theme.overlayBorder
    }

    Repeater {
        model: [
            {
                diameter: 268,
                size: 5,
                period: 18000,
                phase: 20
            },
            {
                diameter: 314,
                size: 8,
                period: 29000,
                phase: 155
            },
            {
                diameter: 358,
                size: 4,
                period: 41000,
                phase: 260
            },
            {
                diameter: 520,
                size: 7,
                period: 63000,
                phase: 75
            }
        ]

        Item {
            id: orbit

            required property var modelData

            anchors.centerIn: parent
            width: modelData.diameter
            height: width

            NumberAnimation on rotation {
                from: orbit.modelData.phase
                to: orbit.modelData.phase + 360
                duration: orbit.modelData.period
                loops: Animation.Infinite
                running: root.running
                paused: root.paused
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: Shared.Theme.overlayOrbit
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -height / 2
                width: orbit.modelData.size
                height: width
                radius: width / 2
                color: Shared.Theme.overlayMuted

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + root.dotHaloPadding
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: root.dotHalo
                    visible: orbit.modelData.size > root.dotHaloMinSize
                }
            }
        }
    }
}
