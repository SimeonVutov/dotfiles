import QtQuick

// Turns the mouse wheel into steps: wheel movement builds up until it amounts to
// a step, and steps are spaced at least 90 ms apart.
MouseArea {
    id: root

    // Raised with -1 (a step back) or 1 (a step forward).
    signal stepRequested(int direction)

    property real steps: 0
    property real lastAt: -1000

    acceptedButtons: Qt.NoButton

    // Forgets any movement that has built up.
    function reset() {
        delay.stop();
        steps = 0;
        lastAt = -1000;
    }

    function flush() {
        if (Math.abs(steps) < 120)
            return;

        const now = Date.now();
        const remaining = 90 - (now - lastAt);
        if (remaining > 0) {
            if (!delay.running) {
                delay.interval = Math.ceil(remaining);
                delay.start();
            }
            return;
        }

        stepRequested(steps > 0 ? -1 : 1);
        steps = 0;
        lastAt = now;
    }

    onEnabledChanged: {
        if (!enabled) {
            delay.stop();
            steps = 0;
        }
    }

    onWheel: wheel => {
        const delta = wheel.angleDelta.y || wheel.pixelDelta.y * 2;
        if (!delta)
            return;
        if (root.steps * delta < 0)
            root.steps = 0;
        root.steps = Math.max(-120, Math.min(120, root.steps + delta));
        root.flush();
        wheel.accepted = true;
    }

    Timer {
        id: delay
        interval: 90
        onTriggered: root.flush()
    }
}
