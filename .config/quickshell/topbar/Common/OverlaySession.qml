import QtQuick
import Quickshell
import Quickshell.Io

// One opening of a full-screen overlay (the app launcher, the session menu)
// that runs as a process of its own and ends when it closes. quickshell-overlay.sh
// captures the desktop while the process starts and names the file, so the
// capture is usually done by the time the window is built. The overlay maps
// once the snapshot is ready or the capture deadline expires.
//
// Nothing here may wait on a Timer: with the clock-driven animation driver
// (QSG_USE_SIMPLE_ANIMATION_DRIVER) timers only run once a window is on screen,
// and this process has none until the overlay maps.
Item {
    id: root

    // Names the capture file when the capture is made here, not by the script.
    property string capturePrefix: "overlay"
    // How long to wait for the script's capture before showing the overlay
    // without a snapshot, in milliseconds.
    property int captureDeadline: 250

    // The monitor holding the focus, as found by the script.
    readonly property string monitor: Quickshell.env("QS_OVERLAY_MONITOR") || Quickshell.screens[0]?.name || ""
    readonly property var targetScreen: Quickshell.screens.find(screen => screen.name === monitor) || Quickshell.screens[0]
    // A capture made ahead of this process, and the marker that appears once it
    // is complete. Without one, the capture is made here.
    readonly property string preparedCapture: Quickshell.env("QS_OVERLAY_CAPTURE")

    property bool opened: false
    property bool armed: false
    // The desktop capture, to hand to the overlay.
    property string snapshotSource: ""

    function open() {
        if (opened)
            return;

        if (preparedCapture) {
            // Before the window, so the wait runs while the window is built.
            awaitCapture.running = true;
            opened = true;
            return;
        }

        // Before the window: the capture runs while the window is built.
        const capturing = capture.start(monitor);
        opened = true;
        if (!capturing)
            arm();
    }

    // Idempotent: whichever of the overlay's own readiness, a failed capture or
    // the capture deadline comes first is the one that maps the window.
    function arm() {
        if (!opened || armed)
            return;

        armed = true;
    }

    // Drops the snapshot once the overlay has painted it, so a long-lived
    // overlay does not keep a screen-sized capture in memory.
    function releaseSnapshot() {
        snapshotSource = "";
        capture.release();
        if (preparedCapture)
            Quickshell.execDetached(["rm", "-f", "--", preparedCapture, preparedCapture + ".part", preparedCapture + ".ok"]);
    }

    // The process ends here, taking the window and everything else with it.
    function finish() {
        if (!opened)
            return;

        opened = false;
        armed = false;
        // The process ends before the capture's own clean-up would run.
        capture.cancel();
        releaseSnapshot();
        Qt.quit();
    }

    DesktopCapture {
        id: capture

        prefix: root.capturePrefix

        onCompleted: source => {
            // A capture that lands after arming has missed its slot; handing it
            // over now would pop the desktop in mid-animation.
            if (root.opened && !root.armed)
                root.snapshotSource = source;
            else
                capture.release();
        }

        onFailed: {
            if (root.opened)
                root.arm();
        }
    }

    // Waits for the prepared capture's marker, which comes last so that a
    // snapshot is never read half written. It ends at once if the marker is
    // there already, and gives up after the deadline, when the overlay maps
    // without a snapshot instead of waiting for the compositor indefinitely.
    Process {
        id: awaitCapture

        command: ["sh", "-c", 'n=0; while [ ! -e "$1" ] && [ "$n" -lt "$2" ]; do sleep 0.005; n=$((n + 1)); done; [ -e "$1" ]',
            "sh", root.preparedCapture + ".ok", String(Math.ceil(root.captureDeadline / 5))]
        onExited: (code, status) => {
            if (!root.opened || root.armed)
                return;

            if (code === 0 && status === 0)
                root.snapshotSource = "file://" + root.preparedCapture;
            else
                root.arm();
        }
    }

    Component.onDestruction: {
        capture.cancel();
        capture.release();
    }
}
