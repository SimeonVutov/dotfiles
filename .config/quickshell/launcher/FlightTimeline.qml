import QtQuick
import Quickshell
import "Flight.js" as Flight

// Runs the launcher's flight (Flight.js). The entrance runs `progress` from 0
// to 1. Closing runs `closeProgress` as a landing (cancelled in orbit), an
// abort (cancelled during lift-off) or an exit (an app was chosen), starting
// from the state the flight was in when closing began.
Scope {
    id: root

    // What the flight depends on: the screen's aspect ratio, the globe's radius
    // in screen heights, and whether the launcher is closing.
    required property real aspect
    required property real radius
    required property bool closing

    property real progress: 0
    property string closeMode: ""
    property real closeProgress: 0
    property var closeFrom: null
    property real closeClock: 0
    // Fades the whole launcher when a landing is skipped with a second cancel.
    property real fade: 1

    // Raised when the entrance has finished, and when closing has finished and
    // the settled closing frame has been shown.
    signal ascended
    signal closed

    readonly property var flight: Flight.state(closeMode, progress, closeProgress, closeFrom, aspect, radius)
    readonly property real clock: closeMode ? closeClock + closeProgress * descent.duration / 1000 : progress * Theme.entranceDuration / 1000
    readonly property real settled: 1 - Math.pow(1 - flight.reveal, 3)
    // Early in lift-off, behind the shaking and smoke, everything shown later
    // is drawn once, invisibly, so its shaders, icons and textures are ready
    // before it appears instead of stalling the moment it does.
    readonly property bool warming: !closing && progress > Theme.warmFrom && progress < Theme.warmUntil
    // The capsule's window during a landing: centre and half size, in screen heights.
    readonly property rect pane: Qt.rect(aspect / 2, .5, aspect / 2 * Theme.paneWidth * flight.frameZoom,
        .5 * Theme.paneHeight * flight.frameZoom)
    readonly property point shake: Flight.shake(flight.shake, clock)

    function start() {
        ascent.start();
    }

    function restart() {
        ascent.restart();
    }

    // Back to the start, with nothing running.
    function reset() {
        ascent.stop();
        descent.stop();
        skipFade.stop();
        dismissAfterFrame.stop();
        progress = 0;
        closeMode = "";
        closeProgress = 0;
        closeFrom = null;
        fade = 1;
    }

    function beginClose(mode) {
        ascent.stop();
        closeFrom = flight;
        closeClock = clock;
        closeProgress = 0;
        descent.duration = mode === "landing" ? Theme.landingDuration : mode === "exit" ? Theme.exitDuration : Theme.abortDuration;
        closeMode = mode;
        descent.restart();
    }

    // Cuts a landing short: fades the launcher out instead of finishing it.
    function skip() {
        if (!skipFade.running)
            skipFade.start();
    }

    // Closing is undone, and the flight is back in orbit.
    function abandonClose() {
        descent.stop();
        closeMode = "";
        closeProgress = 0;
        closeFrom = null;
        progress = 1;
    }

    NumberAnimation {
        id: ascent
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Theme.entranceDuration
        easing.type: Easing.Linear
        onFinished: root.ascended()
    }

    NumberAnimation {
        id: descent
        target: root
        property: "closeProgress"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: dismissAfterFrame.start()
    }

    NumberAnimation {
        id: skipFade
        target: root
        property: "fade"
        to: 0
        duration: Theme.skipDuration
        easing.type: Easing.OutCubic
        onFinished: {
            descent.stop();
            root.closed();
        }
    }

    // Keeps the settled closing frame visible before the overlay unmaps.
    Timer {
        id: dismissAfterFrame
        interval: Theme.settleDelay
        onTriggered: root.closed()
    }
}
