import QtQuick

// Everything behind the launcher's interface: deep space, the stars, the
// desktop wrapped onto the globe, and the fire and smoke of the flight.
Item {
    id: root

    required property var flight
    required property real clock
    required property point shake
    required property rect pane
    // The desktop capture, and whether it is ready to draw.
    required property Item surface
    required property bool surfaceReady
    required property real progress

    // Deep space behind everything; without a capture it fades in with altitude
    // so the real desktop is not covered before the flight starts.
    Rectangle {
        anchors.fill: parent
        color: Theme.space
        opacity: root.surfaceReady ? 1 : Math.min(1, root.progress * 3)
    }

    Starfield {
        x: -Theme.shakeMargin
        y: -Theme.shakeMargin
        width: parent.width + Theme.shakeMargin * 2
        height: parent.height + Theme.shakeMargin * 2
        level: root.flight.stars
        streak: root.flight.starsStreak
        shift: root.flight.starsShift
        transform: [
            Scale {
                origin.x: root.width / 2 + Theme.shakeMargin
                origin.y: root.height / 2 + Theme.shakeMargin
                xScale: root.flight.starsZoom
                yScale: root.flight.starsZoom
            },
            Translate {
                x: root.shake.x * root.height
                y: root.shake.y * root.height
            }
        ]
    }

    World {
        flight: root.flight
        surface: root.surface
        hasSurface: root.surfaceReady ? 1 : 0
        clock: root.clock
        shake: root.shake
    }

    Smoke {
        anchors.fill: parent
        flight: root.flight
        clock: root.clock
        shake: root.shake
        pane: root.pane
    }
}
